import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _preferenceKey = 'theme_mode';

  final SharedPreferencesAsync _preferences;
  AppThemeMode _mode = AppThemeMode.system;
  bool _isDisposed = false;

  ThemeProvider({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync() {
    unawaited(_restoreMode());
  }

  AppThemeMode get mode => _mode;

  ThemeMode get themeMode => _mode.themeMode;

  void setMode(AppThemeMode mode) {
    if (_mode == mode) {
      return;
    }

    _mode = mode;
    notifyListeners();
    unawaited(_preferences.setString(_preferenceKey, mode.name));
  }

  Future<void> _restoreMode() async {
    final storedMode = await _preferences.getString(_preferenceKey);
    if (storedMode == null || _isDisposed) {
      return;
    }

    final restoredMode = AppThemeMode.values.where(
      (mode) => mode.name == storedMode,
    );
    if (restoredMode.isEmpty || _mode == restoredMode.first) {
      return;
    }

    _mode = restoredMode.first;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
