import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const SaigonExplorerApp());
}

class SaigonExplorerApp extends StatelessWidget {
  const SaigonExplorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Saigon Explorer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}