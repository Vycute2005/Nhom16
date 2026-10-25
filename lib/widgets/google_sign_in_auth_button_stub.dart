import 'package:hcm_explorer/widgets/app_ui.dart';

class GoogleSignInAuthButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: const Text(
          'G',
          style: TextStyle(
            color: Color(0xFF4285F4),
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        label: Text(
          isRegistering
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
