import 'package:flutter/services.dart';

class AppHaptics {
  const AppHaptics._();

  static Future<void> importantAction() {
    return HapticFeedback.mediumImpact();
  }

  static Future<void> selection() {
    return HapticFeedback.lightImpact();
  }
}
