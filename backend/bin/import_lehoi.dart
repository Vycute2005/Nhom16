import 'dart:convert';
import 'dart:io';
import 'package:mysql1/mysql1.dart';
import 'package:dotenv/dotenv.dart';

Future<void> main() async {
  // 1. Kiểm tra file JSON
  final jsonFile = File('data/lehoi.json');
  if (!await jsonFile.exists()) {
    print('❌ Không tìm thấy file data/lehoi.json! Hãy chạy script crawl_lehoi.dart trước.');
    return;
  }

  final List<dynamic> festivalData = jsonDecode(await jsonFile.readAsString());
  print('📌 Tìm thấy ${festivalData.length} lễ hội trong file JSON.');

  // 2. Tải cấu hình kết nối từ file .env
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

    int successCount = 0;

    // 3. Import từng lễ hội vào MariaDB
    for (var item in festivalData) {
      try {
        await conn.query(
          '''
          INSERT INTO festivals (name, time_period, location, highlights, travel_info, source)
          VALUES (?, ?, ?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE 
            time_period = VALUES(time_period),
            location = VALUES(location),
            highlights = VALUES(highlights),
            travel_info = VALUES(travel_info);
          ''',
          [
            item['name'],
            item['time_period'],
            item['location'],
            item['highlights'],
            item['travel_info'],
            item['source']
          ],
        );
        successCount++;
      } catch (e) {
        // Bỏ qua nếu dòng dữ liệu trùng lặp
      }
    }

    print('==================================================');
    print('✅ ĐÃ IMPORT THÀNH CÔNG $successCount/${festivalData.length} LỄ HỘI VÀO MARIADB VPS!');
    print('==================================================');

  } catch (e) {
    print('❌ Lỗi kết nối/import dữ liệu: $e');
  } finally {
    await conn?.close();
  }
}