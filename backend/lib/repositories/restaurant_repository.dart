import 'package:backend/config/database.dart';

class RestaurantRepository {
  final DatabaseConnection db;

  RestaurantRepository(this.db);

  Future<void> ensureSchema() async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant (
        id VARCHAR(191) NOT NULL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        address TEXT NOT NULL,
        food_id VARCHAR(191) NOT NULL,
        latitude DOUBLE NOT NULL,
        longitude DOUBLE NOT NULL,
        image_url TEXT NOT NULL,
        rating DOUBLE NOT NULL DEFAULT 0,
        opening_hours VARCHAR(64) NOT NULL DEFAULT '',
        opening_hours_source VARCHAR(16) NOT NULL DEFAULT '',
        image_is_illustrative TINYINT(1) NOT NULL DEFAULT 0
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
    ''');
  }

  Future<List<Map<String, dynamic>>> findAll() async {
    final results = await db.execute('''
      SELECT
        id,
        name,
        address,
        food_id,
        latitude,
        longitude,
        image_url,
        rating,
        opening_hours,
        opening_hours_source,
        image_is_illustrative
      FROM restaurant
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
        address,
        food_id,
        latitude,
        longitude,
        image_url,
        rating,
        opening_hours,
        opening_hours_source,
        image_is_illustrative
      FROM restaurant
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
    required String address,
    required String foodId,
    required double latitude,
    required double longitude,
    required String imageUrl,
    required double rating,
    required String openingHours,
    required String openingHoursSource,
    required bool imageIsIllustrative,
  }) async {
    await db.execute(
      '''
      INSERT INTO restaurant (
        id,
        name,
        address,
        food_id,
        latitude,
        longitude,
        image_url,
        rating,
        opening_hours,
        opening_hours_source,
        image_is_illustrative
      )
      VALUES (
        :id,
        :name,
        :address,
        :food_id,
        :latitude,
        :longitude,
        :image_url,
        :rating,
        :opening_hours,
        :opening_hours_source,
        :image_is_illustrative
      )
      ''',
      {
        'id': id,
        'name': name,
        'address': address,
        'food_id': foodId,
        'latitude': latitude,
        'longitude': longitude,
        'image_url': imageUrl,
        'rating': rating,
        'opening_hours': openingHours,
        'opening_hours_source': openingHoursSource,
        'image_is_illustrative': imageIsIllustrative ? 1 : 0,
      },
    );
  }

  Future<void> update({
    required String id,
    required String name,
    required String address,
    required String foodId,
    required double latitude,
    required double longitude,
    required String imageUrl,
    required double rating,
    required String openingHours,
    required String openingHoursSource,
    required bool imageIsIllustrative,
  }) async {
    await db.execute(
      '''
      UPDATE restaurant
      SET
        name = :name,
        address = :address,
        food_id = :food_id,
        latitude = :latitude,
        longitude = :longitude,
        image_url = :image_url,
        rating = :rating,
        opening_hours = :opening_hours,
        opening_hours_source = :opening_hours_source,
        image_is_illustrative = :image_is_illustrative
      WHERE id = :id
      ''',
      {
        'id': id,
        'name': name,
        'address': address,
        'food_id': foodId,
        'latitude': latitude,
        'longitude': longitude,
        'image_url': imageUrl,
        'rating': rating,
        'opening_hours': openingHours,
        'opening_hours_source': openingHoursSource,
        'image_is_illustrative': imageIsIllustrative ? 1 : 0,
      },
    );
  }

  Future<void> delete(String id) async {
    await db.execute('DELETE FROM restaurant WHERE id = :id', {'id': id});
  }
}
