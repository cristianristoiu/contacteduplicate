import 'dart:convert';

import 'contact_data_normalizer.dart';

enum ContactAccessCapability { writable, readOnly, unknown }
enum ContactSourceKind { local, google, iCloud, exchange, other, unknown }
enum ContactValueKind { phone, email, address, organization, jobTitle, birthday, note, photo, favorite }
enum ScanAccessScope { full, limited, none, unknown }
enum ScanPhase { idle, requestingPermission, reading, normalizing, indexing, scoring, finalizing, completed, cancelled }
enum DuplicateConfidenceLabel { safe, probable, manualReview, ignored }
enum MatchEvidenceKind { phoneExact, emailExact, nameExact, nameInverted, nameSimilar, companyExact, nameAndPhone, nameAndEmail, nameAndCompany }

typedef ContactFingerprint = String;

class ContactPhoneValue {
  final String displayValue;
  final String canonicalKey;
  final String label;
  final String? extension;
  final bool isMatchable;

  const ContactPhoneValue({
    required this.displayValue,
    required this.canonicalKey,
    this.label = '',
    this.extension,
    required this.isMatchable,
  });

  String get identityKey => canonicalKey.isEmpty
      ? 'raw:${displayValue.toLowerCase()}'
      : canonicalKey;

  String get contentKey => _stableHash(jsonEncode(<String, Object?>{
        'value': identityKey,
        'label': label.trim().toLowerCase(),
        'extension': extension?.trim() ?? '',
      }));
}

class ContactEmailValue {
  final String displayValue;
  final String canonicalKey;
  final String label;
  final bool isMatchable;

  const ContactEmailValue({
    required this.displayValue,
    required this.canonicalKey,
    this.label = '',
    required this.isMatchable,
  });

  String get identityKey => canonicalKey.isEmpty
      ? 'raw:${displayValue.toLowerCase()}'
      : canonicalKey;

  String get contentKey => _stableHash(jsonEncode(<String, Object?>{
        'value': identityKey,
        'label': label.trim().toLowerCase(),
      }));
}

class ContactAddressValue {
  final String label;
  final String street;
  final String city;
  final String region;
  final String postalCode;
  final String country;
  final String canonicalKey;

  const ContactAddressValue({
    this.label = '',
    this.street = '',
    this.city = '',
    this.region = '',
    this.postalCode = '',
    this.country = '',
    required this.canonicalKey,
  });

  bool get isEmpty => street.isEmpty &&
      city.isEmpty &&
      region.isEmpty &&
      postalCode.isEmpty &&
      country.isEmpty;

  String get contentKey => _stableHash(jsonEncode(<String, String>{
        'canonical': canonicalKey.trim(),
        'label': label.trim().toLowerCase(),
        'street': street.trim(),
        'city': city.trim(),
        'region': region.trim(),
        'postalCode': postalCode.trim(),
        'country': country.trim(),
      }));
}

class ContactOrganizationValue {
  final String company;
  final String department;
  final String jobTitle;
  final String companyKey;

  const ContactOrganizationValue({
    this.company = '',
    this.department = '',
    this.jobTitle = '',
    required this.companyKey,
  });

  bool get isEmpty =>
      company.isEmpty && department.isEmpty && jobTitle.isEmpty;

  String get contentKey => _stableHash(jsonEncode(<String, String>{
        'company': companyKey.trim(),
        'department': department.trim().toLowerCase(),
        'jobTitle': jobTitle.trim().toLowerCase(),
      }));
}

class ContactNameParts {
  final String displayName;
  final String givenName;
  final String middleName;
  final String familyName;
  final String prefix;
  final String suffix;
  final bool hasOriginalDisplayName;

  const ContactNameParts({
    required this.displayName,
    this.givenName = '',
    this.middleName = '',
    this.familyName = '',
    this.prefix = '',
    this.suffix = '',
    this.hasOriginalDisplayName = true,
  });

  String get structuredDisplayName => <String>[
        prefix,
        givenName,
        middleName,
        familyName,
        suffix,
      ].where((value) => value.trim().isNotEmpty).join(' ');
}

