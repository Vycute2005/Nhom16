import 'package:mysql_client/mysql_client.dart';

class FoodRepository {
  final MySQLConnection db;

  FoodRepository(this.db);

  Future<List<Map<String, dynamic>>> findAll() async {
    final results = await db.execute(
      'SELECT id, name, description, image_url FROM food',
    );

    return results.rows.map((row) {
      return row.assoc();
    }).toList();
  }

  Future<Map<String, dynamic>?> findById(String id) async {
    final results = await db.execute(
      'SELECT id, name, description, image_url FROM food WHERE id = :id',
      {'id': id},
    );

    if (results.rows.isEmpty) {
      return null;
    }

    return results.rows.first.assoc();
  }

  Future<void> create({
    required String id,
    required String name,
    required String description,
    required String imageUrl,
  }) async {
    await db.execute(
      '''
      INSERT INTO food (
        id,
        name,
        description,
        image_url
      )
      VALUES (
        :id,
        :name,
        :description,
        :image_url
      )
      ''',
      {
        'id': id,
        'name': name,
        'description': description,
        'image_url': imageUrl,
      },
    );
  }

  Future<void> update({
    required String id,
    required String name,
    required String description,
    required String imageUrl,
  }) async {
    await db.execute(
      '''
      UPDATE food
      SET
        name = :name,
        description = :description,
        image_url = :image_url
      WHERE id = :id
      ''',
      {
        'id': id,
        'name': name,
        'description': description,
        'image_url': imageUrl,
      },
    );
  }

  Future<void> delete(String id) async {
    await db.execute(
      'DELETE FROM food WHERE id = :id',
      {'id': id},
    );
  }
}