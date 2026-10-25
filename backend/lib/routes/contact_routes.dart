import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class ContactRoutes {
  ContactRoutes() : _dotenv = _loadDotEnv();

  static const _defaultInbox = 'letuongvy03082005@gmail.com';
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final DotEnv? _dotenv;

  static DotEnv? _loadDotEnv() {
    final candidates = [File('backend/.env'), File('.env')];
    for (final file in candidates) {
      if (file.existsSync()) return DotEnv()..load([file.path]);
    }
    return null;
  }

  String _setting(String key, [String fallback = '']) =>
      Platform.environment[key] ?? _dotenv?[key] ?? fallback;

  Router get router {
    final router = Router();
    router.post('/api/contact', _submitFeedback);
    return router;
  }

  Future<Response> _submitFeedback(Request request) async {
    final rawBody = await request.readAsString();
    if (rawBody.length > 16000) {
      return _json(413, {'success': false, 'message': 'Nội dung phản hồi quá dài.'});
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(rawBody);
    } on FormatException {
      return _json(400, {'success': false, 'message': 'Dữ liệu gửi lên không hợp lệ.'});
    }
    if (decoded is! Map) {
      return _json(400, {'success': false, 'message': 'Dữ liệu gửi lên không hợp lệ.'});
    }

    final data = Map<String, dynamic>.from(decoded);
    final name = (data['name'] ?? '').toString().replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    final email = (data['email'] ?? '').toString().trim();
    final subject = (data['subject'] ?? '').toString().trim();
    final feedback = (data['message'] ?? '').toString().trim();

    if (name.isEmpty || name.length > 120 ||
        email.length > 254 || !_emailPattern.hasMatch(email) ||
        subject.isEmpty || subject.length > 160 || subject.contains('\r') || subject.contains('\n') ||
        feedback.isEmpty || feedback.length > 10000) {
      return _json(400, {
        'success': false,
        'message': 'Vui lòng kiểm tra họ tên, email, chủ đề và nội dung phản hồi.',
      });
    }

    final smtpUsername = _setting('SMTP_GMAIL_ADDRESS').trim();
    final smtpPassword = _setting('SMTP_GMAIL_APP_PASSWORD').replaceAll(RegExp(r'\s+'), '');
    if (smtpUsername.isEmpty || smtpPassword.isEmpty) {
      return _json(503, {
        'success': false,
        'message': 'Email gửi phản hồi chưa được cấu hình trên máy chủ.',
      });
    }

    final configuredInbox = _setting('CONTACT_INBOX_EMAIL').trim();
    final inbox = configuredInbox.isEmpty ? _defaultInbox : configuredInbox;
    final message = Message()
      ..from = Address(smtpUsername, 'VN Guide')
      ..recipients.add(inbox)
      ..subject = '[VN Guide] $subject'
      ..headers['Reply-To'] = Address(email, name)
      ..text = 'Họ và tên: $name\n'
          'Email liên hệ: $email\n'
          'Chủ đề: $subject\n\n'
          '$feedback';

    try {
      await send(message, gmail(smtpUsername, smtpPassword))
          .timeout(const Duration(seconds: 20));
      return _json(200, {
        'success': true,
        'message': 'Đã gửi phản hồi thành công.',
      });
    } catch (error, stackTrace) {
      print('Contact email delivery failed: $error\n$stackTrace');
      final errorText = error.toString().toLowerCase();
      final failureMessage = error is TimeoutException
          ? 'Kết nối SMTP hết thời gian chờ. Kiểm tra kết nối mạng của backend.'
          : RegExp(r'535|auth|credential|password').hasMatch(errorText)
              ? 'Gmail từ chối xác thực SMTP. Kiểm tra SMTP_GMAIL_ADDRESS và app password trong backend/.env.'
              : 'Không gửi được qua SMTP. Xem log backend để biết nguyên nhân.';
      return _json(502, {
        'success': false,
        'message': failureMessage,
      });
    }
  }

  Response _json(int status, Map<String, dynamic> body) => Response(
        status,
        body: jsonEncode(body),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}