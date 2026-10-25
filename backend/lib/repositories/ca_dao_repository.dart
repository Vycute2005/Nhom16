import 'dart:convert';
import 'dart:io';

import 'package:backend/config/database.dart';

class CaDaoRepository {
  final DatabaseConnection db;

  CaDaoRepository(this.db);

  Future<void> ensureSchema() async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ca_dao (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        type VARCHAR(100) NOT NULL DEFAULT 'Ca dao',
        category VARCHAR(150) NOT NULL DEFAULT 'Văn hóa & Phong tục',
        content TEXT NOT NULL,
        meaning TEXT NOT NULL,
        source TEXT NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_ca_dao_content (content(191))
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vn_guide_data_migrations (
        migration_key VARCHAR(100) NOT NULL PRIMARY KEY,
        completed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ''');
  }

  Future<void> seedBundledData() async {
    final migration = await db.execute('''
      SELECT migration_key FROM vn_guide_data_migrations
      WHERE migration_key = :migration_key
    ''', {'migration_key': 'seed_ca_dao_json_v1'});
    if (migration.rows.isNotEmpty) return;

    File? jsonFile;
    for (final path in [
      'data/cadao_vanhoa.json',
      'backend/data/cadao_vanhoa.json',
    ]) {
      final candidate = File(path);
      if (await candidate.exists()) {
        jsonFile = candidate;
        break;
      }
    }
    if (jsonFile == null) return;

    final existing = await db.execute('SELECT content FROM ca_dao');
    final hasValidEntry = existing.rows.any(
      (row) => _isValidEntry(row.assoc()['content'] ?? ''),
    );
    if (!hasValidEntry) {
      final decoded = jsonDecode(await jsonFile.readAsString());
      if (decoded is List) {
        for (final raw in decoded.whereType<Map>().toList().reversed) {
          final item = Map<String, dynamic>.from(raw);
          final content = item['content']?.toString().trim() ?? '';
          if (!_isValidEntry(content)) continue;
          await db.execute('''
            INSERT IGNORE INTO ca_dao (type, category, content, meaning, source)
            VALUES (:type, :category, :content, :meaning, :source)
          ''', {
            'type': item['type']?.toString().trim().isNotEmpty == true
                ? item['type'].toString()
                : 'Ca dao',
            'category': item['category']?.toString().trim().isNotEmpty == true
                ? item['category'].toString()
                : 'Văn hóa & Phong tục',
            'content': content,
            'meaning': item['meaning']?.toString() ?? '',
            'source': item['source']?.toString() ?? '',
          });
        }
      }
    }
    await db.execute('''
      INSERT IGNORE INTO vn_guide_data_migrations (migration_key)
      VALUES (:migration_key)
    ''', {'migration_key': 'seed_ca_dao_json_v1'});
  }

  bool _isValidEntry(String content) {
    if (content.isEmpty || content.length > 500) return false;
    final normalized = content.toLowerCase();
    const noise = [
      'bỏ qua để tới nội dung',
      'đăng nhập',
      'quay về trang chính',
      'ca-dao.com',
      'kho dữ liệu ca dao',
      'tất cả thể loại',
      'trang chủ',
      'đăng ký',
      'tìm kiếm',
      'xem thêm',
      'đọc thêm',
    ];
    return !noise.any(normalized.contains);
  }

  Future<List<Map<String, dynamic>>> findAll() async {
    final result = await db.execute('''
      SELECT id, type, category, content, meaning, source
      FROM ca_dao ORDER BY id DESC
    ''');
    return result.rows
        .map((row) => row.assoc())
        .where((row) => _isValidEntry(row['content'] ?? ''))
        .toList();
  }

  Future<Map<String, dynamic>?> findById(String id) async {
    final result = await db.execute('''
      SELECT id, type, category, content, meaning, source
      FROM ca_dao WHERE id = :id
    ''', {'id': id});
    return result.rows.isEmpty ? null : result.rows.first.assoc();
  }

  Future<void> create(Map<String, dynamic> data) async {
    await db.execute('''
      INSERT INTO ca_dao (type, category, content, meaning, source)
      VALUES (:type, :category, :content, :meaning, :source)
    ''', _values(data));
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await db.execute('''
      UPDATE ca_dao SET type = :type, category = :category,
        content = :content, meaning = :meaning
      WHERE id = :id
    ''', {..._values(data), 'id': id});
  }

  Map<String, dynamic> _values(Map<String, dynamic> data) => {
        'type': data['type']?.toString().trim().isNotEmpty == true
            ? data['type'].toString().trim()
            : 'Ca dao',
        'category': data['category']?.toString().trim().isNotEmpty == true
            ? data['category'].toString().trim()
            : 'Văn hóa & Phong tục',
        'content': data['content']?.toString().trim() ?? '',
        'meaning': data['meaning']?.toString() ?? '',
        'source': data['source']?.toString() ?? '',
      };

  Future<void> delete(String id) async {
    await db.execute('DELETE FROM ca_dao WHERE id = :id', {'id': id});
  }
}
