import 'dart:async';

import 'package:flutter_contacts/flutter_contacts.dart';

import 'contact_data_normalizer.dart';
import 'contact_models.dart';
import 'duplicate_scoring.dart';

enum ContactsPermissionState {
  granted,
  limited,
  denied,
  permanentlyDenied,
  restricted,
  notDetermined,
  failure,
}

enum DuplicateMatchReason { phone, email, name, company }

enum ScanCancellationReason { user, lifecycle, superseded }

class ScanCancellationToken {
  bool _cancelled = false;
  ScanCancellationReason? _reason;

  bool get isCancelled => _cancelled;
  ScanCancellationReason? get reason => _reason;

  void cancel([ScanCancellationReason reason = ScanCancellationReason.user]) {
    if (_cancelled) return;
    _cancelled = true;
    _reason = reason;
  }

  void throwIfCancelled() {
    if (_cancelled) throw const _ScanCancelledException();
  }
}

class ScanProgress {
  final ScanPhase phase;
  final double ratio;
  final int processed;
  final int total;

  const ScanProgress({
    required this.phase,
    required this.ratio,
    required this.processed,
    required this.total,
  }) : assert(ratio >= 0 && ratio <= 1);
}

class ScannedContact {
  final String nativeId;
  final String displayName;
  final List<String> phones;
  final List<String> emails;
  final bool hasStableNativeId;
  final bool hasOriginalDisplayName;
  final ContactRecord? record;

  const ScannedContact({
    required this.nativeId,
    required this.displayName,
    required this.phones,
    required this.emails,
    this.hasStableNativeId = true,
    this.hasOriginalDisplayName = true,
    this.record,
  });

  bool get canBeDestructivelyMerged =>
      hasStableNativeId && (record?.capabilities.isFullyWritable ?? false);
}

class DuplicateContactGroup {
  final String id;
  final List<ScannedContact> contacts;
  final Set<DuplicateMatchReason> reasons;
  final int confidenceScore;
  final DuplicateConfidenceLabel confidenceLabel;
  final List<MatchEvidence> evidence;
  final bool requiresManualReview;
  final bool canBeMerged;
  final String? proposedPrimaryContactId;
  final String revisionFingerprint;
  final bool overlapsAnotherGroup;

  const DuplicateContactGroup({
    required this.id,
    required this.contacts,
    required this.reasons,
    required this.confidenceScore,
    this.confidenceLabel = DuplicateConfidenceLabel.manualReview,
    this.evidence = const <MatchEvidence>[],
    this.requiresManualReview = true,
    this.canBeMerged = false,
    this.proposedPrimaryContactId,
    this.revisionFingerprint = '',
    this.overlapsAnotherGroup = false,
  })  : assert(contacts.length >= 2),
        assert(confidenceScore >= 0 && confidenceScore <= 100);

  DuplicateContactGroup copyWith({bool? overlapsAnotherGroup}) {
    return DuplicateContactGroup(
      id: id,
      contacts: contacts,
      reasons: reasons,
      confidenceScore: confidenceScore,
      confidenceLabel: confidenceLabel,
      evidence: evidence,
      requiresManualReview: requiresManualReview,
      canBeMerged: canBeMerged,
      proposedPrimaryContactId: proposedPrimaryContactId,
      revisionFingerprint: revisionFingerprint,
      overlapsAnotherGroup: overlapsAnotherGroup ?? this.overlapsAnotherGroup,
    );
  }
}

class ContactsScanResult {
  final ContactsPermissionState permissionState;
  final ScanAccessScope accessScope;
  final int totalContacts;
  final List<DuplicateContactGroup> duplicateGroups;
  final DateTime? scannedAt;
  final ScanMetrics metrics;
  final bool wasCancelled;
  final String? errorCode;

  const ContactsScanResult({
    required this.permissionState,
    this.accessScope = ScanAccessScope.unknown,
    required this.totalContacts,
    required this.duplicateGroups,
    this.scannedAt,
    this.metrics = const ScanMetrics(),
    this.wasCancelled = false,
    this.errorCode,
  });

  const ContactsScanResult.permissionDenied(ContactsPermissionState state)
      : this(
          permissionState: state,
          accessScope: ScanAccessScope.none,
          totalContacts: 0,
          duplicateGroups: const <DuplicateContactGroup>[],
        );

