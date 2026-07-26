import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPreferences {
  static const String _completedKey = 'onboarding_completed';

  final SharedPreferencesAsync _preferences;

  OnboardingPreferences({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  Future<bool> isCompleted() async {
    return await _preferences.getBool(_completedKey) ?? false;
  }

  Future<void> markCompleted() async {
    await _preferences.setBool(_completedKey, true);
  }
}
