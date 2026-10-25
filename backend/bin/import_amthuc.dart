import 'dart:convert';
import 'dart:io';
import 'package:mysql1/mysql1.dart';
import 'package:dotenv/dotenv.dart';

Future<void> main() async {
  final jsonFile = File('data/amthuc.json');
  if (!await jsonFile.exists()) {
    print('❌ Không tìm thấy file data/amthuc.json!');
    return;
  }

  final List<dynamic> foodData = jsonDecode(await jsonFile.readAsString());

  var env = DotEnv()..load();
  final settings = ConnectionSettings(
    host: env['DB_HOST'] ?? '103.82.26.171',
    port: int.tryParse(env['DB_PORT'] ?? '8806') ?? 8806,
    user: env['DB_USERNAME'] ?? 'hcm_explorer',
    password: env['DB_PASSWORD'] ?? '123456',
    db: env['DB_DATABASE'] ?? 'vietnam_travel',
  );

  MySqlConnection? conn;

  try {
    conn = await MySqlConnection.connect(settings);
    print('✅ Kết nối MariaDB VPS thành công!\n');

    for (var item in foodData) {
      await conn.query(
        '''
        INSERT INTO foods (category, region, province, name, description, cultural_story, price_range, image_url, source)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE 
          category = VALUES(category),
          province = VALUES(province),
          description = VALUES(description),
          cultural_story = VALUES(cultural_story),
          price_range = VALUES(price_range),
          image_url = VALUES(image_url);
        ''',
        [
          item['category'],
          item['region'],
          item['province'],
          item['name'],
          item['description'],
          item['cultural_story'],
          item['price_range'],
          item['image_url'],
          item['source']
        ],
      );

      var res = await conn.query(
        'SELECT id FROM foods WHERE name = ? AND region = ? LIMIT 1;',
        [item['name'], item['region']],
      );

      if (res.isNotEmpty) {
        int foodId = res.first['id'];
        await conn.query('DELETE FROM food_spots WHERE food_id = ?;', [foodId]);

        if (item['spots'] != null) {
          for (var spot in item['spots']) {
            await conn.query(
              '''
              INSERT INTO food_spots (food_id, spot_name, address, price, rating, open_hours)
              VALUES (?, ?, ?, ?, ?, ?);
              ''',
              [
                foodId,
                spot['spot_name'],
                spot['address'],
                spot['price'] ?? '30.000 - 80.000 VNĐ',
                spot['rating'] ?? '4.5/5',
                spot['open_hours'] ?? '06:00 - 22:00'
              ],
            );
          }
        }
      }
    }

    print('==================================================');
    print('✅ ĐÃ BƠM THÀNH CÔNG TẤT CẢ MÓN ĂN VÀ QUÁN ĂN LÊN VPS!');
    print('==================================================');

  } catch (e) {
    print('❌ Lỗi import: $e');
  } finally {
    await conn?.close();
  }
}