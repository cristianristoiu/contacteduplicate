import 'dart:convert';

import 'package:flutter_contacts/flutter_contacts.dart';

import 'contact_data_normalizer.dart';

enum ContactCopyStatus {
  success,
  permissionDenied,
  invalidDraft,
  createFailed,
  verificationFailed,
  rollbackFailed,
}

enum ContactCopyRemovalStatus {
  success,
  alreadyAbsent,
  permissionDenied,
  invalidRequest,
  identityMismatch,
  deleteFailed,
  verificationFailed,
}

class ContactCopyDraft {
  static final ContactDataNormalizer _fingerprintNormalizer =
      ContactDataNormalizer();

  final String displayName;
  final List<String> phones;
  final List<String> emails;
  final List<String> sourceContactIds;

  const ContactCopyDraft({
    required this.displayName,
    required this.phones,
    required this.emails,
    required this.sourceContactIds,
  });

  bool get isValid {
    final distinctSourceCount = sourceContactIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;
    final normalizedPhones = phones
        .map(_fingerprintNormalizer.normalizePhone)
        .where((value) => value.isNotEmpty);
    final normalizedEmails = emails
        .map(_fingerprintNormalizer.normalizeEmail)
        .where((value) => value.isNotEmpty);
    return _fingerprintNormalizer
            .normalizeDisplayName(displayName)
            .isNotEmpty &&
        (normalizedPhones.isNotEmpty || normalizedEmails.isNotEmpty) &&
        distinctSourceCount >= 2;
  }

  String get fingerprint {
    final normalizedPhones = phones
        .map(_fingerprintNormalizer.normalizePhone)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final normalizedEmails = emails
        .map(_fingerprintNormalizer.normalizeEmail)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final normalizedSourceIds = sourceContactIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return jsonEncode(<String, Object>{
      'displayName': _fingerprintNormalizer.normalizeDisplayName(displayName),
      'phones': normalizedPhones,
      'emails': normalizedEmails,
      'sourceContactIds': normalizedSourceIds,
    });
  }
}

class ContactCopyResult {
  final ContactCopyStatus status;
  final String? createdContactId;
  final String? errorCode;

  const ContactCopyResult({
    required this.status,
    this.createdContactId,
    this.errorCode,
  });

  bool get isSuccess => status == ContactCopyStatus.success;
}

class ContactCopyRemovalResult {
  final ContactCopyRemovalStatus status;
  final String? errorCode;

  const ContactCopyRemovalResult({
    required this.status,
    this.errorCode,
  });

  bool get isSuccess =>
      status == ContactCopyRemovalStatus.success ||
      status == ContactCopyRemovalStatus.alreadyAbsent;
}

abstract interface class ContactCopyService {
  Future<ContactCopyResult> createVerifiedCopy(ContactCopyDraft draft);

  Future<ContactCopyRemovalResult> removeVerifiedCopy({
    required String createdContactId,
    required ContactCopyDraft expectedDraft,
  });
}

typedef ContactCopyPermissionRequester = Future<PermissionStatus> Function();
typedef ContactCreator = Future<String> Function(Contact contact);
typedef ContactReader = Future<Contact?> Function(String id);
typedef ContactDeleter = Future<void> Function(String id);

class NativeContactCopyService implements ContactCopyService {
  final ContactCopyPermissionRequester _requestPermission;
  final ContactCreator _createContact;
  final ContactReader _readContact;
  final ContactDeleter _deleteContact;
  final ContactDataNormalizer _normalizer;

  NativeContactCopyService({
    ContactCopyPermissionRequester? requestPermission,
    ContactCreator? createContact,
    ContactReader? readContact,
    ContactDeleter? deleteContact,
    String? defaultCountryCallingCode = '40',
    ContactDataNormalizer? normalizer,
  })  : _requestPermission = requestPermission ??
            (() => FlutterContacts.permissions.request(
                  PermissionType.readWrite,
                )),
        _createContact = createContact ?? FlutterContacts.create,
        _readContact = readContact ??
            ((id) => FlutterContacts.get(
                  id,
                  properties: const <ContactProperty>{
                    ContactProperty.name,
                    ContactProperty.phone,
                    ContactProperty.email,
                  },
                )),
        _deleteContact = deleteContact ?? FlutterContacts.delete,
        _normalizer = normalizer ??
            ContactDataNormalizer(
              defaultCountryCallingCode: defaultCountryCallingCode,
            );

