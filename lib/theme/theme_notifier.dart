import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global notifier for toggling between glass (true) and solid (false) themes.
/// Used by GlassContainer/GlassAppBar/GlassFAB to conditionally skip BackdropFilter.
class ThemeNotifier {
  static final ValueNotifier<bool> isGlass = ValueNotifier<bool>(true);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isGlass.value = prefs.getBool('isGlassTheme') ?? true;
  }

  static Future<void> toggle() async {
    isGlass.value = !isGlass.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isGlassTheme', isGlass.value);
  }
}
