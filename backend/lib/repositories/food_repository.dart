import 'package:backend/config/database.dart';

class FoodRepository {
  final DatabaseConnection db;

  FoodRepository(this.db);

  Future<void> ensureSchema() async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS foods (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        category VARCHAR(100) NOT NULL DEFAULT '',
        region VARCHAR(50) NOT NULL DEFAULT '',
        province VARCHAR(100) NOT NULL DEFAULT '',
        name VARCHAR(255) NOT NULL,
        description TEXT NOT NULL,
        cultural_story TEXT NOT NULL,
        price_range VARCHAR(100) NOT NULL DEFAULT '',
        image_url TEXT NOT NULL,
        source VARCHAR(255) NOT NULL DEFAULT ''
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS food_spots (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        food_id BIGINT UNSIGNED NOT NULL,
        spot_name VARCHAR(255) NOT NULL,
        address TEXT NOT NULL,
        price VARCHAR(100) NOT NULL DEFAULT '',
        rating VARCHAR(32) NOT NULL DEFAULT '4.5/5',
        open_hours VARCHAR(100) NOT NULL DEFAULT '06:00 - 22:00'
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ''');
  }

  Future<List<Map<String, dynamic>>> findAll() async {
    final result = await db.execute('''
      SELECT f.id, f.category, f.region, f.province, f.name,
        f.description, f.cultural_story, f.price_range, f.image_url,
        s.id AS spot_id, s.spot_name, s.address, s.price AS spot_price,
        s.rating, s.open_hours
      FROM foods f
      LEFT JOIN food_spots s ON s.food_id = f.id
      ORDER BY f.id DESC, s.id ASC
    ''');
    final foods = <String, Map<String, dynamic>>{};
    for (final row in result.rows) {
      final data = row.assoc();
      final id = data['id'] ?? '';
      final food = foods.putIfAbsent(id, () => {
        'id': id,
        'category': data['category'] ?? '',
        'region': data['region'] ?? '',
        'province': data['province'] ?? '',
        'name': data['name'] ?? '',
        'description': data['description'] ?? '',
        'cultural_story': data['cultural_story'] ?? '',
        'price_range': data['price_range'] ?? '',
        'image_url': data['image_url'] ?? '',
        'spots': <Map<String, dynamic>>[],
      });
      if (data['spot_id'] != null) {
        (food['spots'] as List<Map<String, dynamic>>).add({
          'id': data['spot_id'],
          'spot_name': data['spot_name'] ?? '',
          'address': data['address'] ?? '',
          'price': data['spot_price'] ?? '',
          'rating': data['rating'] ?? '',
          'open_hours': data['open_hours'] ?? '',
        });
      }
    }
    return foods.values.toList();
  }

  Future<Map<String, dynamic>?> findById(String id) async {
    final result = await db.execute('''
      SELECT id, category, region, province, name, description,
        cultural_story, price_range, image_url
      FROM foods WHERE id = :id
    ''', {'id': id});
    return result.rows.isEmpty ? null : result.rows.first.assoc();
  }

  Future<void> create({
    required String category,
    required String region,
    required String province,
    required String name,
    required String description,
    required String culturalStory,
    required String priceRange,
    required String imageUrl,
  }) async {
    await db.execute('''
      INSERT INTO foods (
        category, region, province, name, description,
        cultural_story, price_range, image_url
      ) VALUES (
        :category, :region, :province, :name, :description,
        :cultural_story, :price_range, :image_url
      )
    ''', {
      'category': category,
      'region': region,
      'province': province,
      'name': name,
      'description': description,
      'cultural_story': culturalStory,
      'price_range': priceRange,
      'image_url': imageUrl,
    });
  }

  Future<void> update({
    required String id,
    required String category,
    required String region,
    required String province,
    required String name,
    required String description,
    required String culturalStory,
    required String priceRange,
    required String imageUrl,
  }) async {
    await db.execute('''
      UPDATE foods SET category = :category, region = :region,
        province = :province, name = :name, description = :description,
        cultural_story = :cultural_story, price_range = :price_range,
        image_url = :image_url
      WHERE id = :id
    ''', {
      'id': id,
      'category': category,
      'region': region,
      'province': province,
      'name': name,
      'description': description,
      'cultural_story': culturalStory,
      'price_range': priceRange,
      'image_url': imageUrl,
    });
  }

  Future<void> delete(String id) async {
    await db.execute('DELETE FROM food_spots WHERE food_id = :id', {'id': id});
    await db.execute('DELETE FROM foods WHERE id = :id', {'id': id});
  }
}
