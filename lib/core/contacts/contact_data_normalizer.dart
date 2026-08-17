class ContactDataNormalizer {
  static final RegExp _controlCharacters = RegExp(
    r'[\u0000-\u001F\u007F]',
  );
  static final RegExp _zeroWidthCharacters = RegExp(
    r'[\u200B-\u200D\u2060\uFEFF]',
  );
  static final RegExp _phoneSeparators = RegExp(r'[\s().\-\/]');
  static final RegExp _emailWhitespace = RegExp(r'\s');
  static final RegExp _multipleWhitespace = RegExp(r'\s+');

  final String? defaultCountryCallingCode;

  ContactDataNormalizer({String? defaultCountryCallingCode = '40'})
      : defaultCountryCallingCode =
            sanitizeCountryCallingCode(defaultCountryCallingCode);

  static String? sanitizeCountryCallingCode(String? value) {
    if (value == null) {
      return null;
    }

    final trimmed = value.trim();
    if (!RegExp(r'^\+?[1-9][0-9]{0,2}$').hasMatch(trimmed)) {
      return null;
    }
    return trimmed.startsWith('+') ? trimmed.substring(1) : trimmed;
  }

  String normalizePhone(String value) {
    final sanitized = _sanitizeInvisible(value).trim();
    if (sanitized.isEmpty || RegExp(r'[A-Za-z]').hasMatch(sanitized)) {
      return '';
    }

    var compact = sanitized.replaceAll(_phoneSeparators, '');
    if (compact.isEmpty) {
      return '';
    }
    if (compact.startsWith('00')) {
      compact = '+${compact.substring(2)}';
    }
    if (!RegExp(r'^\+?[0-9]+$').hasMatch(compact)) {
      return '';
    }

    final plusCount = '+'.allMatches(compact).length;
    if (plusCount > 1 ||
        (compact.contains('+') && !compact.startsWith('+'))) {
      return '';
    }

    var normalized = compact;
    var digits = normalized.replaceAll('+', '');
    if (digits.length < 7 ||
        digits.length > 15 ||
        RegExp(r'^0+$').hasMatch(digits)) {
      return '';
    }

    final countryCode = defaultCountryCallingCode;
    if (countryCode == '40' &&
        normalized.startsWith('+400') &&
        digits.length == 12) {
      normalized = '+40${normalized.substring(4)}';
      digits = normalized.substring(1);
    }

    if (countryCode == '40' &&
        !normalized.startsWith('+') &&
        normalized.startsWith('0') &&
        digits.length == 10) {
      normalized = '+40${normalized.substring(1)}';
      digits = normalized.substring(1);
    } else if (countryCode == '40' &&
        !normalized.startsWith('+') &&
        normalized.startsWith('40') &&
        digits.length == 11) {
      normalized = '+$normalized';
      digits = normalized.substring(1);
    }

    if (digits.length < 7 || digits.length > 15) {
      return '';
    }
    return normalized;
  }

  String normalizeEmail(String value) {
    final normalized = _sanitizeInvisible(value).trim().toLowerCase();
    if (normalized.isEmpty || _emailWhitespace.hasMatch(normalized)) {
      return '';
    }
    if (normalized.length > 254 || '@'.allMatches(normalized).length != 1) {
      return '';
    }

    final separatorIndex = normalized.indexOf('@');
    final localPart = normalized.substring(0, separatorIndex);
    final domain = normalized.substring(separatorIndex + 1);
    if (localPart.isEmpty || domain.isEmpty || localPart.length > 64) {
      return '';
    }
    if (_hasInvalidDots(localPart) || _hasInvalidDots(domain)) {
      return '';
    }

    final labels = domain.split('.');
    if (labels.any(
      (label) =>
          label.isEmpty || label.startsWith('-') || label.endsWith('-'),
    )) {
      return '';
    }
    return normalized;
  }

  String normalizeDisplayName(String value) {
    return _sanitizeInvisible(value)
        .trim()
        .replaceAll(_multipleWhitespace, ' ');
  }

  String canonicalName(String value) {
    var normalized = normalizeDisplayName(value).toLowerCase();
    const replacements = <String, String>{
      'ă': 'a',
      'â': 'a',
      'î': 'i',
      'ș': 's',
      'ş': 's',
      'ț': 't',
      'ţ': 't',
    };
    for (final entry in replacements.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }
    return normalized;
  }

  static bool _hasInvalidDots(String value) {
    return value.startsWith('.') ||
        value.endsWith('.') ||
        value.contains('..');
  }

  static String _sanitizeInvisible(String value) {
    return value
        .replaceAll(_zeroWidthCharacters, '')
        .replaceAll(_controlCharacters, ' ');
  }
}