  @override
  Future<ContactCopyResult> createVerifiedCopy(ContactCopyDraft draft) async {
    final normalizedDraft = _normalizeDraft(draft);
    if (!normalizedDraft.isValid) {
      return const ContactCopyResult(
        status: ContactCopyStatus.invalidDraft,
        errorCode: 'contact_copy_invalid_draft',
      );
    }

    String? createdContactId;
    try {
      final permission = await _requestPermission();
      if (!_canWrite(permission)) {
        return const ContactCopyResult(
          status: ContactCopyStatus.permissionDenied,
          errorCode: 'contacts_write_permission_denied',
        );
      }

      final contact = Contact(
        name: Name(first: normalizedDraft.displayName),
        phones: normalizedDraft.phones
            .map((value) => Phone(number: value))
            .toList(growable: false),
        emails: normalizedDraft.emails
            .map((value) => Email(address: value))
            .toList(growable: false),
      );
      createdContactId = (await _createContact(contact)).trim();
      if (createdContactId.isEmpty) {
        return const ContactCopyResult(
          status: ContactCopyStatus.createFailed,
          errorCode: 'contact_copy_empty_id',
        );
      }

      final createdContact = await _readContact(createdContactId);
      if (createdContact != null &&
          _matchesDraft(createdContact, normalizedDraft)) {
        return ContactCopyResult(
          status: ContactCopyStatus.success,
          createdContactId: createdContactId,
        );
      }

      return await _rollback(
        createdContactId,
        ContactCopyStatus.verificationFailed,
        'contact_copy_verification_failed',
      );
    } on Object {
      if (createdContactId == null || createdContactId.isEmpty) {
        return const ContactCopyResult(
          status: ContactCopyStatus.createFailed,
          errorCode: 'contact_copy_create_failed',
        );
      }

      return _rollback(
        createdContactId,
        ContactCopyStatus.verificationFailed,
        'contact_copy_verification_failed',
      );
    }
  }

  @override
  Future<ContactCopyRemovalResult> removeVerifiedCopy({
    required String createdContactId,
    required ContactCopyDraft expectedDraft,
  }) async {
    final id = createdContactId.trim();
    final normalizedDraft = _normalizeDraft(expectedDraft);
    if (id.isEmpty || !normalizedDraft.isValid) {
      return const ContactCopyRemovalResult(
        status: ContactCopyRemovalStatus.invalidRequest,
        errorCode: 'contact_copy_removal_invalid_request',
      );
    }

    try {
      final permission = await _requestPermission();
      if (!_canWrite(permission)) {
        return const ContactCopyRemovalResult(
          status: ContactCopyRemovalStatus.permissionDenied,
          errorCode: 'contacts_write_permission_denied',
        );
      }

      final existing = await _readContact(id);
      if (existing == null) {
        return const ContactCopyRemovalResult(
          status: ContactCopyRemovalStatus.alreadyAbsent,
        );
      }
      if (!_matchesDraft(
        existing,
        normalizedDraft,
        requireExactValues: true,
      )) {
        return const ContactCopyRemovalResult(
          status: ContactCopyRemovalStatus.identityMismatch,
          errorCode: 'contact_copy_identity_mismatch',
        );
      }
    } on Object {
      return const ContactCopyRemovalResult(
        status: ContactCopyRemovalStatus.verificationFailed,
        errorCode: 'contact_copy_removal_precheck_failed',
      );
    }

    try {
      await _deleteContact(id);
    } on Object {
      return const ContactCopyRemovalResult(
        status: ContactCopyRemovalStatus.deleteFailed,
        errorCode: 'contact_copy_removal_failed',
      );
    }

    try {
      final remaining = await _readContact(id);
      if (remaining == null) {
        return const ContactCopyRemovalResult(
          status: ContactCopyRemovalStatus.success,
        );
      }
      return const ContactCopyRemovalResult(
        status: ContactCopyRemovalStatus.verificationFailed,
        errorCode: 'contact_copy_removal_verification_failed',
      );
    } on Object {
      return const ContactCopyRemovalResult(
        status: ContactCopyRemovalStatus.verificationFailed,
        errorCode: 'contact_copy_removal_verification_failed',
      );
    }
  }

