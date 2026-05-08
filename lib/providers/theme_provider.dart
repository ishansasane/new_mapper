import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  
  // Default to indigo
  FlexScheme _currentScheme = FlexScheme.indigo;
  ThemeMode _themeMode = ThemeMode.system;

  FlexScheme get currentScheme => _currentScheme;
  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Load scheme
    final schemeIndex = _prefs.getInt('theme_scheme') ?? FlexScheme.indigo.index;
    _currentScheme = FlexScheme.values[schemeIndex];

    // Load mode
    final modeIndex = _prefs.getInt('theme_mode') ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[modeIndex];

    notifyListeners();
  }

  Future<void> setScheme(FlexScheme scheme) async {
    _currentScheme = scheme;
    await _prefs.setInt('theme_scheme', scheme.index);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  ThemeData get lightTheme => FlexThemeData.light(scheme: _currentScheme);
  ThemeData get darkTheme => FlexThemeData.dark(scheme: _currentScheme);
}
