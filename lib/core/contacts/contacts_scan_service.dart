import 'dart:convert';

import 'package:flutter_contacts/flutter_contacts.dart';

import 'contact_data_normalizer.dart';

enum ContactsPermissionState {
  granted,
  limited,
  denied,
  permanentlyDenied,
  restricted,
  notDetermined,
  failure,
}

enum DuplicateMatchReason {
  phone,
  email,
}

class ScannedContact {
  final String nativeId;
  final String displayName;
  final List<String> phones;
  final List<String> emails;
  final bool hasStableNativeId;
  final bool hasOriginalDisplayName;

  const ScannedContact({
    required this.nativeId,
    required this.displayName,
    required this.phones,
    required this.emails,
    this.hasStableNativeId = true,
    this.hasOriginalDisplayName = true,
  });
}

class DuplicateContactGroup {
  final String id;
  final List<ScannedContact> contacts;
  final Set<DuplicateMatchReason> reasons;
  final int confidenceScore;

  const DuplicateContactGroup({
    required this.id,
    required this.contacts,
    required this.reasons,
    required this.confidenceScore,
  })  : assert(contacts.length >= 2),
        assert(confidenceScore >= 0 && confidenceScore <= 100);
}

class ContactsScanResult {
  final ContactsPermissionState permissionState;
  final int totalContacts;
  final List<DuplicateContactGroup> duplicateGroups;
  final String? errorCode;

  const ContactsScanResult({
    required this.permissionState,
    required this.totalContacts,
    required this.duplicateGroups,
    this.errorCode,
  });

  const ContactsScanResult.permissionDenied(
    ContactsPermissionState state,
  ) : this(
          permissionState: state,
          totalContacts: 0,
          duplicateGroups: const <DuplicateContactGroup>[],
        );

  const ContactsScanResult.failure(String code)
      : this(
          permissionState: ContactsPermissionState.failure,
          totalContacts: 0,
          duplicateGroups: const <DuplicateContactGroup>[],
          errorCode: code,
        );

  bool get canReadContacts =>
      permissionState == ContactsPermissionState.granted ||
      permissionState == ContactsPermissionState.limited;
}

abstract interface class ContactsScanService {
  Future<ContactsScanResult> scan();

  Future<void> openAppSettings();
}

typedef ContactsPermissionRequester = Future<PermissionStatus> Function();
typedef NativeContactsReader = Future<List<Contact>> Function();
typedef AppSettingsOpener = Future<void> Function();

class NativeContactsScanService implements ContactsScanService {
  final ContactsPermissionRequester _requestPermission;
  final NativeContactsReader _readContacts;
  final AppSettingsOpener _openSettings;
  final ContactDataNormalizer _normalizer;

  NativeContactsScanService({
    ContactsPermissionRequester? requestPermission,
    NativeContactsReader? readContacts,
    AppSettingsOpener? openSettings,
    String? defaultCountryCallingCode = '40',
    ContactDataNormalizer? normalizer,
  })  : _requestPermission = requestPermission ??
            (() => FlutterContacts.permissions.request(PermissionType.read)),
        _readContacts = readContacts ??
            (() => FlutterContacts.getAll(
                  properties: const <ContactProperty>{
                    ContactProperty.name,
                    ContactProperty.phone,
                    ContactProperty.email,
                  },
                )),
        _openSettings = openSettings ??
            (() async {
              await FlutterContacts.permissions.openSettings();
            }),
        _normalizer = normalizer ??
            ContactDataNormalizer(
              defaultCountryCallingCode: defaultCountryCallingCode,
            );

  @override
  Future<ContactsScanResult> scan() async {
    try {
      final permission = await _requestPermission();
      final permissionState = _mapPermission(permission);
      if (permissionState != ContactsPermissionState.granted &&
          permissionState != ContactsPermissionState.limited) {
        return ContactsScanResult.permissionDenied(permissionState);
      }

      final nativeContacts = await _readContacts();
      final contacts = nativeContacts
          .asMap()
          .entries
          .map(_mapContact)
          .toList(growable: false);
      final groups = _findExactDuplicates(contacts);

      return ContactsScanResult(
        permissionState: permissionState,
        totalContacts: contacts.length,
        duplicateGroups: groups,
      );
    } on Object {
      return const ContactsScanResult.failure('contacts_scan_failed');
    }
  }

  @override
  Future<void> openAppSettings() {
    return _openSettings();
  }

