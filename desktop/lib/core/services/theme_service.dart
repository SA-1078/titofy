import 'package:flutter/material.dart';
import 'database_service.dart';
import '../theme/colors.dart';

class ThemeService extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  String _accentColorKey = 'coral';
  DatabaseService? _dbService;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  String get accentColorKey => _accentColorKey;
  AccentPreset get accentPreset => AccentPresets.getPreset(_accentColorKey);
  Color get accentColor => accentPreset.primary;

  void attachDatabaseService(DatabaseService db) {
    _dbService = db;
    bool needsNotify = false;

    final saved = _dbService!.getSetting('theme_mode');
    if (saved != null) {
      final mode = saved == 'light' ? ThemeMode.light : ThemeMode.dark;
      if (_themeMode != mode) {
        _themeMode = mode;
        needsNotify = true;
      }
    }

    final savedAccent = _dbService!.getSetting('accent_color');
    if (savedAccent != null && AccentPresets.has(savedAccent)) {
      if (_accentColorKey != savedAccent) {
        _accentColorKey = savedAccent;
        AppColors.applyAccent(accentPreset);
        needsNotify = true;
      }
    } else {
      AppColors.applyAccent(accentPreset);
    }

    if (needsNotify) {
      notifyListeners();
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      _dbService?.setSetting('theme_mode', mode == ThemeMode.light ? 'light' : 'dark');
      notifyListeners();
    }
  }

  void setAccentColor(String key) {
    if (_accentColorKey != key && AccentPresets.has(key)) {
      _accentColorKey = key;
      AppColors.applyAccent(accentPreset);
      _dbService?.setSetting('accent_color', key);
      notifyListeners();
    }
  }

  void toggleTheme() {
    setThemeMode(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
