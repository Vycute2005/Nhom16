import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/food.dart';
import '../config/api_config.dart';

class FoodService {
  Future<List<Food>> getFoods() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/foods'),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load foods: ${response.statusCode}',
      );
    }

    final List<dynamic> jsonList = jsonDecode(response.body);

    return jsonList
        .map((json) => Food.fromJson(json))
        .toList();
  }

  Future<void> createFood({
    required String id,
    required String name,
    required String description,
    required String imageUrl,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/foods'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'id': id,
        'name': name,
        'description': description,
        'image_url': imageUrl,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Failed to create food: ${response.statusCode}',
      );
    }
  }

  Future<void> updateFood({
    required String id,
    required String name,
    required String description,
    required String imageUrl,
  }) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/foods/$id'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'description': description,
        'image_url': imageUrl,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update food: ${response.statusCode}',
      );
    }
  }

  Future<void> deleteFood(String id) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/foods/$id'),
    );

    if (response.statusCode != 200) {
      try {
        final data = jsonDecode(response.body);

        if (data['message'] != null) {
          throw Exception(data['message']);
        }
      } catch (e) {
        if (e is Exception &&
            e.toString().contains(
              'Cannot delete food',
            )) {
          rethrow;
        }
      }

      throw Exception(
        'Failed to delete food: ${response.statusCode}',
      );
    }
  }
}