  ContactsPermissionState _mapPermission(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return ContactsPermissionState.granted;
      case PermissionStatus.limited:
        return ContactsPermissionState.limited;
      case PermissionStatus.denied:
        return ContactsPermissionState.denied;
      case PermissionStatus.permanentlyDenied:
        return ContactsPermissionState.permanentlyDenied;
      case PermissionStatus.restricted:
        return ContactsPermissionState.restricted;
      case PermissionStatus.notDetermined:
        return ContactsPermissionState.notDetermined;
    }
  }

  ScannedContact _mapContact(MapEntry<int, Contact> entry) {
    final contact = entry.value;
    final rawId = contact.id?.trim() ?? '';
    final hasStableNativeId = rawId.isNotEmpty;
    final rawDisplayName = contact.displayName ?? '';
    final normalizedDisplayName =
        _normalizer.normalizeDisplayName(rawDisplayName);
    final hasOriginalDisplayName = normalizedDisplayName.isNotEmpty;

    final phoneKeys = <String>{};
    for (final phone in contact.phones) {
      final key = _normalizer.normalizePhone(phone.number);
      if (key.isNotEmpty) {
        phoneKeys.add(key);
      }
    }
    final phones = phoneKeys.toList()..sort();

    final emailKeys = <String>{};
    for (final email in contact.emails) {
      final key = _normalizer.normalizeEmail(email.address);
      if (key.isNotEmpty) {
        emailKeys.add(key);
      }
    }
    final emails = emailKeys.toList()..sort();

    return ScannedContact(
      nativeId:
          hasStableNativeId ? rawId : 'temporary-contact-${entry.key}',
      displayName: hasOriginalDisplayName
          ? normalizedDisplayName
          : 'Contact fara nume',
      phones: List<String>.unmodifiable(phones),
      emails: List<String>.unmodifiable(emails),
      hasStableNativeId: hasStableNativeId,
      hasOriginalDisplayName: hasOriginalDisplayName,
    );
  }

  List<DuplicateContactGroup> _findExactDuplicates(
    List<ScannedContact> contacts,
  ) {
    if (contacts.length < 2) {
      return const <DuplicateContactGroup>[];
    }

    final phoneOwners = <String, Set<int>>{};
    final emailOwners = <String, Set<int>>{};

    for (var index = 0; index < contacts.length; index++) {
      final contact = contacts[index];

      for (final phone in contact.phones) {
        phoneOwners.putIfAbsent(phone, () => <int>{}).add(index);
      }

      for (final email in contact.emails) {
        emailOwners.putIfAbsent(email, () => <int>{}).add(index);
      }
    }

    final candidates = <String, _DuplicateCandidate>{};
    _collectCandidates(
      ownersByValue: phoneOwners,
      reason: DuplicateMatchReason.phone,
      candidates: candidates,
    );
    _collectCandidates(
      ownersByValue: emailOwners,
      reason: DuplicateMatchReason.email,
      candidates: candidates,
    );

    final groups = candidates.values.map((candidate) {
      final members = candidate.contactIndices
          .map((index) => contacts[index])
          .toList(growable: false)
        ..sort((left, right) {
          final nameComparison = _normalizer
              .canonicalName(left.displayName)
              .compareTo(_normalizer.canonicalName(right.displayName));
          if (nameComparison != 0) {
            return nameComparison;
          }
          return left.nativeId.compareTo(right.nativeId);
        });
      final sortedIds = members.map((contact) => contact.nativeId).toList()
        ..sort();

      return DuplicateContactGroup(
        id: jsonEncode(sortedIds),
        contacts: List<ScannedContact>.unmodifiable(members),
        reasons: Set<DuplicateMatchReason>.unmodifiable(candidate.reasons),
        confidenceScore: _confidenceFor(candidate.reasons),
      );
    }).toList(growable: false)
      ..sort((left, right) {
        final scoreComparison =
            right.confidenceScore.compareTo(left.confidenceScore);
        if (scoreComparison != 0) {
          return scoreComparison;
        }
        final sizeComparison =
            right.contacts.length.compareTo(left.contacts.length);
        if (sizeComparison != 0) {
          return sizeComparison;
        }
        return left.id.compareTo(right.id);
      });

    return List<DuplicateContactGroup>.unmodifiable(groups);
  }

  void _collectCandidates({
    required Map<String, Set<int>> ownersByValue,
    required DuplicateMatchReason reason,
    required Map<String, _DuplicateCandidate> candidates,
  }) {
    for (final owners in ownersByValue.values) {
      if (owners.length < 2) {
        continue;
      }

      final indices = owners.toList()..sort();
      final membershipKey = indices.join(',');
      final candidate = candidates.putIfAbsent(
        membershipKey,
        () => _DuplicateCandidate(indices),
      );
      candidate.reasons.add(reason);
    }
  }

  int _confidenceFor(Set<DuplicateMatchReason> reasons) {
    return reasons.length >= 2 ? 100 : 95;
  }
}

class _DuplicateCandidate {
  final List<int> contactIndices;
  final Set<DuplicateMatchReason> reasons = <DuplicateMatchReason>{};

  _DuplicateCandidate(List<int> contactIndices)
      : contactIndices = List<int>.unmodifiable(contactIndices);
}
