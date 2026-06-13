import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primary = Color(0xFF6C63FF);
  static const Color secondary = Color(0xFF00D9FF);
  static const Color accent = Color(0xFFFF6B9D);
  static const Color bgDark = Color(0xFF0A0E1A);
  static const Color bgCard = Color(0xFF1A1E2E);
  static const Color surfaceGlass = Color(0x1AFFFFFF);
  static const Color borderGlass = Color(0x33FFFFFF);
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFFA0A5B5);
  static const Color online = Color(0xFF00E676);
  static const Color offline = Color(0xFFFF5252);
  static const Color gold = Color(0xFFFFD700);

  static const _gradientStart = Alignment(-0.2, -0.2);
  static const _gradientEnd = Alignment(0.8, 0.8);

  static const Gradient backgroundGradient = LinearGradient(
    begin: _gradientStart,
    end: _gradientEnd,
    colors: [Color(0xFF0F1428), Color(0xFF1A1040), Color(0xFF0A0E1A)],
  );

  static const Gradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF8B7FFF)],
  );

  static const Gradient accentGradient = LinearGradient(
    colors: [secondary, accent],
  );

  /// Glass decoration for cards and containers
  static BoxDecoration glass({
    double blur = 20,
    double opacity = 0.08,
    double borderOpacity = 0.12,
    Color? borderColor,
    double radius = 16,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: (borderColor ?? Colors.white).withValues(alpha: borderOpacity),
        width: 0.5,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: opacity + 0.03),
          Colors.white.withValues(alpha: opacity * 0.5),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: blur,
          spreadRadius: -2,
        ),
      ],
    );
  }

  /// Bottom sheet with glass effect
  static BoxDecoration glassBottomSheet({
    double radius = 20,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF1A1E2E).withValues(alpha: 0.95),
          const Color(0xFF0F1428).withValues(alpha: 0.98),
        ],
      ),
      border: Border(
        top: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
    );
  }

  /// Theme data
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: bgCard,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
        labelLarge: TextStyle(
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Language display helpers
class LanguageHelper {
  static const _flags = {
    'ES': '🇪🇸',
    'ES-MX': '🇲🇽',
    'ES-AR': '🇦🇷',
    'PT': '🇧🇷',
    'PT-BR': '🇧🇷',
    'EN': '🇺🇸',
    'ES-PE': '🇵🇪',
    'ES-CO': '🇨🇴',
  };

  static const _names = {
    'ES': 'Español',
    'ES-MX': 'Español MX',
    'ES-AR': 'Español AR',
    'ES-PE': 'Español PE',
    'ES-CO': 'Español CO',
    'PT': 'Português',
    'PT-BR': 'Português BR',
    'EN': 'English',
  };

  static String flag(String lang) => _flags[lang] ?? '🌐';
  static String name(String lang) => _names[lang] ?? lang;
}
