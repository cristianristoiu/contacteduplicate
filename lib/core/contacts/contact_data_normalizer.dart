class NormalizedPhoneValue {
  final String displayValue;
  final String canonicalKey;
  final String? extension;
  final bool isMatchable;

  const NormalizedPhoneValue({
    required this.displayValue,
    required this.canonicalKey,
    required this.extension,
    required this.isMatchable,
  });

  static const NormalizedPhoneValue empty = NormalizedPhoneValue(
    displayValue: '',
    canonicalKey: '',
    extension: null,
    isMatchable: false,
  );
}

class NormalizedEmailValue {
  final String displayValue;
  final String canonicalKey;
  final bool isMatchable;

  const NormalizedEmailValue({
    required this.displayValue,
    required this.canonicalKey,
    required this.isMatchable,
  });

  static const NormalizedEmailValue empty = NormalizedEmailValue(
    displayValue: '',
    canonicalKey: '',
    isMatchable: false,
  );
}

class ContactDataNormalizer {
  static final RegExp _controlCharacters = RegExp(r'[\u0000-\u001F\u007F-\u009F]');
  static final RegExp _zeroWidthCharacters = RegExp(r'[\u200B-\u200D\u2060\uFEFF]');
  static final RegExp _multipleWhitespace = RegExp(r'\s+');
  static final RegExp _phoneVisualSeparators = RegExp(
    r'[\s().\-\/\u00A0\u2007\u202F\u2010-\u2015\u2212]',
  );
  static final RegExp _emailWhitespace = RegExp(r'\s');
  static final RegExp _emailLocalPart = RegExp(
    r"^[a-z0-9!#$%&'*+/=?^_`{|}~.-]+$",
  );
  static final RegExp _domainLabel = RegExp(r'^[a-z0-9-]+$');
  static final RegExp _namePunctuation = RegExp(r'''[.,;:!?"'`()\[\]{}<>_\/\\|+\-]+''');
  static final RegExp _companyPunctuation = RegExp(r'''[.,;:!?"'`()\[\]{}<>_\/\\|+\-]+''');
  static final RegExp _extensionSuffix = RegExp(
    r'(?:\s*(?:ext\.?|extension|x|#)\s*)([0-9０-９]{1,8})\s*$',
    caseSensitive: false,
  );

  static const Map<String, String> _romanianDiacritics = <String, String>{
    'ă': 'a', 'â': 'a', 'î': 'i', 'ș': 's', 'ş': 's', 'ț': 't', 'ţ': 't',
  };

  static const Map<String, String> _commonLatinDiacritics = <String, String>{
    'á': 'a', 'à': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'æ': 'ae',
    'ç': 'c', 'č': 'c', 'ć': 'c', 'ď': 'd', 'đ': 'd',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ě': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'ľ': 'l', 'ł': 'l',
    'ñ': 'n', 'ň': 'n', 'ó': 'o', 'ò': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o',
    'ř': 'r', 'ŕ': 'r', 'š': 's', 'ś': 's', 'ť': 't',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'ů': 'u', 'ý': 'y', 'ÿ': 'y',
    'ž': 'z', 'ź': 'z', 'ż': 'z',
  };

  final String? defaultCountryCallingCode;
  final int minimumMatchablePhoneDigits;
  final int maximumPhoneDigits;

  ContactDataNormalizer({
    String? defaultCountryCallingCode = '40',
    this.minimumMatchablePhoneDigits = 7,
    this.maximumPhoneDigits = 15,
  })  : assert(minimumMatchablePhoneDigits > 0),
        assert(maximumPhoneDigits >= minimumMatchablePhoneDigits),
        defaultCountryCallingCode = sanitizeCountryCallingCode(defaultCountryCallingCode);

  static String? sanitizeCountryCallingCode(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (!RegExp(r'^\+?[1-9][0-9]{0,2}$').hasMatch(trimmed)) return null;
    return trimmed.startsWith('+') ? trimmed.substring(1) : trimmed;
  }

  String sanitizeText(String value) => _sanitizeInvisible(value).trim().replaceAll(_multipleWhitespace, ' ');

  String normalizePhone(String value) => normalizePhoneValue(value).canonicalKey;

