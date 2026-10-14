import 'package:mysql_client/mysql_client.dart';

class PhraseRepository {
  final MySQLConnection db;

  PhraseRepository(this.db);

  Future<List<Map<String, dynamic>>> findAll() async {
    final results = await db.execute('''
      SELECT
        id,
        vietnamese,
        pronunciation,
        english,
        explanation
      FROM phrase
    ''');

    return results.rows.map((row) {
      return row.assoc();
    }).toList();
  }

  Future<Map<String, dynamic>?> findById(String id) async {
    final results = await db.execute(
      '''
      SELECT
        id,
        vietnamese,
        pronunciation,
        english,
        explanation
      FROM phrase
      WHERE id = :id
      ''',
      {'id': id},
    );

    if (results.rows.isEmpty) {
      return null;
    }

    return results.rows.first.assoc();
  }

  Future<void> create({
    required String id,
    required String vietnamese,
    required String pronunciation,
    required String english,
    required String explanation,
  }) async {
    await db.execute(
      '''
      INSERT INTO phrase (
        id,
        vietnamese,
        pronunciation,
        english,
        explanation
      )
      VALUES (
        :id,
        :vietnamese,
        :pronunciation,
        :english,
        :explanation
      )
      ''',
      {
        'id': id,
        'vietnamese': vietnamese,
        'pronunciation': pronunciation,
        'english': english,
        'explanation': explanation,
      },
    );
  }

  Future<void> update({
    required String id,
    required String vietnamese,
    required String pronunciation,
    required String english,
    required String explanation,
  }) async {
    await db.execute(
      '''
      UPDATE phrase
      SET
        vietnamese = :vietnamese,
        pronunciation = :pronunciation,
        english = :english,
        explanation = :explanation
      WHERE id = :id
      ''',
      {
        'id': id,
        'vietnamese': vietnamese,
        'pronunciation': pronunciation,
        'english': english,
        'explanation': explanation,
      },
    );
  }

  Future<void> delete(String id) async {
    await db.execute(
      'DELETE FROM phrase WHERE id = :id',
      {'id': id},
    );
  }
}