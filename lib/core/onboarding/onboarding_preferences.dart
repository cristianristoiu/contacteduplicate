import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class OnboardingReadResult {
  final bool completed;
  final String? errorCode;

  const OnboardingReadResult({required this.completed, this.errorCode});
  bool get isReliable => errorCode == null;
}

class OnboardingPreferences {
  static const String _completedKey = 'onboarding_completed';
  final SharedPreferencesAsync _preferences;
  final Duration timeout;
  Future<void> _writeQueue = Future<void>.value();

  OnboardingPreferences({
    SharedPreferencesAsync? preferences,
    this.timeout = const Duration(seconds: 3),
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  Future<bool> isCompleted() async => (await read()).completed;

  Future<OnboardingReadResult> read() async {
    try {
      final value = await _preferences.getBool(_completedKey).timeout(timeout);
      return OnboardingReadResult(completed: value ?? false);
    } on TimeoutException {
      return const OnboardingReadResult(completed: false, errorCode: 'onboarding_read_timeout');
    } on Object {
      return const OnboardingReadResult(completed: false, errorCode: 'onboarding_read_failed');
    }
  }

  Future<void> markCompleted() {
    return _enqueue(() async {
      await _preferences.setBool(_completedKey, true).timeout(timeout);
      final verified = await _preferences.getBool(_completedKey).timeout(timeout);
      if (verified != true) throw StateError('onboarding_persistence_verification_failed');
    });
  }

  Future<void> reset() {
    return _enqueue(() async {
      await _preferences.remove(_completedKey).timeout(timeout);
      final verified = await _preferences.getBool(_completedKey).timeout(timeout);
      if (verified != null) throw StateError('onboarding_reset_verification_failed');
    });
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final completer = Completer<void>();
    _writeQueue = _writeQueue.catchError((Object _) {}).then((_) async {
      try {
        await action();
        completer.complete();
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
