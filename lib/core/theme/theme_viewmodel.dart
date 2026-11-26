import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages application-wide ThemeMode (OLED Dark vs Clean Light).
/// Adheres strictly to AGENTS.md Invariant 1 (Provider injected, zero singletons)
/// and Invariant 4 (Pure Monochrome Dark & Light palette).
class ThemeViewModel extends ChangeNotifier {
  static const String _themePrefKey = 'dilse_theme_mode_v1';

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeViewModel({ThemeMode initialMode = ThemeMode.dark}) : _themeMode = initialMode;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Toggles between Dark (OLED Black) and Light (Clean White) modes.
  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    _saveThemePreference();
  }

  /// Sets an explicit theme mode.
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    _saveThemePreference();
  }

  /// Loads saved theme preference from local storage.
  Future<void> loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_themePrefKey);
      if (saved == 'light') {
        _themeMode = ThemeMode.light;
        notifyListeners();
      } else if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _themePrefKey,
        _themeMode == ThemeMode.light ? 'light' : 'dark',
      );
    } catch (_) {}
  }
}