  bool _canWrite(PermissionStatus permission) {
    return permission == PermissionStatus.granted ||
        permission == PermissionStatus.limited;
  }

  Future<ContactCopyResult> _rollback(
    String createdContactId,
    ContactCopyStatus failureStatus,
    String failureCode,
  ) async {
    try {
      await _deleteContact(createdContactId);
    } on Object {
      return ContactCopyResult(
        status: ContactCopyStatus.rollbackFailed,
        createdContactId: createdContactId,
        errorCode: 'contact_copy_rollback_failed',
      );
    }

    try {
      final remaining = await _readContact(createdContactId);
      if (remaining == null) {
        return ContactCopyResult(
          status: failureStatus,
          errorCode: failureCode,
        );
      }
    } on Object {
      // Fara recitire nu putem afirma ca rollbackul a reusit.
    }

    return ContactCopyResult(
      status: ContactCopyStatus.rollbackFailed,
      createdContactId: createdContactId,
      errorCode: 'contact_copy_rollback_failed',
    );
  }

  ContactCopyDraft _normalizeDraft(ContactCopyDraft draft) {
    final phones = draft.phones
        .map(_normalizer.normalizePhone)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final emails = draft.emails
        .map(_normalizer.normalizeEmail)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final sourceIds = draft.sourceContactIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return ContactCopyDraft(
      displayName: _normalizer.normalizeDisplayName(draft.displayName),
      phones: List<String>.unmodifiable(phones),
      emails: List<String>.unmodifiable(emails),
      sourceContactIds: List<String>.unmodifiable(sourceIds),
    );
  }

  bool _matchesDraft(
    Contact contact,
    ContactCopyDraft draft, {
    bool requireExactValues = false,
  }) {
    final expectedName = _normalizer.canonicalName(draft.displayName);
    final displayName = contact.displayName;
    final firstName = contact.name?.first;
    final actualNames = <String>{
      if (displayName != null) _normalizer.canonicalName(displayName),
      if (firstName != null) _normalizer.canonicalName(firstName),
    }..removeWhere((value) => value.isEmpty);
    if (!actualNames.contains(expectedName)) {
      return false;
    }

    final expectedPhones = draft.phones
        .map(_normalizer.normalizePhone)
        .where((value) => value.isNotEmpty)
        .toSet();
    final actualPhones = contact.phones
        .map((phone) => _normalizer.normalizePhone(phone.number))
        .where((phone) => phone.isNotEmpty)
        .toSet();
    if (!_valuesMatch(
      expectedPhones,
      actualPhones,
      requireExactValues: requireExactValues,
    )) {
      return false;
    }

    final expectedEmails = draft.emails
        .map(_normalizer.normalizeEmail)
        .where((value) => value.isNotEmpty)
        .toSet();
    final actualEmails = contact.emails
        .map((email) => _normalizer.normalizeEmail(email.address))
        .where((email) => email.isNotEmpty)
        .toSet();
    return _valuesMatch(
      expectedEmails,
      actualEmails,
      requireExactValues: requireExactValues,
    );
  }

  bool _valuesMatch(
    Set<String> expected,
    Set<String> actual, {
    required bool requireExactValues,
  }) {
    return actual.containsAll(expected) &&
        (!requireExactValues || actual.length == expected.length);
  }
}
