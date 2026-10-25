import 'dart:convert';
import 'dart:io';

import 'package:backend/config/database.dart';
import 'package:backend/repositories/tourist_place_repository.dart';
import 'package:backend/utils/tourist_province.dart';

String _normalizeId(String value) {
  const replacements = {
    'a': 'áàảãạăắằẳẵặâấầẩẫậ',
    'e': 'éèẻẽẹêếềểễệ',
    'i': 'íìỉĩị',
    'o': 'óòỏõọôốồổỗộơớờởỡợ',
    'u': 'úùủũụưứừửữự',
    'y': 'ýỳỷỹỵ',
    'd': 'đ',
  };
  var normalized = value.toLowerCase();
  for (final entry in replacements.entries) {
    for (final codePoint in entry.value.runes) {
      normalized = normalized.replaceAll(
        String.fromCharCode(codePoint),
        entry.key,
      );
    }
  }
  return normalized
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

void main() async {
  final file = File('assets/data/places.json');
  if (!await file.exists()) {
    stderr.writeln(
      '❌ Không tìm thấy assets/data/places.json. Hãy chạy '
      '`dart run bin/crawl_dulich.dart` trước.',
    );
    exitCode = 1;
    return;
  }

  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! List || decoded.isEmpty) {
    throw const FormatException(
      'places.json phải là JSON array không rỗng; từ chối import.',
    );
  }
  final places = <Map<String, dynamic>>[];
  for (final entry in decoded) {
    if (entry is! Map<String, dynamic>) {
      throw const FormatException(
        'Mỗi phần tử trong places.json phải là một JSON object.',
      );
    }
    places.add(entry);
  }

  final conn = await Database.connect();
  final repository = TouristPlaceRepository(conn);
  try {
    await repository.ensureSchema();
    final destinationCount = await repository.syncDestinationsIfAvailable();
    if (destinationCount > 0) {
      print('✅ Đã đồng bộ $destinationCount địa điểm từ bảng destinations.');
    }

    final existingResults = await conn.execute('SELECT id FROM tourist_place');
    final existingIds = <String>{};
    for (final row in existingResults.rows) {
      final id = row.assoc()['id'];
      if (id != null) {
        existingIds.add(id);
      }
    }

    final destinationColumns = await conn.execute('''
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = DATABASE()
        AND table_name = 'destinations'
    ''');
    final hasDestinationImages = destinationColumns.rows
        .map((row) => row.assoc()['column_name'])
        .contains('image_url');
    if (hasDestinationImages) {
      final destinationNames = await conn.execute(
        'SELECT name FROM destinations',
      );
      final namesByNormalizedValue = <String, String>{};
      for (final row in destinationNames.rows) {
        final name = row.assoc()['name'];
        if (name != null) {
          namesByNormalizedValue.putIfAbsent(_normalizeId(name), () => name);
        }
      }

      var updatedSourceImages = 0;
      for (final place in places) {
        final name = (place['name'] as String?)?.trim() ?? '';
        final imageUrl = (place['image_url'] as String?)?.trim() ?? '';
        final sourceName = namesByNormalizedValue[_normalizeId(name)];
        if (imageUrl.isEmpty || sourceName == null) continue;

        await conn.execute(
          'UPDATE destinations SET image_url = :imageUrl WHERE name = :name',
          {'imageUrl': imageUrl, 'name': sourceName},
        );
        updatedSourceImages++;
      }
      print(
        'Đã cập nhật ảnh khớp tiêu đề cho $updatedSourceImages địa điểm '
        'trong destinations.',
      );
    }

    print('Đang đồng bộ ${places.length} địa điểm vào bảng tourist_place...');
    var savedCount = 0;
    var insertedCount = 0;
    var updatedCount = 0;
    final failedPlaces = <String>[];
    for (var index = 0; index < places.length; index++) {
      final place = places[index];
      final name = (place['name'] as String?)?.trim() ?? '';
      final id = (place['id'] as String?)?.trim().isNotEmpty == true
          ? (place['id'] as String).trim()
          : _normalizeId(name);
      final address = (place['address'] as String?)?.trim() ?? '';
      final province = resolveTouristProvince(
        name: name,
        address: address,
        province: place['province'] as String?,
      );
      final history =
          (place['history'] as String?)?.trim() ??
          (place['description'] as String?)?.trim() ??
          '';
      final culture =
          (place['culture'] as String?)?.trim() ??
          (place['type'] as String?)?.trim() ??
          '';
      final imageUrl =
          (place['image_url'] as String?)?.trim() ??
          (place['image'] as String?)?.trim() ??
          '';
      final latitude = place['latitude'];
      final longitude = place['longitude'];
      if (name.isEmpty ||
          id.isEmpty ||
          address.isEmpty ||
          province == null ||
          latitude is! num ||
          longitude is! num) {
        throw FormatException(
          'Bản ghi địa điểm #${index + 1} thiếu name/address/tỉnh thành hợp lệ '
          'hoặc tọa độ.',
        );
      }

      try {
        await conn.execute(
          '''
          INSERT INTO tourist_place (
            id, name, image_url, history, culture, address, province,
            latitude, longitude
          )
          VALUES (
            :id, :name, :imageUrl, :history, :culture, :address, :province,
            :latitude, :longitude
          )
          ON DUPLICATE KEY UPDATE
            name = VALUES(name),
            image_url = IF(VALUES(image_url) <> '', VALUES(image_url), image_url),
            history = VALUES(history),
            culture = VALUES(culture),
            address = VALUES(address),
            province = VALUES(province),
            latitude = VALUES(latitude),
            longitude = VALUES(longitude)
          ''',
          {
            'id': id,
            'name': name,
            'imageUrl': imageUrl,
            'history': history,
            'culture': culture,
            'address': address,
            'province': province,
            'latitude': latitude,
            'longitude': longitude,
          },
        );
        if (existingIds.contains(id)) {
          updatedCount++;
        } else {
          insertedCount++;
          existingIds.add(id);
        }
        savedCount++;
      } catch (error) {
        stderr.writeln(
          '❌ Không thể đồng bộ "$name" vào tourist_place '
          '(bản ghi #${index + 1}/${places.length}). '
          'Kiểm tra schema và quyền SELECT/INSERT/UPDATE trên cơ sở dữ liệu.',
        );
        stderr.writeln('Chi tiết lỗi: $error');
        failedPlaces.add(name);
      }
    }

    print(
      '✅ Đã đồng bộ $savedCount/${places.length} địa điểm vào tourist_place '
      '($insertedCount thêm mới, $updatedCount cập nhật).',
    );
    final countResult = await conn.execute(
      'SELECT COUNT(*) AS total FROM tourist_place',
    );
    final totalRows = countResult.rows.first.assoc()['total'];
    print('📊 Tổng số bản ghi hiện có trong tourist_place: $totalRows.');
    if (failedPlaces.isNotEmpty) {
      stderr.writeln('❌ ${failedPlaces.length} địa điểm chưa được lưu:');
      for (final name in failedPlaces) {
        stderr.writeln(' - $name');
      }
      exitCode = 1;
    }
  } finally {
    await conn.close();
  }
}
