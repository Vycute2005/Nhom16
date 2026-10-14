import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:mysql_client/mysql_client.dart';

Future<void> main() async {
  final dotenv = DotEnv()..load();
  final file = File('assets/data/slangs.json');
  if (!await file.exists()) {
    stderr.writeln(
      '❌ Không tìm thấy assets/data/slangs.json. Hãy chạy '
      '`dart run bin/crawl_vanhoa.dart` trước.',
    );
    exitCode = 1;
    return;
  }

  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! List || decoded.isEmpty) {
    throw const FormatException(
      'slangs.json phải là JSON array không rỗng; từ chối import.',
    );
  }

  final slangs = <Map<String, String>>[];
  for (var index = 0; index < decoded.length; index++) {
    final entry = decoded[index];
    if (entry is! Map<String, dynamic>) {
      throw FormatException(
        'Mục #${index + 1} trong slangs.json phải là một JSON object.',
      );
    }
    final term = entry['term'];
    final meaning = entry['meaning'];
    final audioUrl = entry['audio_url'] ?? '';
    final context = entry['context'] ?? 'Văn hóa Nam Bộ';
    if (term is! String ||
        term.trim().isEmpty ||
        meaning is! String ||
        meaning.trim().isEmpty ||
        audioUrl is! String ||
        context is! String) {
      throw FormatException(
        'Mục #${index + 1} trong slangs.json thiếu term/meaning hợp lệ '
        'hoặc có audio_url/context sai kiểu.',
      );
    }
    slangs.add({
      'term': term.trim(),
      'meaning': meaning.trim(),
      'audio_url': audioUrl.trim(),
      'context': context.trim(),
    });
  }

  final host = dotenv['DB_HOST'] ?? '103.82.26.171';
  final portValue = dotenv['DB_PORT'] ?? '8806';
  final port = int.tryParse(portValue);
  if (port == null) {
    throw FormatException('DB_PORT không hợp lệ: $portValue');
  }
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
    'Đang kết nối MariaDB tại $host:$port '
    '(user: $user, database: $database)...',
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
  print('✅ Kết nối MariaDB thành công!');

  try {
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS slangs (
        term VARCHAR(255) NOT NULL PRIMARY KEY,
        meaning TEXT NOT NULL,
        audio_url TEXT NOT NULL,
        context VARCHAR(255) NOT NULL
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
    ''');

    var insertedCount = 0;
    var updatedCount = 0;
    for (var index = 0; index < slangs.length; index++) {
      final slang = slangs[index];
      try {
        final existing = await conn.execute(
          'SELECT term FROM slangs WHERE term = :term LIMIT 1',
          {'term': slang['term']},
        );
        if (existing.rows.isEmpty) {
          await conn.execute(
            '''
            INSERT INTO slangs (term, meaning, audio_url, context)
            VALUES (:term, :meaning, :audioUrl, :context)
            ''',
            {
              'term': slang['term'],
              'meaning': slang['meaning'],
              'audioUrl': slang['audio_url'],
              'context': slang['context'],
            },
          );
          insertedCount++;
        } else {
          await conn.execute(
            '''
            UPDATE slangs
            SET meaning = :meaning, audio_url = :audioUrl, context = :context
            WHERE term = :term
            ''',
            {
              'term': slang['term'],
              'meaning': slang['meaning'],
              'audioUrl': slang['audio_url'],
              'context': slang['context'],
            },
          );
          updatedCount++;
        }
      } catch (error) {
        stderr.writeln(
          '❌ Không thể lưu "${slang['term']}" vào bảng slangs '
          '(mục #${index + 1}/${slangs.length}). '
          'Kiểm tra schema và quyền SELECT/INSERT/UPDATE của tài khoản $user '
          'trên $database.',
        );
        stderr.writeln('Chi tiết lỗi: $error');
        rethrow;
      }
    }

    print(
      '✅ Đã đồng bộ ${slangs.length} từ ngữ vào slangs '
      '($insertedCount thêm mới, $updatedCount cập nhật).',
    );
  } finally {
    await conn.close();
  }
}
