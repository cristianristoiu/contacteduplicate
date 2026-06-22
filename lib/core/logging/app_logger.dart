enum AppLogLevel {
  debug,
  info,
  warning,
  error,
}

class AppLogger {
  const AppLogger._();

  static void log(
    AppLogLevel level,
    String message, {
    Object? error,
  }) {
    assert(
      !_looksLikePersonalData(message),
      'Log message appears to contain PII. Remove contact data before logging.',
    );

    // Intentionat gol in MVP brut: se evita print/log cu date personale.
    // Se poate conecta ulterior la un logger safe, fara nume, telefoane sau emailuri.
  }

  static bool _looksLikePersonalData(String message) {
    final emailPattern = RegExp(r'\S+@\S+\.\S+');
    final phonePattern = RegExp(r'(\+?\d[\d\s().-]{6,}\d)');
    return emailPattern.hasMatch(message) || phonePattern.hasMatch(message);
  }
}
