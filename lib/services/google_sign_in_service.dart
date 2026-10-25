import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  GoogleSignInService._();

  static final GoogleSignIn _google = GoogleSignIn.instance;
  static Future<void>? _initialization;

  static GoogleSignIn get instance => _google;

  static Future<void> initialize() => _initialize();

  static Future<void> _initialize() {
    const webClientId = String.fromEnvironment(
      'GOOGLE_CLIENT_ID',
      defaultValue:
          '409118219902-lf23rdn9l3sheeekl9cjod3e2kin6lh5.apps.googleusercontent.com',
    );
    const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
    const macosClientId = String.fromEnvironment('GOOGLE_MACOS_CLIENT_ID');

    if (webClientId.isEmpty) {
      throw StateError(
        'Ch\u{01b0}a c\u{1ea5}u h\u{00ec}nh GOOGLE_CLIENT_ID khi ch\u{1ea1}y \u{1ee9}ng d\u{1ee5}ng Flutter.',
      );
    }

    if (kIsWeb) {
      _initialization ??= _google.initialize(clientId: webClientId);
      return _initialization!;
    }

    final nativeClientId = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => iosClientId,
      TargetPlatform.macOS => macosClientId,
      _ => '',
    };

    _initialization ??= _google.initialize(
      clientId: nativeClientId.isEmpty ? null : nativeClientId,
      serverClientId: webClientId,
    );
    return _initialization!;
  }

  static Future<String?> authenticate() async {
    await _initialize();
    try {
      final account = await _google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError(
          'Google kh\u{00f4}ng tr\u{1ea3} v\u{1ec1} ID token. H\u{00e3}y ki\u{1ec3}m tra OAuth client.',
        );
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw StateError(error.description ?? error.toString());
    }
  }
}
