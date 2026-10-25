import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class AuthApiException implements Exception {
  const AuthApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Client wrapper for the VN Guide backend authentication endpoints.
/// This does not store the token automatically; save it using the app's
/// existing secure/session storage after a successful login or registration.
class AuthApiService {
  static const _requestTimeout = Duration(seconds: 15);

  AuthApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? ApiConfig.baseUrl).replaceFirst(RegExp(r'/$'), '');

  final http.Client _client;
  final String _baseUrl;

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<http.Response> _request(Future<http.Response> request) async {
    try {
      return await request.timeout(_requestTimeout);
    } on TimeoutException {
      throw const AuthApiException(
        'Máy chủ phản hồi quá chậm. Vui lòng thử lại sau.',
      );
    }
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String fullName = '',
  }) {
    return _post('/api/auth/register', {
      'username': username.trim(),
      'email': email.trim(),
      'password': password,
      'fullName': fullName.trim(),
    });
  }

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) {
    return _post('/api/auth/login', {
      'identifier': identifier.trim(),
      'password': password,
    });
  }

  Future<Map<String, dynamic>> googleLogin({required String idToken}) {
    return _post('/api/auth/google', {'idToken': idToken});
  }

  Future<Map<String, dynamic>> forgotPassword({required String email}) {
    return _post('/api/auth/forgot-password', {'email': email.trim()});
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    return _post('/api/auth/reset-password', {
      'email': email.trim(),
      'otp': otp.trim(),
      'newPassword': newPassword,
    });
  }

  Future<Map<String, dynamic>> me({required String token}) async {
    final response = await _request(_client.get(
      _uri('/api/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    ));
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> adminCheck({required String token}) async {
    final response = await _request(_client.get(
      _uri('/api/auth/admin-check'),
      headers: {'Authorization': 'Bearer $token'},
    ));
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> updateProfile({
    required String token,
    required String username,
    required String email,
    required String fullName,
    String nationality = '',
    String avatarUrl = '',
  }) {
    return _authorizedPost('/api/auth/profile', token, {
      'username': username.trim(),
      'email': email.trim(),
      'fullName': fullName.trim(),
      'nationality': nationality.trim(),
      'avatarUrl': avatarUrl.trim(),
    });
  }

  Future<Map<String, dynamic>> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) {
    return _authorizedPost('/api/auth/change-password', token, {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<Map<String, dynamic>> logout({required String token}) {
    return _authorizedPost('/api/auth/logout', token, const {});
  }

  Future<List<Map<String, dynamic>>> getFavorites({
    required String token,
  }) async {
    final response = await _request(_client.get(
      _uri('/api/auth/favorites'),
      headers: {'Authorization': 'Bearer $token'},
    ));
    final result = _parseResponse(response);
    final value = result['favorites'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> saveFavorite({
    required String token,
    required Map<String, dynamic> favorite,
  }) async {
    await _authorizedPost('/api/auth/favorites', token, favorite);
  }

  Future<void> deleteFavorite({
    required String token,
    required String kind,
    required String id,
  }) async {
    final response = await _request(_client.delete(
      _uri('/api/auth/favorites'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({'kind': kind, 'id': id}),
    ));
    _parseResponse(response);
  }

  Future<List<Map<String, dynamic>>> getCheckins({
    required String token,
  }) async {
    final response = await _request(_client.get(
      _uri('/api/auth/checkins'),
      headers: {'Authorization': 'Bearer $token'},
    ));
    return _readList(_parseResponse(response), 'checkins');
  }

  Future<Map<String, dynamic>> createCheckin({
    required String token,
    required String placeId,
    required String placeName,
    required DateTime visitedAt,
    required String imageUrl,
    required String feeling,
  }) {
    return _authorizedPost('/api/auth/checkins', token, {
      'placeId': placeId,
      'placeName': placeName,
      'visitedAt': visitedAt.toIso8601String(),
      'imageUrl': imageUrl,
      'feeling': feeling,
    });
  }

  Future<List<Map<String, dynamic>>> getReviews({
    required String token,
    String? placeId,
  }) async {
    final uri = _uri('/api/auth/reviews').replace(
      queryParameters: {
        if (placeId != null && placeId.isNotEmpty) 'placeId': placeId,
      },
    );
    final response = await _request(_client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    ));
    return _readList(_parseResponse(response), 'reviews');
  }

  Future<Map<String, dynamic>> saveReview({
    required String token,
    required String placeId,
    required String placeName,
    required int rating,
    required String comment,
  }) {
    return _authorizedPost('/api/auth/reviews', token, {
      'placeId': placeId,
      'placeName': placeName,
      'rating': rating,
      'comment': comment,
    });
  }

  Future<List<Map<String, dynamic>>> getCommunityPosts({
    required bool popular,
    String? token,
  }) async {
    final uri = _uri('/api/community/posts').replace(
      queryParameters: {'sort': popular ? 'popular' : 'latest'},
    );
    final response = await _request(_client.get(
      uri,
      headers: token == null || token.isEmpty
          ? const {}
          : {'Authorization': 'Bearer $token'},
    ));
    return _readList(_parseResponse(response), 'posts');
  }

  Future<Map<String, dynamic>> getCommunityPost({
    required String postId,
    String? token,
  }) async {
    final response = await _request(_client.get(
      _uri('/api/community/posts/$postId'),
      headers: token == null || token.isEmpty
          ? const {}
          : {'Authorization': 'Bearer $token'},
    ));
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> createCommunityPost({
    required String token,
    required String placeId,
    required String placeName,
    required int rating,
    required String content,
    String imageUrl = '',
  }) {
    return _authorizedPost('/api/community/posts', token, {
      'placeId': placeId,
      'placeName': placeName,
      'rating': rating,
      'content': content.trim(),
      'imageUrl': imageUrl,
    });
  }

  Future<Map<String, dynamic>> addCommunityComment({
    required String token,
    required String postId,
    required String content,
    String? parentCommentId,
  }) {
    return _authorizedPost('/api/community/posts/$postId/comments', token, {
      'content': content.trim(),
      if (parentCommentId != null) 'parentCommentId': parentCommentId,
    });
  }

  List<Map<String, dynamic>> _readList(
    Map<String, dynamic> response,
    String key,
  ) {
    final value = response[key];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> _authorizedPost(
    String path,
    String token,
    Map<String, dynamic> body,
  ) async {
    final response = await _request(_client.post(
      _uri(path),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(body),
    ));
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final response = await _request(_client.post(
      _uri(path),
      headers: const {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(body),
    ));
    return _parseResponse(response);
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    if (response.statusCode == 404) {
      throw const AuthApiException(
        'Backend chưa có API này. Hãy dừng server cũ rồi khởi động lại backend.',
        statusCode: 404,
      );
    }

    Map<String, dynamic> decoded;
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      decoded = value is Map<String, dynamic>
          ? value
          : <String, dynamic>{'message': 'Phản hồi API không đúng định dạng.'};
    } catch (_) {
      decoded = <String, dynamic>{
        'message': 'Không đọc được phản hồi từ máy chủ.'
      };
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] == false) {
      throw AuthApiException(
        (decoded['message'] ?? 'Yêu cầu không thành công.').toString(),
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  void close() => _client.close();
}
