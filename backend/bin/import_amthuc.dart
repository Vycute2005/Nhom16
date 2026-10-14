import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:backend/utils/food_estimates.dart';

String _normalizeFoodKey(String value) {
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
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

String _makeId(String value) => _normalizeFoodKey(value).replaceAll(' ', '-');

void main() async {
  final dotenv = DotEnv()..load();
  final file = File('assets/data/foods.json');
  if (!await file.exists()) {
    stderr.writeln(
      '❌ Không tìm thấy assets/data/foods.json. Hãy chạy '
      '`dart run bin/crawl_amthuc.dart` trước.',
    );
    exitCode = 1;
    return;
  }

  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! List) {
    throw const FormatException('foods.json phải chứa một JSON array.');
  }
  final foods = <Map<String, dynamic>>[];
  for (final entry in decoded) {
    if (entry is! Map<String, dynamic>) {
      throw const FormatException(
        'Mỗi phần tử trong foods.json phải là một JSON object.',
      );
    }
    foods.add(entry);
  }
  if (foods.isEmpty) {
    throw const FormatException(
      'foods.json không có dữ liệu; từ chối import danh sách rỗng.',
    );
  }

  final conn = await MySQLConnection.createConnection(
    host: dotenv['DB_HOST'] ?? '103.82.26.171',
    port: int.tryParse(dotenv['DB_PORT'] ?? '8806') ?? 8806,
    userName: dotenv['DB_USERNAME'] ?? 'hcm_explorer',
    password: dotenv['DB_PASSWORD'] ?? '',
    databaseName: dotenv['DB_DATABASE'] ?? 'vietnam_travel',
    secure: false,
  );

  final dbHost = dotenv['DB_HOST'] ?? '103.82.26.171';
  final dbPort = dotenv['DB_PORT'] ?? '8806';
  final dbUser = dotenv['DB_USERNAME'] ?? 'hcm_explorer';
  final dbName = dotenv['DB_DATABASE'] ?? 'vietnam_travel';
  print(
    'Đang kết nối MariaDB tại $dbHost:$dbPort '
    '(user: $dbUser, database: $dbName)...',
  );
  try {
    await conn.connect();
  } catch (error) {
    stderr.writeln(
      '❌ Không kết nối được MariaDB tại $dbHost:$dbPort với user $dbUser. '
      'Kiểm tra DB_HOST, DB_PORT, DB_USERNAME và DB_PASSWORD trong .env.',
    );
    stderr.writeln('Chi tiết lỗi: $error');
    rethrow;
  }
  print('✅ Kết nối MariaDB thành công!');

  try {
    final restaurantColumns = await conn.execute(
      "SHOW COLUMNS FROM restaurant LIKE 'opening_hours'",
    );
    if (restaurantColumns.rows.isEmpty) {
      await conn.execute(
        "ALTER TABLE restaurant ADD COLUMN opening_hours VARCHAR(64) NOT NULL DEFAULT ''",
      );
    }
    final hoursSourceColumns = await conn.execute(
      "SHOW COLUMNS FROM restaurant LIKE 'opening_hours_source'",
    );
    if (hoursSourceColumns.rows.isEmpty) {
      await conn.execute(
        "ALTER TABLE restaurant ADD COLUMN opening_hours_source VARCHAR(16) NOT NULL DEFAULT ''",
      );
    }
    final illustrativeImageColumns = await conn.execute(
      "SHOW COLUMNS FROM restaurant LIKE 'image_is_illustrative'",
    );
    if (illustrativeImageColumns.rows.isEmpty) {
      await conn.execute(
        'ALTER TABLE restaurant ADD COLUMN image_is_illustrative TINYINT(1) NOT NULL DEFAULT 0',
      );
    }

    final existingFoods = await conn.execute('SELECT id, name FROM food');
    final foodIdsByName = <String, String>{};
    for (final row in existingFoods.rows) {
      final values = row.assoc();
      final id = values['id'];
      final name = values['name'];
      if (id != null && name != null) {
        foodIdsByName[_normalizeFoodKey(name)] = id;
      }
    }

    final foodIdByRecord = <Map<String, dynamic>, String>{};
    final imageUrlByFoodKey = <String, String>{};
    for (final food in foods) {
      final foodName = (food['food_name'] as String?)?.trim().isNotEmpty == true
          ? (food['food_name'] as String).trim()
          : 'Ẩm thực đa dạng';
      final imageUrl = food['image_url']?.toString().trim() ?? '';
      if (foodName != 'Ẩm thực đa dạng' && imageUrl.isNotEmpty) {
        imageUrlByFoodKey.putIfAbsent(
          _normalizeFoodKey(foodName),
          () => imageUrl,
        );
      }
    }

    for (final food in foods) {
      final foodName = (food['food_name'] as String?)?.trim().isNotEmpty == true
          ? (food['food_name'] as String).trim()
          : 'Ẩm thực đa dạng';
      final foodKey = _normalizeFoodKey(foodName);
      var foodId = foodIdsByName[foodKey];
      if (foodId == null) {
        foodId = _makeId(foodName);
        foodIdsByName[foodKey] = foodId;
      }
      await conn.execute(
        '''
        INSERT INTO food (id, name, description, image_url)
        VALUES (:id, :name, :description, :imageUrl)
        ON DUPLICATE KEY UPDATE
          name = VALUES(name),
          description = VALUES(description),
          image_url = CASE
            WHEN VALUES(name) = 'Ẩm thực đa dạng' THEN ''
            WHEN VALUES(image_url) <> ''
              AND VALUES(image_url) NOT LIKE 'https://down-vn.img.susercontent.com/%'
              THEN VALUES(image_url)
            WHEN image_url LIKE 'https://down-vn.img.susercontent.com/%' THEN ''
            ELSE image_url
          END
        ''',
        {
          'id': foodId,
          'name': foodName,
          'description': foodName == 'Ẩm thực đa dạng'
              ? 'Các quán ăn đa dạng tại TP. Hồ Chí Minh.'
              : 'Món ăn truyền thống Việt Nam.',
          'imageUrl': imageUrlByFoodKey[foodKey] ?? '',
        },
      );
      foodIdByRecord[food] = foodId;
    }

    final traditionalDishCount = foods
        .where(
          (food) => (food['restaurant_name'] as String? ?? '').startsWith(
            'Món ăn truyền thống -',
          ),
        )
        .length;
    print(
      'Đang nạp ${foods.length} mục ẩm thực '
      '($traditionalDishCount món truyền thống) vào bảng food và restaurant...',
    );

    for (final food in foods) {
      final restaurantName = (food['restaurant_name'] as String?)?.trim() ?? '';
      final foodName = (food['food_name'] as String?)?.trim() ?? '';
      final address = (food['address'] as String?)?.trim() ?? '';
      final latitude = food['latitude'];
      final longitude = food['longitude'];
      final rawRating = food['rating'];
      final rating = rawRating is num
          ? rawRating.toDouble().clamp(0, 5).toDouble()
          : 0.0;
      final coordinates = estimatedFoodCoordinates(restaurantName, address);
      final restaurantId = 'restaurant-${_makeId('$restaurantName $foodName')}';
      final foodId = foodIdByRecord[food]!;

      try {
        await conn.execute(
          '''
          INSERT INTO restaurant (
            id, name, address, food_id, latitude, longitude, image_url, rating,
            opening_hours, opening_hours_source, image_is_illustrative
          )
          VALUES (
            :id, :name, :address, :foodId, :latitude, :longitude, :imageUrl,
            :rating, :openingHours, :openingHoursSource, :imageIsIllustrative
          )
          ON DUPLICATE KEY UPDATE
            name = VALUES(name),
            address = VALUES(address),
            food_id = VALUES(food_id),
            latitude = VALUES(latitude),
            longitude = VALUES(longitude),
            image_url = CASE
              WHEN VALUES(image_url) <> ''
                AND VALUES(image_url) NOT LIKE 'https://down-vn.img.susercontent.com/%'
                THEN VALUES(image_url)
              WHEN image_url LIKE 'https://down-vn.img.susercontent.com/%' THEN ''
              ELSE image_url
            END,
            rating = IF(VALUES(rating) > 0, VALUES(rating), rating),
            opening_hours = VALUES(opening_hours),
            opening_hours_source = VALUES(opening_hours_source),
            image_is_illustrative = VALUES(image_is_illustrative)
          ''',
          {
            'id': restaurantId,
            'name': restaurantName,
            'address': address.isEmpty ? 'TP. Hồ Chí Minh' : address,
            'foodId': foodId,
            'latitude': latitude is num && latitude != 0
                ? latitude
                : coordinates.latitude,
            'longitude': longitude is num && longitude != 0
                ? longitude
                : coordinates.longitude,
            'imageUrl': food['image_url'] ?? '',
            'rating': rating,
            'openingHours': food['opening_hours'] ?? '',
            'openingHoursSource': food['opening_hours_source'] ?? '',
            'imageIsIllustrative': food['image_is_illustrative'] == true ? 1 : 0,
          },
        );
      } catch (error) {
        stderr.writeln(
          '❌ Không thể lưu món "$foodName" / quán "$restaurantName" '
          'vào bảng restaurant. Kiểm tra schema và quyền INSERT/UPDATE '
          'của tài khoản $dbUser trên $dbName.',
        );
        stderr.writeln('Chi tiết lỗi: $error');
        rethrow;
      }
    }

    print(
      '🎉 Hoàn tất! Đã lưu ${foods.length} quán vào bảng restaurant và '
      '${foodIdsByName.length} loại món vào bảng food.',
    );
  } finally {
    await conn.close();
  }
}
