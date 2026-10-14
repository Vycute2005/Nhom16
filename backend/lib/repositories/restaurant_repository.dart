import 'package:mysql_client/mysql_client.dart';

class RestaurantRepository {
  final MySQLConnection db;

  RestaurantRepository(this.db);

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
    await db.execute(
      'DELETE FROM restaurant WHERE id = :id',
      {'id': id},
    );
  }
}