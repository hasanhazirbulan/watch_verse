import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's light/dark/system theme preference and persists it
/// across launches via [SharedPreferences].
class ThemeController extends ValueNotifier<ThemeMode> {
  static const _prefsKey = 'theme_mode';

  ThemeController() : super(ThemeMode.dark);

  static final ThemeController instance = ThemeController();

  /// Loads the stored preference, if any. Call once before [runApp].
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_prefsKey)) {
      case 'light':
        value = ThemeMode.light;
      case 'system':
        value = ThemeMode.system;
      case 'dark':
      default:
        value = ThemeMode.dark;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}
