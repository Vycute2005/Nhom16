import 'dart:io';

import 'package:backend/config/database.dart';
import 'package:backend/utils/tourist_province.dart';

class TouristPlaceRepository {
  final DatabaseConnection db;

  TouristPlaceRepository(this.db);

  Future<void> ensureSchema() async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tourist_place (
        id VARCHAR(191) NOT NULL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        image_url TEXT NOT NULL,
        history TEXT NOT NULL,
        culture TEXT NOT NULL,
        address TEXT NOT NULL,
        province VARCHAR(100) NOT NULL DEFAULT '',
        latitude DOUBLE NULL,
        longitude DOUBLE NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
    ''');

    final provinceColumn = await db.execute('''
      SELECT COUNT(*) AS total
      FROM information_schema.columns
      WHERE table_schema = DATABASE()
        AND table_name = 'tourist_place'
        AND column_name = 'province'
    ''');
    final hasProvince =
        int.tryParse(provinceColumn.rows.first.assoc()['total'] ?? '') ?? 0;
    if (hasProvince == 0) {
      await db.execute(
        "ALTER TABLE tourist_place ADD COLUMN province VARCHAR(100) NOT NULL DEFAULT ''",
      );
    }

    final createdAtColumn = await db.execute('''
      SELECT COUNT(*) AS total
      FROM information_schema.columns
      WHERE table_schema = DATABASE()
        AND table_name = 'tourist_place'
        AND column_name = 'created_at'
    ''');
    final hasCreatedAt =
        int.tryParse(createdAtColumn.rows.first.assoc()['total'] ?? '') ?? 0;
    if (hasCreatedAt == 0) {
      await db.execute(
        'ALTER TABLE tourist_place ADD COLUMN created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP',
      );
    }
    final unclassifiedPlaces = await db.execute('''
      SELECT id, name, address
      FROM tourist_place
      WHERE province = ''
    ''');
    for (final row in unclassifiedPlaces.rows) {
      final place = row.assoc();
      final province = resolveTouristProvince(
        name: place['name'] ?? '',
        address: place['address'] ?? '',
      );
      if (province == null) continue;
      await db.execute(
        'UPDATE tourist_place SET province = :province WHERE id = :id',
        {'province': province, 'id': place['id']},
      );
    }
  }

  Future<List<Map<String, dynamic>>> findAll({
    List<String> provinces = const [],
  }) async {
    await syncDestinationsIfAvailable();

    final parameters = <String, String>{};
    var provinceFilter = '';
    if (provinces.isNotEmpty) {
      final conditions = <String>[];
      for (var index = 0; index < provinces.length; index++) {
        final provinceParameter = 'province$index';
        final addressParameter = 'address$index';
        parameters[provinceParameter] = '%${provinces[index]}%';
        parameters[addressParameter] = '%${provinces[index]}%';
        conditions.add(
          "(province LIKE :$provinceParameter OR "
          "(province = '' AND address LIKE :$addressParameter))",
        );
      }
      provinceFilter = 'WHERE ${conditions.join(' OR ')}';
    }

    final results = await db.execute('''
      SELECT
        id,
        name,
        image_url,
        history,
        culture,
        address,
        province,
        latitude,
        longitude
      FROM tourist_place
      $provinceFilter
      ORDER BY created_at DESC, id DESC, name
    ''', parameters);

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
        province,
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
    required String province,
    required double? latitude,
    required double? longitude,
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
        province,
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
        :province,
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
        'province': province,
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
    required String province,
    required double? latitude,
    required double? longitude,
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
        province = :province,
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
        'province': province,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  Future<void> delete(String id) async {
    await db.execute('DELETE FROM tourist_place WHERE id = :id', {'id': id});
  }

  Future<int> countAll() async {
    final result = await db.execute(
      'SELECT COUNT(*) AS total FROM tourist_place',
    );
    return int.tryParse(result.rows.first.assoc()['total'] ?? '') ?? 0;
  }

  Future<int> syncDestinationsIfAvailable() async {
    final tableResult = await db.execute('''
      SELECT COUNT(*) AS total
      FROM information_schema.tables
      WHERE table_schema = DATABASE()
        AND table_name = 'destinations'
    ''');
    final hasDestinations =
        int.tryParse(tableResult.rows.first.assoc()['total'] ?? '') ?? 0;
    if (hasDestinations == 0) return 0;

    final columnResult = await db.execute('''
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = DATABASE()
        AND table_name = 'destinations'
    ''');
    final columns = columnResult.rows
        .map((row) => row.assoc()['column_name'])
        .whereType<String>()
        .toSet();
    const requiredColumns = {
      'name',
      'address',
      'description',
      'image_url',
      'category',
      'latitude',
      'longitude',
    };
    final missingColumns = requiredColumns.difference(columns);
    if (missingColumns.isNotEmpty) {
      throw StateError(
        'Table destinations is missing columns: '
        '${missingColumns.join(', ')}',
      );
    }

    final sourceResults = await db.execute('''
      SELECT name, address, description, image_url, category, latitude, longitude
      FROM destinations
    ''');
    final existingResults = await db.execute(
      'SELECT id, name FROM tourist_place',
    );
    final idsByName = <String, String>{};
    for (final row in existingResults.rows) {
      final place = row.assoc();
      final name = _normalizePlaceName(place['name'] ?? '');
      final id = place['id'];
      if (name.isNotEmpty && id != null) {
        idsByName.putIfAbsent(name, () => id);
      }
    }

    final unresolvedPlaces = <String>[];
    final placesByName = <String, Map<String, dynamic>>{};
    for (final row in sourceResults.rows) {
      final source = row.assoc();
      final name = source['name']?.trim() ?? '';
      final address = source['address']?.trim() ?? '';
      final province = resolveTouristProvince(name: name, address: address);
      final latitude = double.tryParse(source['latitude'] ?? '');
      final longitude = double.tryParse(source['longitude'] ?? '');
      if (name.isEmpty ||
          address.isEmpty ||
          province == null ||
          latitude == null ||
          longitude == null) {
        unresolvedPlaces.add(name.isEmpty ? address : name);
        continue;
      }

      final normalizedName = _normalizePlaceName(name);
      final id =
          idsByName[normalizedName] ??
          'destinations-${normalizedName.replaceAll(' ', '-').substring(0, normalizedName.length > 180 ? 180 : normalizedName.length)}';
      idsByName[normalizedName] = id;
      placesByName[normalizedName] = {
        'id': id,
        'name': name,
        'image_url': source['image_url'] ?? '',
        'history': source['description'] ?? '',
        'culture': source['category'] ?? '',
        'address': address,
        'province': province,
        'latitude': latitude,
        'longitude': longitude,
      };
    }

    final places = placesByName.values.toList();
    for (var offset = 0; offset < places.length; offset += 100) {
      final batch = places.skip(offset).take(100).toList();
      final parameters = <String, dynamic>{};
      final valueGroups = <String>[];
      for (var index = 0; index < batch.length; index++) {
        final place = batch[index];
        final keys = [
          'id',
          'name',
          'image_url',
          'history',
          'culture',
          'address',
          'province',
          'latitude',
          'longitude',
        ];
        final placeholders = <String>[];
        for (final key in keys) {
          final parameter = '${key}_$index';
          placeholders.add(':$parameter');
          parameters[parameter] = place[key];
        }
        valueGroups.add('(${placeholders.join(', ')})');
      }

      await db.execute('''
        INSERT INTO tourist_place (
          id, name, image_url, history, culture, address, province,
          latitude, longitude
        )
        VALUES ${valueGroups.join(', ')}
        ON DUPLICATE KEY UPDATE
          name = VALUES(name),
          image_url = IF(VALUES(image_url) <> '', VALUES(image_url), image_url),
          history = VALUES(history),
          culture = VALUES(culture),
          address = VALUES(address),
          province = VALUES(province),
          latitude = VALUES(latitude),
          longitude = VALUES(longitude)
      ''', parameters);
    }

    if (unresolvedPlaces.isNotEmpty) {
      stderr.writeln(
        'Skipped ${unresolvedPlaces.length} rows from destinations because '
        'their address, coordinates, or province could not be resolved:',
      );
      for (final place in unresolvedPlaces) {
        stderr.writeln(' - $place');
      }
    }
    return places.length;
  }

  String _normalizePlaceName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
