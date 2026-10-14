import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class UploadService {
  Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
    String folder = 'foods',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '${ApiConfig.baseUrl}/api/uploads?folder=$folder',
      ),
    );

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ),
    );

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(
      streamedResponse,
    );

    if (response.statusCode != 200) {
      try {
        final data = jsonDecode(response.body);

        if (data['message'] != null) {
          throw Exception(data['message']);
        }
      } catch (e) {
        if (e is Exception &&
            !e.toString().contains('FormatException')) {
          rethrow;
        }
      }

      throw Exception(
        'Failed to upload image: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    return data['path'].toString();
  }
}