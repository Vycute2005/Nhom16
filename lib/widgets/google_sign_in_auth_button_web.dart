import 'dart:async';

import 'package:hcm_explorer/widgets/app_ui.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart';

import '../services/google_sign_in_service.dart';

class GoogleSignInAuthButton extends StatefulWidget {
  const GoogleSignInAuthButton({
    super.key,
    required this.isRegistering,
    required this.enabled,
    required this.onPressed,
    required this.onIdToken,
    required this.onError,
  });

  final bool isRegistering;
  final bool enabled;
  final VoidCallback onPressed;
  final ValueChanged<String> onIdToken;
  final ValueChanged<String> onError;

  @override
  State<GoogleSignInAuthButton> createState() => _GoogleSignInAuthButtonState();
}

class _GoogleSignInAuthButtonState extends State<GoogleSignInAuthButton> {
  late final Future<void> _initialization;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = GoogleSignInService.instance.authenticationEvents.listen(
      (event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          final idToken = event.user.authentication.idToken;
          if (idToken == null || idToken.isEmpty) {
            widget.onError(
              'Google kh\u{00f4}ng tr\u{1ea3} v\u{1ec1} ID token. H\u{00e3}y ki\u{1ec3}m tra OAuth client.',
            );
          } else {
            widget.onIdToken(idToken);
          }
        }
      },
      onError: (Object error) => widget.onError(error.toString()),
    );
    _initialization = Future<void>.sync(
      GoogleSignInService.initialize,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _fallbackButton(
            onPressed: () => widget.onError(snapshot.error.toString()),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 50,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final config = GSIButtonConfiguration(
          type: GSIButtonType.standard,
          theme: GSIButtonTheme.outline,
          size: GSIButtonSize.large,
          text: widget.isRegistering
              ? GSIButtonText.signupWith
              : GSIButtonText.continueWith,
          shape: GSIButtonShape.rectangular,
          minimumWidth: 300,
          locale: 'vi',
        );
        return SizedBox(
          height: 50,
          child: Center(
            child: AbsorbPointer(
              absorbing: !widget.enabled,
              child: renderButton(configuration: config),
            ),
          ),
        );
      },
    );
  }

  Widget _fallbackButton({required VoidCallback onPressed}) {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: widget.enabled ? onPressed : null,
        icon: const Text(
          'G',
          style: TextStyle(
            color: Color(0xFF4285F4),
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        label: Text(
          widget.isRegistering
              ? '\u{0110}\u{0103}ng k\u{00fd} v\u{1edb}i Google'
              : 'Ti\u{1ebf}p t\u{1ee5}c v\u{1edb}i Google',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF202124),
          side: const BorderSide(color: Color(0xFFB8B8B8)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
