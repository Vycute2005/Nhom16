import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/phrase.dart';

class PhraseService {
  Future<List<Phrase>> getPhrases() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/phrases'),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load phrases: ${response.statusCode}',
      );
    }

    final List<dynamic> jsonList = jsonDecode(response.body);

    return jsonList.map((json) => Phrase.fromJson(json)).toList();
  }

  Future<void> createPhrase({
    required String id,
    required String vietnamese,
    required String pronunciation,
    required String english,
    required String explanation,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/phrases'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'id': id,
        'vietnamese': vietnamese,
        'pronunciation': pronunciation,
        'english': english,
        'explanation': explanation,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Failed to create phrase: ${response.statusCode}',
      );
    }
  }

  Future<void> updatePhrase({
    required String id,
    required String vietnamese,
    required String pronunciation,
    required String english,
    required String explanation,
  }) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/phrases/$id'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'vietnamese': vietnamese,
        'pronunciation': pronunciation,
        'english': english,
        'explanation': explanation,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update phrase: ${response.statusCode}',
      );
    }
  }

  Future<void> deletePhrase(String id) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/phrases/$id'),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to delete phrase: ${response.statusCode}',
      );
    }
  }
}
