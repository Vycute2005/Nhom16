import 'package:flutter/widgets.dart';

class AppLocaleController {
  static final ValueNotifier<String> languageCode = ValueNotifier<String>('vi');
  static bool get isEnglish => languageCode.value == 'en';

  static void setLanguage(String code) {
    final next = code.toLowerCase() == 'en' ? 'en' : 'vi';
    if (languageCode.value != next) languageCode.value = next;
  }
}

mixin AppLocaleAwareState<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    AppLocaleController.languageCode.addListener(_handleLanguageChange);
  }

  @override
  void dispose() {
    AppLocaleController.languageCode.removeListener(_handleLanguageChange);
    super.dispose();
  }

  void _handleLanguageChange() {
    if (mounted) setState(() {});
  }
}