  const ContactsScanResult.failure(String code)
      : this(
          permissionState: ContactsPermissionState.failure,
          accessScope: ScanAccessScope.unknown,
          totalContacts: 0,
          duplicateGroups: const <DuplicateContactGroup>[],
          errorCode: code,
        );

  const ContactsScanResult.cancelled()
      : this(
          permissionState: ContactsPermissionState.failure,
          accessScope: ScanAccessScope.unknown,
          totalContacts: 0,
          duplicateGroups: const <DuplicateContactGroup>[],
          wasCancelled: true,
          errorCode: 'contacts_scan_cancelled',
        );

  bool get canReadContacts =>
      permissionState == ContactsPermissionState.granted ||
      permissionState == ContactsPermissionState.limited;
  bool get isEmptyValid => canReadContacts && totalContacts == 0 && !wasCancelled;
}

abstract interface class ContactsScanService {
  Future<ContactsScanResult> scan({
    ScanCancellationToken? cancellationToken,
    void Function(ScanProgress progress)? onProgress,
  });
  Future<void> openAppSettings();
  Future<ContactsPermissionState> checkPermission();
}

typedef ContactsPermissionRequester = Future<PermissionStatus> Function();
typedef ContactsPermissionChecker = Future<PermissionStatus> Function();
typedef NativeContactsReader = Future<List<Contact>> Function();
typedef AppSettingsOpener = Future<void> Function();
typedef ScanClock = DateTime Function();

class NativeContactsScanService implements ContactsScanService {
  final ContactsPermissionRequester _requestPermission;
  final ContactsPermissionChecker _checkPermission;
  final NativeContactsReader _readContacts;
  final AppSettingsOpener _openSettings;
  final ContactDataNormalizer _normalizer;
  final DuplicateScorer _scorer;
  final ScanClock _clock;
  int _generation = 0;

  NativeContactsScanService({
    ContactsPermissionRequester? requestPermission,
    ContactsPermissionChecker? checkPermission,
    NativeContactsReader? readContacts,
    AppSettingsOpener? openSettings,
    String? defaultCountryCallingCode = '40',
    ContactDataNormalizer? normalizer,
    DuplicateScorer? scorer,
    ScanClock? clock,
  })  : _requestPermission = requestPermission ??
            (() => FlutterContacts.permissions.request(PermissionType.read)),
        _checkPermission = checkPermission ??
            (() => FlutterContacts.permissions.check(PermissionType.read)),
        _readContacts = readContacts ??
            (() => FlutterContacts.getAll(
                  properties: const <ContactProperty>{
                    ContactProperty.name,
                    ContactProperty.phone,
                    ContactProperty.email,
                    ContactProperty.address,
                    ContactProperty.organization,
                    ContactProperty.note,
                    ContactProperty.photoThumbnail,
                  },
                )),
        _openSettings = openSettings ??
            (() async => FlutterContacts.permissions.openSettings()),
        _normalizer = normalizer ?? ContactDataNormalizer(defaultCountryCallingCode: defaultCountryCallingCode),
        _scorer = scorer ?? DuplicateScorer(normalizer: normalizer ?? ContactDataNormalizer(defaultCountryCallingCode: defaultCountryCallingCode)),
        _clock = clock ?? DateTime.now;

  @override
  Future<ContactsPermissionState> checkPermission() async {
    try {
      return _mapPermission(await _checkPermission());
    } on Object {
      return ContactsPermissionState.failure;
    }
  }

