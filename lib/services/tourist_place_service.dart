import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/tourist_place.dart';

class TouristPlaceService {
  Future<List<TouristPlace>> getTouristPlaces() async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/tourist-places',
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load tourist places: ${response.statusCode}',
      );
    }

    final List<dynamic> jsonList =
    jsonDecode(response.body);

    return jsonList
        .map((json) => TouristPlace.fromJson(json))
        .toList();
  }

  Future<void> createTouristPlace({
    required String id,
    required String name,
    required String imageUrl,
    required String history,
    required String culture,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/tourist-places',
      ),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'id': id,
        'name': name,
        'image_url': imageUrl,
        'history': history,
        'culture': culture,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Failed to create tourist place: ${response.statusCode}',
      );
    }
  }

  Future<void> updateTouristPlace({
    required String id,
    required String name,
    required String imageUrl,
    required String history,
    required String culture,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    final response = await http.put(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/tourist-places/$id',
      ),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'image_url': imageUrl,
        'history': history,
        'culture': culture,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update tourist place: ${response.statusCode}',
      );
    }
  }

  Future<void> deleteTouristPlace(String id) async {
    final response = await http.delete(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/tourist-places/$id',
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to delete tourist place: ${response.statusCode}',
      );
    }
  }
}