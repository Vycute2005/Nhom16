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
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/uploads').replace(
      queryParameters: {'folder': folder},
    );
    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ),
    );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 45),
      onTimeout: () => throw Exception(
        'Máy chủ tải ảnh phản hồi quá chậm. Vui lòng thử lại.',
      ),
    );

    final response = await http.Response.fromStream(
      streamedResponse,
    ).timeout(
      const Duration(seconds: 45),
      onTimeout: () => throw Exception(
        'Máy chủ tải ảnh phản hồi quá chậm. Vui lòng thử lại.',
      ),
    );

    if (response.statusCode != 200) {
      try {
        final data = jsonDecode(response.body);

        if (data['message'] != null) {
          if (data['message'] == 'Invalid upload folder.') {
            throw Exception(
              'Backend đang chạy phiên bản cũ, chưa hỗ trợ tải ảnh đại diện. '
              'Hãy dừng server cũ rồi khởi động lại backend.',
            );
          }
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