  @override
  Future<ContactsScanResult> scan({
    ScanCancellationToken? cancellationToken,
    void Function(ScanProgress progress)? onProgress,
  }) async {
    final generation = ++_generation;
    final startedAt = _clock();
    final token = cancellationToken ?? ScanCancellationToken();
    try {
      _progress(onProgress, ScanPhase.requestingPermission, 0.02, 0, 0);
      token.throwIfCancelled();
      final permission = await _requestPermission();
      if (generation != _generation) return const ContactsScanResult.cancelled();
      final permissionState = _mapPermission(permission);
      if (!_canRead(permissionState)) return ContactsScanResult.permissionDenied(permissionState);

      _progress(onProgress, ScanPhase.reading, 0.08, 0, 0);
      final nativeContacts = await _readContacts();
      token.throwIfCancelled();
      if (generation != _generation) return const ContactsScanResult.cancelled();

      final finalPermission = _mapPermission(await _checkPermission());
      if (!_canRead(finalPermission)) return ContactsScanResult.permissionDenied(finalPermission);

      if (nativeContacts.isEmpty) {
        return ContactsScanResult(
          permissionState: finalPermission,
          accessScope: _scopeFor(finalPermission),
          totalContacts: 0,
          duplicateGroups: const <DuplicateContactGroup>[],
          scannedAt: _clock().toUtc(),
          metrics: ScanMetrics(totalDuration: _clock().difference(startedAt)),
        );
      }

      _progress(onProgress, ScanPhase.normalizing, 0.12, 0, nativeContacts.length);
      final contacts = <ScannedContact>[];
      var unstableIds = 0;
      var ignoredPhones = 0;
      var ignoredEmails = 0;
      final seenStableIds = <String>{};
      final collidingIds = <String>{};
      for (var index = 0; index < nativeContacts.length; index++) {
        token.throwIfCancelled();
        final mapped = _mapContact(MapEntry<int, Contact>(index, nativeContacts[index]));
        contacts.add(mapped.contact);
        unstableIds += mapped.contact.hasStableNativeId ? 0 : 1;
        ignoredPhones += mapped.ignoredPhones;
        ignoredEmails += mapped.ignoredEmails;
        if (mapped.contact.hasStableNativeId && !seenStableIds.add(mapped.contact.nativeId)) {
          collidingIds.add(mapped.contact.nativeId);
        }
        if (index % 25 == 0 || index == nativeContacts.length - 1) {
          _progress(onProgress, ScanPhase.normalizing, 0.12 + 0.38 * ((index + 1) / nativeContacts.length), index + 1, nativeContacts.length);
        }
      }

      final safeContacts = collidingIds.isEmpty
          ? contacts
          : contacts.map((contact) {
              if (!collidingIds.contains(contact.nativeId)) return contact;
              return ScannedContact(
                nativeId: contact.nativeId,
                displayName: contact.displayName,
                phones: contact.phones,
                emails: contact.emails,
                hasStableNativeId: false,
                hasOriginalDisplayName: contact.hasOriginalDisplayName,
                record: contact.record,
              );
            }).toList(growable: false);

      _progress(onProgress, ScanPhase.indexing, 0.52, 0, safeContacts.length);
      final groups = _findDuplicates(safeContacts, token, onProgress);
      token.throwIfCancelled();
      if (generation != _generation) return const ContactsScanResult.cancelled();
      _progress(onProgress, ScanPhase.finalizing, 0.96, groups.length, groups.length);

      final scannedAt = _clock().toUtc();
      final result = ContactsScanResult(
        permissionState: finalPermission,
        accessScope: _scopeFor(finalPermission),
        totalContacts: safeContacts.length,
        duplicateGroups: groups,
        scannedAt: scannedAt,
        metrics: ScanMetrics(
          totalDuration: _clock().difference(startedAt),
          normalizedContacts: safeContacts.length,
          ignoredPhoneValues: ignoredPhones,
          ignoredEmailValues: ignoredEmails,
          unstableIdContacts: unstableIds + collidingIds.length,
          candidateGroups: groups.length,
        ),
      );
      _progress(onProgress, ScanPhase.completed, 1, safeContacts.length, safeContacts.length);
      return result;
    } on _ScanCancelledException {
      return const ContactsScanResult.cancelled();
    } on Object {
      return const ContactsScanResult.failure('contacts_scan_failed');
    }
  }

  @override
  Future<void> openAppSettings() => _openSettings();