class ContactSourceInfo {
  static const int maxIdentityLength = 256;

  final String sourceId;
  final String sourceName;
  final ContactSourceKind kind;

  const ContactSourceInfo({
    this.sourceId = '',
    this.sourceName = '',
    this.kind = ContactSourceKind.unknown,
  });

  bool get isKnown => sourceId.isNotEmpty ||
      sourceName.isNotEmpty ||
      kind != ContactSourceKind.unknown;

  String get categoryKey => kind.name;

  String get identityFingerprint => stableOpaqueId(
        <String>[
          _bounded(sourceId, maxIdentityLength),
          _bounded(sourceName, maxIdentityLength),
          categoryKey,
        ],
        namespace: 'contact-source',
      );
}

class ContactCapabilities {
  final ContactAccessCapability update;
  final ContactAccessCapability delete;
  final String? limitationCode;

  const ContactCapabilities({
    this.update = ContactAccessCapability.unknown,
    this.delete = ContactAccessCapability.unknown,
    this.limitationCode,
  });

  bool get canUpdate => update == ContactAccessCapability.writable;
  bool get canDelete => delete == ContactAccessCapability.writable;
  bool get isKnownReadOnly => update == ContactAccessCapability.readOnly ||
      delete == ContactAccessCapability.readOnly;
  bool get isFullyWritable => canUpdate && canDelete;
  bool get isMixed => update != delete &&
      update != ContactAccessCapability.unknown &&
      delete != ContactAccessCapability.unknown;

  String get fingerprint => stableOpaqueId(
        <String>[
          update.name,
          delete.name,
          _bounded(limitationCode ?? '', 96),
        ],
        namespace: 'contact-capability',
      );
}

class ContactRevisionInfo {
  final DateTime? updatedAt;
  final String fingerprint;
  final String contentFingerprint;
  final String identityFingerprint;
  final String capabilityFingerprint;
  final String sourceFingerprint;

  const ContactRevisionInfo({
    this.updatedAt,
    required this.fingerprint,
    this.contentFingerprint = '',
    this.identityFingerprint = '',
    this.capabilityFingerprint = '',
    this.sourceFingerprint = '',
  });

  bool matches(ContactRevisionInfo other) {
    if (fingerprint != other.fingerprint) return false;
    if (updatedAt == null || other.updatedAt == null) return true;
    if (!isPlausible() || !other.isPlausible()) return false;
    return updatedAt!.toUtc() == other.updatedAt!.toUtc();
  }

  bool contentMatches(ContactRevisionInfo other) {
    final left = contentFingerprint.isEmpty ? fingerprint : contentFingerprint;
    final right = other.contentFingerprint.isEmpty
        ? other.fingerprint
        : other.contentFingerprint;
    return left == right;
  }

  bool contextMatches(ContactRevisionInfo other) =>
      contentMatches(other) &&
      _optionalEquals(capabilityFingerprint, other.capabilityFingerprint) &&
      _optionalEquals(sourceFingerprint, other.sourceFingerprint);

  bool isPlausible({
    DateTime? now,
    Duration futureTolerance = const Duration(minutes: 5),
  }) {
    final value = updatedAt;
    if (value == null) return true;
    final reference = (now ?? DateTime.now()).toUtc();
    return !value.toUtc().isAfter(reference.add(futureTolerance));
  }

  static bool _optionalEquals(String left, String right) =>
      left.isEmpty || right.isEmpty || left == right;
}

class ScanMetrics {
  final Duration totalDuration;
  final int normalizedContacts;
  final int ignoredPhoneValues;
  final int ignoredEmailValues;
  final int unstableIdContacts;
  final int readOnlyContacts;
  final int candidateGroups;

  const ScanMetrics({
    this.totalDuration = Duration.zero,
    this.normalizedContacts = 0,
    this.ignoredPhoneValues = 0,
    this.ignoredEmailValues = 0,
    this.unstableIdContacts = 0,
    this.readOnlyContacts = 0,
    this.candidateGroups = 0,
  });
}