  NormalizedPhoneValue normalizePhoneValue(String value) {
    final displayValue = sanitizeText(value);
    if (displayValue.isEmpty) return NormalizedPhoneValue.empty;

    final extensionMatch = _extensionSuffix.firstMatch(displayValue);
    var mainValue = displayValue;
    String? extension;
    if (extensionMatch != null) {
      extension = _asciiDigits(extensionMatch.group(1) ?? '');
      mainValue = displayValue.substring(0, extensionMatch.start).trim();
      if (extension.isEmpty) extension = null;
    }

    var compact = _asciiDigitsPreservingPlus(mainValue).replaceAll(_phoneVisualSeparators, '');
    if (compact.isEmpty) {
      return NormalizedPhoneValue(displayValue: displayValue, canonicalKey: '', extension: extension, isMatchable: false);
    }
    if (compact.startsWith('00')) compact = '+${compact.substring(2)}';
    if (!RegExp(r'^\+?[0-9]+$').hasMatch(compact) ||
        '+'.allMatches(compact).length > 1 ||
        (compact.contains('+') && !compact.startsWith('+'))) {
      return NormalizedPhoneValue(displayValue: displayValue, canonicalKey: '', extension: extension, isMatchable: false);
    }

    var normalized = compact;
    var digits = normalized.replaceAll('+', '');
    if (digits.isEmpty || digits.length > maximumPhoneDigits || RegExp(r'^0+$').hasMatch(digits)) {
      return NormalizedPhoneValue(displayValue: displayValue, canonicalKey: '', extension: extension, isMatchable: false);
    }

    final countryCode = defaultCountryCallingCode;
    if (countryCode != null) {
      final internationalPrefix = '+$countryCode';
      if (normalized.startsWith('${internationalPrefix}0')) {
        final withoutTrunk = '$internationalPrefix${normalized.substring(internationalPrefix.length + 1)}';
        final withoutTrunkDigits = withoutTrunk.substring(1);
        if (withoutTrunkDigits.length >= minimumMatchablePhoneDigits && withoutTrunkDigits.length <= maximumPhoneDigits) {
          normalized = withoutTrunk;
          digits = withoutTrunkDigits;
        }
      }
      if (!normalized.startsWith('+') && normalized.startsWith('0') && digits.length >= minimumMatchablePhoneDigits) {
        final candidate = '+$countryCode${normalized.substring(1)}';
        if (candidate.length - 1 <= maximumPhoneDigits) {
          normalized = candidate;
          digits = normalized.substring(1);
        }
      } else if (!normalized.startsWith('+') && normalized.startsWith(countryCode) && digits.length >= countryCode.length + 6) {
        normalized = '+$normalized';
        digits = normalized.substring(1);
      }
    }

    final matchable = digits.length >= minimumMatchablePhoneDigits && digits.length <= maximumPhoneDigits;
    return NormalizedPhoneValue(
      displayValue: displayValue,
      canonicalKey: matchable ? normalized : '',
      extension: extension,
      isMatchable: matchable,
    );
  }

  String normalizeEmail(String value) => normalizeEmailValue(value).canonicalKey;

  NormalizedEmailValue normalizeEmailValue(String value) {
    final displayValue = sanitizeText(value);
    final normalized = displayValue.toLowerCase();
    if (normalized.isEmpty || _emailWhitespace.hasMatch(normalized) || normalized.length > 254 || '@'.allMatches(normalized).length != 1) {
      return NormalizedEmailValue(displayValue: displayValue, canonicalKey: '', isMatchable: false);
    }
    final separatorIndex = normalized.indexOf('@');
    final localPart = normalized.substring(0, separatorIndex);
    final domain = normalized.substring(separatorIndex + 1);
    if (localPart.isEmpty || localPart.length > 64 || domain.isEmpty || _hasInvalidDots(localPart) || _hasInvalidDots(domain) || localPart.startsWith('"') || localPart.endsWith('"') || !_emailLocalPart.hasMatch(localPart)) {
      return NormalizedEmailValue(displayValue: displayValue, canonicalKey: '', isMatchable: false);
    }
    final labels = domain.split('.');
    if (labels.any((label) => label.isEmpty || label.length > 63 || label.startsWith('-') || label.endsWith('-') || !_domainLabel.hasMatch(label))) {
      return NormalizedEmailValue(displayValue: displayValue, canonicalKey: '', isMatchable: false);
    }
    return NormalizedEmailValue(displayValue: displayValue, canonicalKey: normalized, isMatchable: true);
  }