  ContactsPermissionState _mapPermission(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted: return ContactsPermissionState.granted;
      case PermissionStatus.limited: return ContactsPermissionState.limited;
      case PermissionStatus.denied: return ContactsPermissionState.denied;
      case PermissionStatus.permanentlyDenied: return ContactsPermissionState.permanentlyDenied;
      case PermissionStatus.restricted: return ContactsPermissionState.restricted;
      case PermissionStatus.notDetermined: return ContactsPermissionState.notDetermined;
    }
  }

  bool _canRead(ContactsPermissionState state) => state == ContactsPermissionState.granted || state == ContactsPermissionState.limited;
  ScanAccessScope _scopeFor(ContactsPermissionState state) => state == ContactsPermissionState.granted ? ScanAccessScope.full : state == ContactsPermissionState.limited ? ScanAccessScope.limited : ScanAccessScope.none;

  _MappedContact _mapContact(MapEntry<int, Contact> entry) {
    final contact = entry.value;
    final rawId = contact.id?.trim() ?? '';
    final hasStableNativeId = rawId.isNotEmpty;
    final displayName = _normalizer.normalizeDisplayName(contact.displayName ?? '');
    final hasOriginalDisplayName = displayName.isNotEmpty;
    final normalizedName = hasOriginalDisplayName ? displayName : 'Contact fara nume';

    final phoneByKey = <String, ContactPhoneValue>{};
    var ignoredPhones = 0;
    for (final phone in contact.phones) {
      final normalized = _normalizer.normalizePhoneValue(phone.number);
      if (normalized.displayValue.isEmpty) continue;
      if (!normalized.isMatchable) ignoredPhones++;
      final identity = normalized.isMatchable ? normalized.canonicalKey : 'raw:${normalized.displayValue.toLowerCase()}';
      phoneByKey.putIfAbsent(identity, () => ContactPhoneValue(
        displayValue: normalized.displayValue,
        canonicalKey: normalized.canonicalKey,
        extension: normalized.extension,
        isMatchable: normalized.isMatchable,
      ));
    }

    final emailByKey = <String, ContactEmailValue>{};
    var ignoredEmails = 0;
    for (final email in contact.emails) {
      final normalized = _normalizer.normalizeEmailValue(email.address);
      if (normalized.displayValue.isEmpty) continue;
      if (!normalized.isMatchable) ignoredEmails++;
      final identity = normalized.isMatchable ? normalized.canonicalKey : 'raw:${normalized.displayValue.toLowerCase()}';
      emailByKey.putIfAbsent(identity, () => ContactEmailValue(
        displayValue: normalized.displayValue,
        canonicalKey: normalized.canonicalKey,
        isMatchable: normalized.isMatchable,
      ));
    }

    final phoneValues = phoneByKey.values.toList()..sort((a, b) => a.identityKey.compareTo(b.identityKey));
    final emailValues = emailByKey.values.toList()..sort((a, b) => a.identityKey.compareTo(b.identityKey));
    final name = contact.name;
    final nameParts = ContactNameParts(
      displayName: normalizedName,
      givenName: _normalizer.sanitizeText(name?.first ?? ''),
      middleName: _normalizer.sanitizeText(name?.middle ?? ''),
      familyName: _normalizer.sanitizeText(name?.last ?? ''),
      prefix: _normalizer.sanitizeText(name?.prefix ?? ''),
      suffix: _normalizer.sanitizeText(name?.suffix ?? ''),
      hasOriginalDisplayName: hasOriginalDisplayName,
    );

    final organizations = contact.organizations.map((organization) {
      final company = _normalizer.sanitizeText(organization.organizationName);
      return ContactOrganizationValue(
        company: company,
        department: _normalizer.sanitizeText(organization.departmentName),
        jobTitle: _normalizer.sanitizeText(organization.jobTitle),
        companyKey: _normalizer.companyKey(company),
      );
    }).where((value) => !value.isEmpty).toList(growable: false);

    final addresses = contact.addresses.map((address) {
      final components = <String>[
        address.street,
        address.city,
        address.state,
        address.postalCode,
        address.country,
      ];
      return ContactAddressValue(
        street: _normalizer.sanitizeText(address.street),
        city: _normalizer.sanitizeText(address.city),
        region: _normalizer.sanitizeText(address.state),
        postalCode: _normalizer.sanitizeText(address.postalCode),
        country: _normalizer.sanitizeText(address.country),
        canonicalKey: _normalizer.addressKey(components),
      );
    }).where((value) => !value.isEmpty).toList(growable: false);

    final nativeId = hasStableNativeId ? rawId : 'temporary-contact-${entry.key}';
    final fingerprintBuilder = ContactFingerprintBuilder(_normalizer);
    final revision = ContactRevisionInfo(
      fingerprint: fingerprintBuilder.build(
        nativeId: nativeId,
        name: nameParts,
        phones: phoneValues,
        emails: emailValues,
        addresses: addresses,
        organizations: organizations,
      ),
    );
    final record = ContactRecord(
      nativeId: nativeId,
      hasStableNativeId: hasStableNativeId,
      name: nameParts,
      phones: phoneValues,
      emails: emailValues,
      addresses: addresses,
      organizations: organizations,
      notesAvailable: contact.notes.isNotEmpty,
      photoAvailable: contact.photo?.thumbnail != null,
      capabilities: const ContactCapabilities(),
      revision: revision,
    );

    return _MappedContact(
      contact: ScannedContact(
        nativeId: nativeId,
        displayName: normalizedName,
        phones: List<String>.unmodifiable(phoneValues.where((value) => value.isMatchable).map((value) => value.canonicalKey)),
        emails: List<String>.unmodifiable(emailValues.where((value) => value.isMatchable).map((value) => value.canonicalKey)),
        hasStableNativeId: hasStableNativeId,
        hasOriginalDisplayName: hasOriginalDisplayName,
        record: record,
      ),
      ignoredPhones: ignoredPhones,
      ignoredEmails: ignoredEmails,
    );
  }

  List<DuplicateContactGroup> _findDuplicates(
    List<ScannedContact> contacts,
    ScanCancellationToken token,
    void Function(ScanProgress progress)? onProgress,
  ) {
    if (contacts.length < 2) return const <DuplicateContactGroup>[];
    final pairCandidates = <String, _PairCandidate>{};
    final phoneOwners = <String, List<int>>{};
    final emailOwners = <String, List<int>>{};
    final nameOwners = <String, List<int>>{};
    final companyOwners = <String, List<int>>{};

    for (var index = 0; index < contacts.length; index++) {
      token.throwIfCancelled();
      final contact = contacts[index];
      for (final phone in contact.phones) phoneOwners.putIfAbsent(phone, () => <int>[]).add(index);
      for (final email in contact.emails) emailOwners.putIfAbsent(email, () => <int>[]).add(index);
      if (contact.hasOriginalDisplayName) {
        final nameKey = _normalizer.exactNameKey(contact.displayName);
        if (_normalizer.isSemanticallyUsefulName(nameKey, minimumLetters: 3)) nameOwners.putIfAbsent(nameKey, () => <int>[]).add(index);
      }
      final companies = contact.record?.organizations.map((value) => value.companyKey).where((value) => value.isNotEmpty).toSet() ?? const <String>{};
      for (final company in companies) companyOwners.putIfAbsent(company, () => <int>[]).add(index);
    }

    _addPairs(phoneOwners, pairCandidates, maxOwners: 50);
    _addPairs(emailOwners, pairCandidates, maxOwners: 50);
    _addPairs(nameOwners, pairCandidates, maxOwners: _scorer.policy.maxPopularKeyOwners);
    _addPairs(companyOwners, pairCandidates, maxOwners: _scorer.policy.maxPopularKeyOwners);

    final fuzzyPool = contacts.asMap().entries.where((entry) => entry.value.hasOriginalDisplayName && _normalizer.isSemanticallyUsefulName(entry.value.displayName, minimumLetters: 3)).toList(growable: false);
    for (var i = 0; i < fuzzyPool.length; i++) {
      token.throwIfCancelled();
      final left = fuzzyPool[i];
      for (var j = i + 1; j < fuzzyPool.length; j++) {
        final right = fuzzyPool[j];
        if (_normalizer.orderInsensitiveNameKey(left.value.displayName).isEmpty) continue;
        final similarity = _scorer.nameSimilarity(left.value.displayName, right.value.displayName);
        if (similarity >= _scorer.policy.similarNameThreshold) {
          _putPair(pairCandidates, left.key, right.key);
        }
      }
      if (i % 20 == 0 || i == fuzzyPool.length - 1) {
        _progress(onProgress, ScanPhase.scoring, 0.65 + 0.25 * ((i + 1) / fuzzyPool.length), i + 1, fuzzyPool.length);
      }
    }

    final groups = <DuplicateContactGroup>[];
    for (final candidate in pairCandidates.values) {
      token.throwIfCancelled();
      final left = contacts[candidate.left];
      final right = contacts[candidate.right];
      final leftRecord = left.record;
      final rightRecord = right.record;
      if (leftRecord == null || rightRecord == null) continue;
      final score = _scorer.scorePair(leftRecord, rightRecord);
      if (!_scorer.policy.shouldSurface(score.score)) continue;
      final reasons = <DuplicateMatchReason>{
        if (score.evidence.any((item) => item.kind == MatchEvidenceKind.phoneExact)) DuplicateMatchReason.phone,
        if (score.evidence.any((item) => item.kind == MatchEvidenceKind.emailExact)) DuplicateMatchReason.email,
        if (score.evidence.any((item) => item.kind == MatchEvidenceKind.nameExact || item.kind == MatchEvidenceKind.nameInverted || item.kind == MatchEvidenceKind.nameSimilar)) DuplicateMatchReason.name,
        if (score.evidence.any((item) => item.kind == MatchEvidenceKind.companyExact)) DuplicateMatchReason.company,
      };
      final members = <ScannedContact>[left, right]..sort((a, b) {
        final compareName = _normalizer.exactNameKey(a.displayName).compareTo(_normalizer.exactNameKey(b.displayName));
        return compareName != 0 ? compareName : a.nativeId.compareTo(b.nativeId);
      });
      final canBeMerged = members.every((contact) => contact.canBeDestructivelyMerged) && !score.requiresManualReview;
      groups.add(DuplicateContactGroup(
        id: stableOpaqueId(members.map((contact) => contact.nativeId), namespace: 'group'),
        contacts: List<ScannedContact>.unmodifiable(members),
        reasons: Set<DuplicateMatchReason>.unmodifiable(reasons),
        confidenceScore: score.score,
        confidenceLabel: score.label,
        evidence: score.evidence,
        requiresManualReview: score.requiresManualReview,
        canBeMerged: canBeMerged,
        proposedPrimaryContactId: _recommendedPrimary(members)?.nativeId,
        revisionFingerprint: stableOpaqueId(members.map((contact) => contact.record?.revision.fingerprint ?? contact.nativeId), namespace: 'revision'),
      ));
    }

    final membershipCounts = <String, int>{};
    for (final group in groups) {
      for (final contact in group.contacts) membershipCounts.update(contact.nativeId, (value) => value + 1, ifAbsent: () => 1);
    }
    final marked = groups.map((group) => group.copyWith(
      overlapsAnotherGroup: group.contacts.any((contact) => (membershipCounts[contact.nativeId] ?? 0) > 1),
    )).toList(growable: false)
      ..sort((left, right) {
        final scoreCompare = right.confidenceScore.compareTo(left.confidenceScore);
        if (scoreCompare != 0) return scoreCompare;
        final nameCompare = left.contacts.first.displayName.compareTo(right.contacts.first.displayName);
        return nameCompare != 0 ? nameCompare : left.id.compareTo(right.id);
      });
    return List<DuplicateContactGroup>.unmodifiable(marked);
  }

  void _addPairs(Map<String, List<int>> ownersByValue, Map<String, _PairCandidate> candidates, {required int maxOwners}) {
    for (final owners in ownersByValue.values) {
      if (owners.length < 2 || owners.length > maxOwners) continue;
      for (var i = 0; i < owners.length; i++) {
        for (var j = i + 1; j < owners.length; j++) _putPair(candidates, owners[i], owners[j]);
      }
    }
  }

  void _putPair(Map<String, _PairCandidate> candidates, int left, int right) {
    final a = left < right ? left : right;
    final b = left < right ? right : left;
    candidates.putIfAbsent('$a:$b', () => _PairCandidate(a, b));
  }

  ScannedContact? _recommendedPrimary(List<ScannedContact> contacts) {
    if (contacts.isEmpty) return null;
    final sorted = contacts.toList()..sort((left, right) {
      final leftScore = _completeness(left);
      final rightScore = _completeness(right);
      if (leftScore != rightScore) return rightScore.compareTo(leftScore);
      return left.nativeId.compareTo(right.nativeId);
    });
    return sorted.first;
  }

  int _completeness(ScannedContact contact) {
    final record = contact.record;
    return (contact.hasStableNativeId ? 10 : 0) +
        (contact.hasOriginalDisplayName ? 5 : 0) +
        contact.phones.length * 3 +
        contact.emails.length * 3 +
        (record?.addresses.length ?? 0) * 2 +
        (record?.organizations.length ?? 0) * 2 +
        ((record?.capabilities.isFullyWritable ?? false) ? 20 : 0);
  }

  void _progress(void Function(ScanProgress progress)? callback, ScanPhase phase, double ratio, int processed, int total) {
    callback?.call(ScanProgress(phase: phase, ratio: ratio.clamp(0, 1).toDouble(), processed: processed, total: total));
  }
}

class _MappedContact {
  final ScannedContact contact;
  final int ignoredPhones;
  final int ignoredEmails;
  const _MappedContact({required this.contact, required this.ignoredPhones, required this.ignoredEmails});
}

class _PairCandidate {
  final int left;
  final int right;
  const _PairCandidate(this.left, this.right);
}

class _ScanCancelledException implements Exception {
  const _ScanCancelledException();
}