class MatchEvidence {
  final MatchEvidenceKind kind;
  final int scoreContribution;
  final String evidenceFingerprint;
  final bool strong;

  const MatchEvidence({
    required this.kind,
    required this.scoreContribution,
    required this.evidenceFingerprint,
    required this.strong,
  });

  bool get isValid =>
      scoreContribution >= 0 && evidenceFingerprint.trim().isNotEmpty;
}

class ContactRecord {
  final String nativeId;
  final bool hasStableNativeId;
  final ContactNameParts name;
  final List<ContactPhoneValue> phones;
  final List<ContactEmailValue> emails;
  final List<ContactAddressValue> addresses;
  final List<ContactOrganizationValue> organizations;
  final DateTime? birthday;
  final bool notesAvailable;
  final bool photoAvailable;
  final bool isFavorite;
  final ContactSourceInfo source;
  final ContactCapabilities capabilities;
  final ContactRevisionInfo revision;

  ContactRecord({
    required this.nativeId,
    required this.hasStableNativeId,
    required this.name,
    List<ContactPhoneValue> phones = const <ContactPhoneValue>[],
    List<ContactEmailValue> emails = const <ContactEmailValue>[],
    List<ContactAddressValue> addresses = const <ContactAddressValue>[],
    List<ContactOrganizationValue> organizations =
        const <ContactOrganizationValue>[],
    this.birthday,
    this.notesAvailable = false,
    this.photoAvailable = false,
    this.isFavorite = false,
    this.source = const ContactSourceInfo(),
    this.capabilities = const ContactCapabilities(),
    required this.revision,
  })  : phones = List<ContactPhoneValue>.unmodifiable(phones),
        emails = List<ContactEmailValue>.unmodifiable(emails),
        addresses = List<ContactAddressValue>.unmodifiable(addresses),
        organizations = List<ContactOrganizationValue>.unmodifiable(
          organizations,
        );

  bool get effectiveStableIdentity =>
      hasStableNativeId && nativeId.trim().isNotEmpty;
  bool get hasWritableStableIdentity =>
      effectiveStableIdentity && capabilities.isFullyWritable;
  bool get hasAnyContactMethod => phones.isNotEmpty || emails.isNotEmpty;
  String get primaryCompany => organizations
          .where((value) => value.company.isNotEmpty)
          .map((value) => value.company)
          .firstOrNull ??
      '';
  String get contentFingerprint => revision.contentFingerprint.isEmpty
      ? revision.fingerprint
      : revision.contentFingerprint;
  String get identityFingerprint => revision.identityFingerprint.isEmpty
      ? revision.fingerprint
      : revision.identityFingerprint;
  String get contextFingerprint => stableOpaqueId(
        <String>[
          contentFingerprint,
          revision.capabilityFingerprint,
          revision.sourceFingerprint,
        ],
        namespace: 'contact-context',
      );
}

class ContactFingerprintBuilder {
  final ContactDataNormalizer normalizer;

  ContactFingerprintBuilder(this.normalizer);

  String build({
    required String nativeId,
    required ContactNameParts name,
    required Iterable<ContactPhoneValue> phones,
    required Iterable<ContactEmailValue> emails,
    required Iterable<ContactAddressValue> addresses,
    required Iterable<ContactOrganizationValue> organizations,
    DateTime? birthday,
    bool notesAvailable = false,
    bool photoAvailable = false,
    bool isFavorite = false,
    ContactSourceInfo source = const ContactSourceInfo(),
    ContactCapabilities capabilities = const ContactCapabilities(),
  }) {
    return buildIdentity(
      nativeId: nativeId,
      contentFingerprint: buildContent(
        name: name,
        phones: phones,
        emails: emails,
        addresses: addresses,
        organizations: organizations,
        birthday: birthday,
        notesAvailable: notesAvailable,
        photoAvailable: photoAvailable,
        isFavorite: isFavorite,
      ),
      source: source,
      capabilities: capabilities,
    );
  }

