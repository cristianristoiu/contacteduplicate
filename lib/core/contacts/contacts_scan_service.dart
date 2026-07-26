import 'package:flutter_contacts/flutter_contacts.dart';

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

  const ScannedContact({
    required this.nativeId,
    required this.displayName,
    required this.phones,
    required this.emails,
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
  }) : assert(contacts.length >= 2),
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

  NativeContactsScanService({
    ContactsPermissionRequester? requestPermission,
    NativeContactsReader? readContacts,
    AppSettingsOpener? openSettings,
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
            });

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
    } on Exception {
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
    final displayName = contact.displayName?.trim();

    return ScannedContact(
      nativeId: contact.id ?? 'contact-${entry.key}',
      displayName: displayName == null || displayName.isEmpty
          ? 'Contact fara nume'
          : displayName,
      phones: contact.phones
          .map((phone) => phone.number.trim())
          .where((phone) => phone.isNotEmpty)
          .toSet()
          .toList(growable: false),
      emails: contact.emails
          .map((email) => email.address.trim())
          .where((email) => email.isNotEmpty)
          .toSet()
          .toList(growable: false),
    );
  }

  List<DuplicateContactGroup> _findExactDuplicates(
    List<ScannedContact> contacts,
  ) {
    if (contacts.length < 2) {
      return const <DuplicateContactGroup>[];
    }

    final disjointSet = _DisjointSet(contacts.length);
    final phoneOwners = <String, int>{};
    final emailOwners = <String, int>{};

    for (var index = 0; index < contacts.length; index++) {
      final contact = contacts[index];
      for (final phone in contact.phones) {
        final normalized = _normalizePhone(phone);
        if (normalized.isEmpty) {
          continue;
        }
        final owner = phoneOwners[normalized];
        if (owner == null) {
          phoneOwners[normalized] = index;
        } else {
          disjointSet.union(owner, index);
        }
      }

      for (final email in contact.emails) {
        final normalized = _normalizeEmail(email);
        if (normalized.isEmpty) {
          continue;
        }
        final owner = emailOwners[normalized];
        if (owner == null) {
          emailOwners[normalized] = index;
        } else {
          disjointSet.union(owner, index);
        }
      }
    }

    final membersByRoot = <int, List<int>>{};
    for (var index = 0; index < contacts.length; index++) {
      final root = disjointSet.find(index);
      membersByRoot.putIfAbsent(root, () => <int>[]).add(index);
    }

    final groups = <DuplicateContactGroup>[];
    for (final indices in membersByRoot.values) {
      if (indices.length < 2) {
        continue;
      }

      final members = indices
          .map((index) => contacts[index])
          .toList(growable: false);
      final reasons = _resolveReasons(members);
      if (reasons.isEmpty) {
        continue;
      }

      final sortedIds = members.map((contact) => contact.nativeId).toList()
        ..sort();
      groups.add(
        DuplicateContactGroup(
          id: sortedIds.join('|'),
          contacts: members,
          reasons: reasons,
          confidenceScore: _confidenceFor(reasons),
        ),
      );
    }

    groups.sort(
      (left, right) => right.confidenceScore.compareTo(left.confidenceScore),
    );
    return List<DuplicateContactGroup>.unmodifiable(groups);
  }

  Set<DuplicateMatchReason> _resolveReasons(
    List<ScannedContact> contacts,
  ) {
    final phoneCounts = <String, int>{};
    final emailCounts = <String, int>{};

    for (final contact in contacts) {
      for (final phone in contact.phones.map(_normalizePhone).toSet()) {
        if (phone.isNotEmpty) {
          phoneCounts.update(phone, (count) => count + 1, ifAbsent: () => 1);
        }
      }
      for (final email in contact.emails.map(_normalizeEmail).toSet()) {
        if (email.isNotEmpty) {
          emailCounts.update(email, (count) => count + 1, ifAbsent: () => 1);
        }
      }
    }

    return <DuplicateMatchReason>{
      if (phoneCounts.values.any((count) => count >= 2))
        DuplicateMatchReason.phone,
      if (emailCounts.values.any((count) => count >= 2))
        DuplicateMatchReason.email,
    };
  }

  int _confidenceFor(Set<DuplicateMatchReason> reasons) {
    if (reasons.length >= 2) {
      return 100;
    }
    if (reasons.contains(DuplicateMatchReason.phone)) {
      return 98;
    }
    return 97;
  }

  String _normalizePhone(String value) {
    var normalized = value.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.startsWith('00')) {
      normalized = '+${normalized.substring(2)}';
    }
    if (normalized.startsWith('0') && normalized.length >= 9) {
      normalized = '+40${normalized.substring(1)}';
    }
    return normalized;
  }

  String _normalizeEmail(String value) {
    return value.trim().toLowerCase();
  }
}

class _DisjointSet {
  final List<int> _parent;
  final List<int> _rank;

  _DisjointSet(int size)
      : _parent = List<int>.generate(size, (index) => index),
        _rank = List<int>.filled(size, 0);

  int find(int value) {
    final parent = _parent[value];
    if (parent != value) {
      _parent[value] = find(parent);
    }
    return _parent[value];
  }

  void union(int left, int right) {
    final leftRoot = find(left);
    final rightRoot = find(right);
    if (leftRoot == rightRoot) {
      return;
    }

    if (_rank[leftRoot] < _rank[rightRoot]) {
      _parent[leftRoot] = rightRoot;
    } else if (_rank[leftRoot] > _rank[rightRoot]) {
      _parent[rightRoot] = leftRoot;
    } else {
      _parent[rightRoot] = leftRoot;
      _rank[leftRoot]++;
    }
  }
}
