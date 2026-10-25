import 'dart:convert';
import 'dart:io';
import 'package:mysql1/mysql1.dart';
import 'package:dotenv/dotenv.dart';

Future<void> main() async {
  final jsonFile = File('data/cadao_vanhoa.json');
  if (!await jsonFile.exists()) {
    print('❌ Không thấy file data/cadao_vanhoa.json! Hãy chạy script crawl_cadao.dart trước.');
    return;
  }

  final List<dynamic> cadaoData = jsonDecode(await jsonFile.readAsString());
  print('📌 Tìm thấy ${cadaoData.length} bản ghi trong file JSON.');

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

    for (var item in cadaoData) {
      try {
        await conn.query(
          '''
          INSERT INTO ca_dao (type, category, content, meaning, source)
          VALUES (?, ?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE 
            type = VALUES(type),
            category = VALUES(category),
            meaning = VALUES(meaning);
          ''',
          [item['type'], item['category'], item['content'], item['meaning'], item['source']],
        );
        successCount++;
      } catch (e) {
        // Bỏ qua nếu dòng bị trùng lặp
      }
    }

    print('==================================================');
    print('✅ ĐÃ IMPORT THÀNH CÔNG $successCount/${cadaoData.length} BẢN GHI VÀO VPS!');
    print('==================================================');

  } catch (e) {
    print('❌ Lỗi kết nối/nhập dữ liệu: $e');
  } finally {
    await conn?.close();
  }
}