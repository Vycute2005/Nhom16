import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/restaurant.dart';

class RestaurantService {
  Future<List<Restaurant>> getRestaurants() async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/restaurants',
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load restaurants: ${response.statusCode}',
      );
    }

    final List<dynamic> jsonList =
    jsonDecode(response.body);

    return jsonList
        .map((json) => Restaurant.fromJson(json))
        .toList();
  }

  Future<void> createRestaurant({
    required String id,
    required String name,
    required String address,
    required String foodId,
    required double latitude,
    required double longitude,
    required String imageUrl,
    required double rating,
  }) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/restaurants',
      ),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'id': id,
        'name': name,
        'address': address,
        'food_id': foodId,
        'latitude': latitude,
        'longitude': longitude,
        'image_url': imageUrl,
        'rating': rating,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Failed to create restaurant: ${response.statusCode}',
      );
    }
  }

  Future<void> updateRestaurant({
    required String id,
    required String name,
    required String address,
    required String foodId,
    required double latitude,
    required double longitude,
    required String imageUrl,
    required double rating,
  }) async {
    final response = await http.put(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/restaurants/$id',
      ),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'address': address,
        'food_id': foodId,
        'latitude': latitude,
        'longitude': longitude,
        'image_url': imageUrl,
        'rating': rating,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update restaurant: ${response.statusCode}',
      );
    }
  }

  Future<void> deleteRestaurant(String id) async {
    final response = await http.delete(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/restaurants/$id',
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to delete restaurant: ${response.statusCode}',
      );
    }
  }
}