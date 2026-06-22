import 'package:flutter/material.dart';

enum AppThemeMode {
  system,
  light,
  dark;

  ThemeMode get themeMode {
    switch (this) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }
}

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _mode = AppThemeMode.system;

  AppThemeMode get mode => _mode;

  ThemeMode get themeMode => _mode.themeMode;

  void setMode(AppThemeMode mode) {
    if (_mode == mode) {
      return;
    }

    _mode = mode;
    notifyListeners();
  }
}
