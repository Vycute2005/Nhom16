import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/onboarding_screen.dart';
import 'services/app_theme.dart';
import 'services/app_locale.dart';

void main() {
  runApp(const VNGuideApp());
}

class VNGuideApp extends StatelessWidget {
  const VNGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocaleController.languageCode,
      builder: (context, languageCode, _) => ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.mode,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'VN Guide',
        locale: Locale(languageCode),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('vi'), Locale('en')],
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: ThemeData(
          scaffoldBackgroundColor: const Color(0xFFFAF7F0),
          primaryColor: const Color(0xFF0F5B49),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0F5B49),
            primary: const Color(0xFF0F5B49),
            secondary: const Color(0xFFB83B26),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFAF7F0),
            foregroundColor: Color(0xFF202522),
          ),
          fontFamily: 'Roboto',
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF111A17),
          primaryColor: const Color(0xFF76C8AE),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0F5B49),
            brightness: Brightness.dark,
          ).copyWith(
            primary: const Color(0xFF76C8AE),
            surface: const Color(0xFF1C2823),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF111A17),
            foregroundColor: Color(0xFFF2F5F3),
          ),
          fontFamily: 'Roboto',
          useMaterial3: true,
        ),
        home: const OnboardingScreen(),
      ),
      ),
    );
  }
}