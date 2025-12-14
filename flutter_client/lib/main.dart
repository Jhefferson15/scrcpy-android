import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: ScrcpyClientApp(),
    ),
  );
}

class ScrcpyClientApp extends StatelessWidget {
  const ScrcpyClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scrcpy Client',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme, // Ensure AppTheme exists or use default
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}
