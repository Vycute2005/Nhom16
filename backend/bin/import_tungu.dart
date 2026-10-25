import 'dart:convert';
import 'dart:io';
import 'package:backend/config/database.dart';

Future<void> main() async {
  final jsonFile = File('phrases.json');
  if (!await jsonFile.exists()) {
    stderr.writeln(
      'Không tìm thấy phrases.json. Hãy chạy '
      '`dart run bin/crawl_tungu.dart` trước.',
    );
    exitCode = 1;
    return;
  }

  final decoded = jsonDecode(await jsonFile.readAsString(encoding: utf8));
  if (decoded is! List || decoded.isEmpty) {
    throw const FormatException(
      'phrases.json phải là JSON array không rỗng; từ chối import.',
    );
  }

  final phrases = <Map<String, String>>[];
  final sourceKeys = <String>{};
  for (var index = 0; index < decoded.length; index++) {
    final entry = decoded[index];
    if (entry is! Map<String, dynamic>) {
      throw FormatException(
        'Bản ghi phương ngữ #${index + 1} phải là JSON object.',
      );
    }

    final phrase = <String, String>{
      'category': (entry['category'] as String?)?.trim().isNotEmpty == true
          ? (entry['category'] as String).trim()
          : 'Phương ngữ 3 miền',
      'meaning': (entry['meaning'] as String?)?.trim() ?? '',
      'north_word': (entry['north_word'] as String?)?.trim() ?? '',
      'central_word': (entry['central_word'] as String?)?.trim() ?? '',
      'south_word': (entry['south_word'] as String?)?.trim() ?? '',
    };
    if (phrase['meaning']!.isEmpty ||
        (phrase['north_word']!.isEmpty &&
            phrase['central_word']!.isEmpty &&
            phrase['south_word']!.isEmpty)) {
      throw FormatException(
        'Bản ghi phương ngữ #${index + 1} thiếu nghĩa hoặc từ vùng miền.',
      );
    }

    final key = jsonEncode([
      phrase['meaning'],
      phrase['north_word'],
      phrase['central_word'],
      phrase['south_word'],
    ]);
    if (!sourceKeys.add(key)) {
      throw FormatException(
        'Bản ghi phương ngữ #${index + 1} bị lặp trong phrases.json.',
      );
    }
    phrases.add(phrase);
  }

  DatabaseConnection? db;
  try {
    db = await Database.connect(
  
);
    await db.execute('''
      CREATE TABLE IF NOT EXISTS phrases (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        category VARCHAR(100) NOT NULL DEFAULT 'Phương ngữ 3 miền',
        meaning VARCHAR(255) NOT NULL,
        north_word VARCHAR(100) NOT NULL DEFAULT '',
        central_word VARCHAR(100) NOT NULL DEFAULT '',
        south_word VARCHAR(100) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_phrases_regional_words (
          meaning,
          north_word,
          central_word,
          south_word
        )
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ''');

    var insertedCount = 0;
    var updatedCount = 0;
    for (final phrase in phrases) {
      final params = {
        'category': phrase['category'],
        'meaning': phrase['meaning'],
        'north_word': phrase['north_word'],
        'central_word': phrase['central_word'],
        'south_word': phrase['south_word'],
      };
      final matchingRows = await db.execute('''
        SELECT id
        FROM phrases
        WHERE meaning = :meaning
          AND north_word = :north_word
          AND central_word = :central_word
          AND south_word = :south_word
        LIMIT 1
        ''', params);

      if (matchingRows.rows.isEmpty) {
        await db.execute('''
          INSERT INTO phrases (
            category,
            meaning,
            north_word,
            central_word,
            south_word
          )
          VALUES (
            :category,
            :meaning,
            :north_word,
            :central_word,
            :south_word
          )
          ''', params);
        insertedCount++;
      } else {
        await db.execute('''
          UPDATE phrases
          SET category = :category
          WHERE meaning = :meaning
            AND north_word = :north_word
            AND central_word = :central_word
            AND south_word = :south_word
          ''', params);
        updatedCount++;
      }
    }

    final countResult = await db.execute(
      'SELECT COUNT(*) AS total FROM phrases',
    );
    final totalCount = countResult.rows.first.assoc()['total'];
    print(
      'Đã nạp ${phrases.length} bản ghi phương ngữ vào MariaDB '
      '($insertedCount mới, $updatedCount đã có).',
    );
    print('Tổng số bản ghi trong phrases: $totalCount.');
  } catch (error, stackTrace) {
    stderr.writeln('Không thể lưu dữ liệu cào vào MariaDB: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  } finally {
    await db?.close();
  }
}
