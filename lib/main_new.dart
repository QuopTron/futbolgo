import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:futbolgo/screens/splash_screen.dart';
import 'package:futbolgo/theme/glass_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const FutbolGOApp());
}

class FutbolGOApp extends StatelessWidget {
  const FutbolGOApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FutbolGO',
      debugShowCheckedModeBanner: false,
      theme: GlassTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
