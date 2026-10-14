import 'package:mysql_client/mysql_client.dart';

class TouristPlaceRepository {
  final MySQLConnection db;

  TouristPlaceRepository(this.db);

  Future<List<Map<String, dynamic>>> findAll() async {
    final results = await db.execute('''
      SELECT
        id,
        name,
        image_url,
        history,
        culture,
        address,
        latitude,
        longitude
      FROM tourist_place
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
        name,
        image_url,
        history,
        culture,
        address,
        latitude,
        longitude
      FROM tourist_place
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
    required String name,
    required String imageUrl,
    required String history,
    required String culture,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    await db.execute(
      '''
      INSERT INTO tourist_place (
        id,
        name,
        image_url,
        history,
        culture,
        address,
        latitude,
        longitude
      )
      VALUES (
        :id,
        :name,
        :image_url,
        :history,
        :culture,
        :address,
        :latitude,
        :longitude
      )
      ''',
      {
        'id': id,
        'name': name,
        'image_url': imageUrl,
        'history': history,
        'culture': culture,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  Future<void> update({
    required String id,
    required String name,
    required String imageUrl,
    required String history,
    required String culture,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    await db.execute(
      '''
      UPDATE tourist_place
      SET
        name = :name,
        image_url = :image_url,
        history = :history,
        culture = :culture,
        address = :address,
        latitude = :latitude,
        longitude = :longitude
      WHERE id = :id
      ''',
      {
        'id': id,
        'name': name,
        'image_url': imageUrl,
        'history': history,
        'culture': culture,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  Future<void> delete(String id) async {
    await db.execute(
      'DELETE FROM tourist_place WHERE id = :id',
      {'id': id},
    );
  }
}