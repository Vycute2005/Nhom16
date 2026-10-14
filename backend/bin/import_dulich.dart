import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:mysql_client/mysql_client.dart';

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
  final dotenv = DotEnv()..load();
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

  final host = dotenv['DB_HOST'] ?? '103.82.26.171';
  final port = int.tryParse(dotenv['DB_PORT'] ?? '8806') ?? 8806;
  final user = dotenv['DB_USERNAME'] ?? 'hcm_explorer';
  final database = dotenv['DB_DATABASE'] ?? 'vietnam_travel';
  final conn = await MySQLConnection.createConnection(
    host: host,
    port: port,
    userName: user,
    password: dotenv['DB_PASSWORD'] ?? '',
    databaseName: database,
    secure: false,
  );

  print(
    'Đang kết nối MariaDB tại $host:$port (user: $user, database: $database)...',
  );
  try {
    await conn.connect();
  } catch (error) {
    stderr.writeln(
      '❌ Không kết nối được MariaDB. Kiểm tra DB_HOST, DB_PORT, '
      'DB_USERNAME và DB_PASSWORD trong .env.',
    );
    stderr.writeln('Chi tiết lỗi: $error');
    rethrow;
  }
  print('✅ Kết nối thành công!');

  try {
    final existingResults = await conn.execute('SELECT id FROM tourist_place');
    final existingIds = <String>{};
    for (final row in existingResults.rows) {
      final id = row.assoc()['id'];
      if (id != null) {
        existingIds.add(id);
      }
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
          latitude is! num ||
          longitude is! num) {
        throw FormatException(
          'Bản ghi địa điểm #${index + 1} thiếu name/address/latitude/longitude.',
        );
      }

      try {
        await conn.execute(
          '''
          INSERT INTO tourist_place (
            id, name, image_url, history, culture, address, latitude, longitude
          )
          VALUES (
            :id, :name, :imageUrl, :history, :culture, :address, :latitude, :longitude
          )
          ON DUPLICATE KEY UPDATE
            name = VALUES(name),
            image_url = IF(VALUES(image_url) <> '', VALUES(image_url), image_url),
            history = VALUES(history),
            culture = VALUES(culture),
            address = VALUES(address),
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
          'Kiểm tra schema và quyền SELECT/INSERT/UPDATE '
          'của tài khoản $user trên $database.',
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
