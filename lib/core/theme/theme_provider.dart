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

enum ThemePersistenceStatus {
  restoring,
  ready,
  saving,
  error,
}

class ThemeProvider extends ChangeNotifier {
  static const String _preferenceKey = 'theme_mode';

  final SharedPreferencesAsync _preferences;
  AppThemeMode _mode = AppThemeMode.system;
  ThemePersistenceStatus _persistenceStatus =
      ThemePersistenceStatus.restoring;
  String? _persistenceErrorCode;
  Future<void> _writeQueue = Future<void>.value();
  int _selectionRevision = 0;
  bool _isDisposed = false;

  ThemeProvider({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync() {
    unawaited(_restoreMode());
  }

  AppThemeMode get mode => _mode;

  ThemeMode get themeMode => _mode.themeMode;

  ThemePersistenceStatus get persistenceStatus => _persistenceStatus;

  String? get persistenceErrorCode => _persistenceErrorCode;

  bool get hasPersistenceError =>
      _persistenceStatus == ThemePersistenceStatus.error;

  void setMode(AppThemeMode mode) {
    if (_isDisposed) {
      return;
    }

    if (_mode == mode) {
      if (_persistenceStatus == ThemePersistenceStatus.error) {
        _enqueuePersist(mode, _selectionRevision);
      }
      return;
    }

    _selectionRevision++;
    _mode = mode;
    _enqueuePersist(mode, _selectionRevision);
  }

  void _enqueuePersist(AppThemeMode mode, int revision) {
    _persistenceStatus = ThemePersistenceStatus.saving;
    _persistenceErrorCode = null;
    _notifySafely();

    _writeQueue = _writeQueue.then((_) async {
      try {
        await _preferences.setString(_preferenceKey, mode.name);
      } on Object {
        if (!_isDisposed && revision == _selectionRevision) {
          _persistenceStatus = ThemePersistenceStatus.error;
          _persistenceErrorCode = 'theme_persistence_write_failed';
          _notifySafely();
        }
        return;
      }

      if (_isDisposed || revision != _selectionRevision) {
        return;
      }
      _persistenceStatus = ThemePersistenceStatus.ready;
      _persistenceErrorCode = null;
      _notifySafely();
    });
  }

  Future<void> _restoreMode() async {
    final restoreRevision = _selectionRevision;
    final String? storedMode;
    try {
      storedMode = await _preferences.getString(_preferenceKey);
    } on Object {
      if (!_isDisposed && restoreRevision == _selectionRevision) {
        _persistenceStatus = ThemePersistenceStatus.error;
        _persistenceErrorCode = 'theme_persistence_read_failed';
        _notifySafely();
      }
      return;
    }

    if (_isDisposed || restoreRevision != _selectionRevision) {
      return;
    }

    if (storedMode == null) {
      _persistenceStatus = ThemePersistenceStatus.ready;
      _persistenceErrorCode = null;
      _notifySafely();
      return;
    }

    AppThemeMode? restoredMode;
    for (final candidate in AppThemeMode.values) {
      if (candidate.name == storedMode) {
        restoredMode = candidate;
        break;
      }
    }

    if (restoredMode == null) {
      _enqueueInvalidValueCleanup(restoreRevision);
      return;
    }

    if (restoreRevision != _selectionRevision || _isDisposed) {
      return;
    }
    _mode = restoredMode;
    _persistenceStatus = ThemePersistenceStatus.ready;
    _persistenceErrorCode = null;
    _notifySafely();
  }

  void _enqueueInvalidValueCleanup(int restoreRevision) {
    _writeQueue = _writeQueue.then((_) async {
      if (_isDisposed || restoreRevision != _selectionRevision) {
        return;
      }

      try {
        await _preferences.remove(_preferenceKey);
      } on Object {
        if (!_isDisposed && restoreRevision == _selectionRevision) {
          _persistenceStatus = ThemePersistenceStatus.error;
          _persistenceErrorCode = 'theme_persistence_cleanup_failed';
          _notifySafely();
        }
        return;
      }

      if (_isDisposed || restoreRevision != _selectionRevision) {
        return;
      }
      _persistenceStatus = ThemePersistenceStatus.ready;
      _persistenceErrorCode = null;
      _notifySafely();
    });
  }

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
