import 'package:backend/config/database.dart';

class PhraseRepository {
  final DatabaseConnection db;

  PhraseRepository(this.db);

  Future<void> ensureSchema() async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS phrases (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        category VARCHAR(100) NOT NULL DEFAULT 'Phương ngữ 3 miền',
        meaning VARCHAR(255) NOT NULL,
        north_word VARCHAR(100) NOT NULL DEFAULT '',
        central_word VARCHAR(100) NOT NULL DEFAULT '',
        south_word VARCHAR(100) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_phrases_regional_words
          (meaning, north_word, central_word, south_word)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ''');
  }

  Future<List<Map<String, dynamic>>> findAll() async {
    final result = await db.execute('''
      SELECT id, category, meaning, north_word, central_word, south_word
      FROM phrases ORDER BY created_at DESC, id DESC
    ''');
    return result.rows.map((row) => row.assoc()).toList();
  }

  Future<Map<String, dynamic>?> findById(String id) async {
    final result = await db.execute('''
      SELECT id, category, meaning, north_word, central_word, south_word
      FROM phrases WHERE id = :id
    ''', {'id': id});
    return result.rows.isEmpty ? null : result.rows.first.assoc();
  }

  Future<void> create({
    required String category,
    required String meaning,
    required String northWord,
    required String centralWord,
    required String southWord,
  }) async {
    await db.execute('''
      INSERT INTO phrases (category, meaning, north_word, central_word, south_word)
      VALUES (:category, :meaning, :north_word, :central_word, :south_word)
    ''', {
      'category': category,
      'meaning': meaning,
      'north_word': northWord,
      'central_word': centralWord,
      'south_word': southWord,
    });
  }

  Future<void> update({
    required String id,
    required String category,
    required String meaning,
    required String northWord,
    required String centralWord,
    required String southWord,
  }) async {
    await db.execute('''
      UPDATE phrases SET category = :category, meaning = :meaning,
        north_word = :north_word, central_word = :central_word,
        south_word = :south_word
      WHERE id = :id
    ''', {
      'id': id,
      'category': category,
      'meaning': meaning,
      'north_word': northWord,
      'central_word': centralWord,
      'south_word': southWord,
    });
  }

  Future<void> delete(String id) async {
    await db.execute('DELETE FROM phrases WHERE id = :id', {'id': id});
  }
}