  String normalizeDisplayName(String value) => sanitizeText(value);
  String canonicalName(String value) => exactNameKey(value);

  String exactNameKey(String value) => _stripCommonDiacritics(normalizeDisplayName(value).toLowerCase());

  String fuzzyNameKey(String value) => exactNameKey(value)
      .replaceAll(_namePunctuation, ' ')
      .replaceAll(_multipleWhitespace, ' ')
      .trim();

  List<String> tokenizeName(String value) {
    final key = fuzzyNameKey(value);
    if (key.isEmpty) return const <String>[];
    return List<String>.unmodifiable(key.split(' ').where((token) => token.isNotEmpty));
  }

  String orderInsensitiveNameKey(String value) {
    final tokens = tokenizeName(value).toList()..sort();
    return tokens.join(' ');
  }

  String reversedNameKey(String value) => tokenizeName(value).reversed.join(' ');

  bool areObviousNameInversions(String left, String right) {
    final leftTokens = tokenizeName(left);
    final rightTokens = tokenizeName(right);
    if (leftTokens.length < 2 || leftTokens.length != rightTokens.length) return false;
    return leftTokens.join(' ') == rightTokens.reversed.join(' ');
  }

  String companyKey(String value) => _stripCommonDiacritics(sanitizeText(value).toLowerCase())
      .replaceAll(_companyPunctuation, ' ')
      .replaceAll(_multipleWhitespace, ' ')
      .trim();

  String addressKey(Iterable<String> components) => components
      .map(sanitizeText)
      .where((part) => part.isNotEmpty)
      .map((part) => _stripCommonDiacritics(part.toLowerCase()))
      .join('|');

  String normalizeLabel(String? value) => value == null ? '' : sanitizeText(value).toLowerCase();

  bool isSemanticallyUsefulName(String value, {int minimumLetters = 2}) {
    final key = fuzzyNameKey(value);
    if (key.isEmpty) return false;
    return key.replaceAll(RegExp(r'[^a-z0-9]'), '').length >= minimumLetters;
  }

  static bool _hasInvalidDots(String value) => value.startsWith('.') || value.endsWith('.') || value.contains('..');

  static String _sanitizeInvisible(String value) => value.replaceAll(_zeroWidthCharacters, '').replaceAll(_controlCharacters, ' ');

  static String _asciiDigits(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      if (rune >= 0x30 && rune <= 0x39) buffer.writeCharCode(rune);
      else if (rune >= 0xFF10 && rune <= 0xFF19) buffer.writeCharCode(0x30 + rune - 0xFF10);
      else if (rune >= 0x0660 && rune <= 0x0669) buffer.writeCharCode(0x30 + rune - 0x0660);
      else if (rune >= 0x06F0 && rune <= 0x06F9) buffer.writeCharCode(0x30 + rune - 0x06F0);
    }
    return buffer.toString();
  }

  static String _asciiDigitsPreservingPlus(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      if (rune == 0x2B) buffer.write('+');
      else if (rune >= 0x30 && rune <= 0x39) buffer.writeCharCode(rune);
      else if (rune >= 0xFF10 && rune <= 0xFF19) buffer.writeCharCode(0x30 + rune - 0xFF10);
      else if (rune >= 0x0660 && rune <= 0x0669) buffer.writeCharCode(0x30 + rune - 0x0660);
      else if (rune >= 0x06F0 && rune <= 0x06F9) buffer.writeCharCode(0x30 + rune - 0x06F0);
      else buffer.writeCharCode(rune);
    }
    return buffer.toString();
  }

  static String _stripCommonDiacritics(String value) {
    var normalized = value;
    for (final entry in _romanianDiacritics.entries) normalized = normalized.replaceAll(entry.key, entry.value);
    for (final entry in _commonLatinDiacritics.entries) normalized = normalized.replaceAll(entry.key, entry.value);
    return normalized;
  }
}