  String buildContent({
    required ContactNameParts name,
    required Iterable<ContactPhoneValue> phones,
    required Iterable<ContactEmailValue> emails,
    required Iterable<ContactAddressValue> addresses,
    required Iterable<ContactOrganizationValue> organizations,
    DateTime? birthday,
    bool notesAvailable = false,
    bool photoAvailable = false,
    bool isFavorite = false,
  }) {
    final normalizedPhones = _canonicalValues(
      phones.map((value) => value.contentKey),
    );
    final normalizedEmails = _canonicalValues(
      emails.map((value) => value.contentKey),
    );
    final normalizedAddresses = _canonicalValues(
      addresses.where((value) => !value.isEmpty).map((value) => value.contentKey),
    );
    final normalizedOrganizations = _canonicalValues(
      organizations
          .where((value) => !value.isEmpty)
          .map((value) => value.contentKey),
    );
    final nameKey = name.hasOriginalDisplayName
        ? normalizer.exactNameKey(name.displayName)
        : '';
    return _stableHash(jsonEncode(<String, Object?>{
      'name': nameKey,
      'given': normalizer.exactNameKey(name.givenName),
      'middle': normalizer.exactNameKey(name.middleName),
      'family': normalizer.exactNameKey(name.familyName),
      'prefix': normalizer.exactNameKey(name.prefix),
      'suffix': normalizer.exactNameKey(name.suffix),
      'phones': normalizedPhones,
      'emails': normalizedEmails,
      'addresses': normalizedAddresses,
      'organizations': normalizedOrganizations,
      'birthday': canonicalDateOnly(birthday),
      'notesAvailable': notesAvailable,
      'photoAvailable': photoAvailable,
      'favorite': isFavorite,
    }));
  }

  String buildIdentity({
    required String nativeId,
    required String contentFingerprint,
    ContactSourceInfo source = const ContactSourceInfo(),
    ContactCapabilities capabilities = const ContactCapabilities(),
  }) {
    return _stableHash(jsonEncode(<String, Object?>{
      'id': nativeId.trim(),
      'content': contentFingerprint,
      'source': source.identityFingerprint,
      'capability': capabilities.fingerprint,
    }));
  }

  String buildCapability(ContactCapabilities capabilities) =>
      capabilities.fingerprint;

  String buildSource(ContactSourceInfo source) => source.identityFingerprint;
}

String? canonicalDateOnly(DateTime? value) {
  if (value == null) return null;
  final date = value.isUtc ? value.toLocal() : value;
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String stableOpaqueId(Iterable<String> values, {String namespace = 'id'}) {
  final safeNamespace = _sanitizeNamespace(namespace);
  final sorted = _canonicalValues(values);
  return '$safeNamespace-${_stableHash(jsonEncode(sorted))}';
}

List<String> canonicalStringSet(Iterable<String> values) =>
    List<String>.unmodifiable(_canonicalValues(values));

List<String> _canonicalValues(Iterable<String> values) {
  final sorted = values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: true)
    ..sort();
  return sorted;
}

String _sanitizeNamespace(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_-]'), '-')
      .replaceAll(RegExp(r'-+'), '-');
  if (normalized.isEmpty) return 'id';
  return _bounded(normalized, 48);
}

String _bounded(String value, int maxLength) {
  final trimmed = value.trim();
  return trimmed.length <= maxLength
      ? trimmed
      : trimmed.substring(0, maxLength);
}

String _stableHash(String value) {
  var hash1 = 0xcbf29ce484222325;
  var hash2 = 0x84222325cbf29ce4;
  for (final byte in utf8.encode(value)) {
    hash1 ^= byte;
    hash1 = (hash1 * 0x100000001b3) & 0x7fffffffffffffff;
    hash2 ^= (byte + 31);
    hash2 = (hash2 * 0x100000001b3) & 0x7fffffffffffffff;
  }
  return '${hash1.toRadixString(16).padLeft(16, '0')}'
      '${hash2.toRadixString(16).padLeft(16, '0')}';
}

extension _FirstOrNullContactModel<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
