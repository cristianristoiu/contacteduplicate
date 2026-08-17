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

  String get identityKey => canonicalKey.isEmpty ? 'raw:${displayValue.toLowerCase()}' : canonicalKey;
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

  String get identityKey => canonicalKey.isEmpty ? 'raw:${displayValue.toLowerCase()}' : canonicalKey;
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

  bool get isEmpty => street.isEmpty && city.isEmpty && region.isEmpty && postalCode.isEmpty && country.isEmpty;
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

  bool get isEmpty => company.isEmpty && department.isEmpty && jobTitle.isEmpty;
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
  final String sourceId;
  final String sourceName;
  final ContactSourceKind kind;

  const ContactSourceInfo({
    this.sourceId = '',
    this.sourceName = '',
    this.kind = ContactSourceKind.unknown,
  });

  bool get isKnown => sourceId.isNotEmpty || sourceName.isNotEmpty || kind != ContactSourceKind.unknown;
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
  bool get isKnownReadOnly => update == ContactAccessCapability.readOnly || delete == ContactAccessCapability.readOnly;
  bool get isFullyWritable => canUpdate && canDelete;
}

class ContactRevisionInfo {
  final DateTime? updatedAt;
  final String fingerprint;

  const ContactRevisionInfo({
    this.updatedAt,
    required this.fingerprint,
  });

  bool matches(ContactRevisionInfo other) {
    if (fingerprint != other.fingerprint) return false;
    if (updatedAt == null || other.updatedAt == null) return true;
    return updatedAt!.toUtc() == other.updatedAt!.toUtc();
  }
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
    List<ContactOrganizationValue> organizations = const <ContactOrganizationValue>[],
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
        organizations = List<ContactOrganizationValue>.unmodifiable(organizations);

  bool get hasWritableStableIdentity => hasStableNativeId && capabilities.isFullyWritable;
  bool get hasAnyContactMethod => phones.isNotEmpty || emails.isNotEmpty;
  String get primaryCompany => organizations.where((value) => value.company.isNotEmpty).map((value) => value.company).firstOrNull ?? '';
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
  }) {
    final normalizedPhones = phones.map((value) => value.identityKey).toSet().toList()..sort();
    final normalizedEmails = emails.map((value) => value.identityKey).toSet().toList()..sort();
    final normalizedAddresses = addresses.map((value) => value.canonicalKey).where((value) => value.isNotEmpty).toSet().toList()..sort();
    final normalizedOrganizations = organizations.map((value) => value.companyKey).where((value) => value.isNotEmpty).toSet().toList()..sort();
    return _stableHash(jsonEncode(<String, Object?>{
      'id': nativeId.trim(),
      'name': normalizer.exactNameKey(name.displayName),
      'given': normalizer.exactNameKey(name.givenName),
      'family': normalizer.exactNameKey(name.familyName),
      'phones': normalizedPhones,
      'emails': normalizedEmails,
      'addresses': normalizedAddresses,
      'organizations': normalizedOrganizations,
      'birthday': birthday?.toUtc().toIso8601String(),
    }));
  }
}

String stableOpaqueId(Iterable<String> values, {String namespace = 'id'}) {
  final sorted = values.map((value) => value.trim()).where((value) => value.isNotEmpty).toSet().toList()..sort();
  return '$namespace-${_stableHash(jsonEncode(sorted))}';
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
  return '${hash1.toRadixString(16).padLeft(16, '0')}${hash2.toRadixString(16).padLeft(16, '0')}';
}

extension _FirstOrNullContactModel<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
