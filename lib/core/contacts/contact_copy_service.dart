import 'dart:convert';

import 'package:flutter_contacts/flutter_contacts.dart';

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
    return displayName.trim().isNotEmpty &&
        (phones.any((value) => value.trim().isNotEmpty) ||
            emails.any((value) => value.trim().isNotEmpty)) &&
        distinctSourceCount >= 2;
  }

  String get fingerprint {
    final normalizedPhones = phones
        .map(_fingerprintPhone)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final normalizedEmails = emails
        .map((value) => value.trim().toLowerCase())
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
      'displayName': _normalizeName(displayName),
      'phones': normalizedPhones,
      'emails': normalizedEmails,
      'sourceContactIds': normalizedSourceIds,
    });
  }

  static String _fingerprintPhone(String value) {
    var compact = value.replaceAll(RegExp(r'\D'), '');
    if (compact.startsWith('00')) {
      compact = compact.substring(2);
    }
    return compact;
  }

  static String _normalizeName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
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
  final String? _defaultCountryCallingCode;

  NativeContactCopyService({
    ContactCopyPermissionRequester? requestPermission,
    ContactCreator? createContact,
    ContactReader? readContact,
    ContactDeleter? deleteContact,
    String? defaultCountryCallingCode = '40',
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
        _defaultCountryCallingCode =
            _sanitizeCountryCallingCode(defaultCountryCallingCode);

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
      createdContactId = await _createContact(contact);
      if (createdContactId.trim().isEmpty) {
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
    } on Exception {
      if (createdContactId == null || createdContactId.trim().isEmpty) {
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
      if (!_matchesDraft(existing, normalizedDraft)) {
        return const ContactCopyRemovalResult(
          status: ContactCopyRemovalStatus.identityMismatch,
          errorCode: 'contact_copy_identity_mismatch',
        );
      }

      await _deleteContact(id);
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
    } on Exception {
      return const ContactCopyRemovalResult(
        status: ContactCopyRemovalStatus.deleteFailed,
        errorCode: 'contact_copy_removal_failed',
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
      return ContactCopyResult(
        status: failureStatus,
        errorCode: failureCode,
      );
    } on Exception {
      return ContactCopyResult(
        status: ContactCopyStatus.rollbackFailed,
        createdContactId: createdContactId,
        errorCode: 'contact_copy_rollback_failed',
      );
    }
  }

  ContactCopyDraft _normalizeDraft(ContactCopyDraft draft) {
    final phones = <String, String>{};
    for (final rawValue in draft.phones) {
      final value = rawValue.trim();
      final key = _normalizePhone(value);
      if (key.isNotEmpty) {
        phones.putIfAbsent(key, () => value);
      }
    }

    final emails = <String, String>{};
    for (final rawValue in draft.emails) {
      final value = rawValue.trim();
      final key = _normalizeEmail(value);
      if (key.isNotEmpty) {
        emails.putIfAbsent(key, () => value);
      }
    }

    final sourceIds = draft.sourceContactIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    return ContactCopyDraft(
      displayName: draft.displayName.trim().replaceAll(RegExp(r'\s+'), ' '),
      phones: phones.values.toList(growable: false),
      emails: emails.values.toList(growable: false),
      sourceContactIds: sourceIds,
    );
  }

  bool _matchesDraft(Contact contact, ContactCopyDraft draft) {
    final expectedName = _normalizeName(draft.displayName);
    final displayName = contact.displayName;
    final firstName = contact.name?.first;
    final actualNames = <String>{
      if (displayName != null) _normalizeName(displayName),
      if (firstName != null) _normalizeName(firstName),
    }..removeWhere((value) => value.isEmpty);
    if (!actualNames.contains(expectedName)) {
      return false;
    }

    final expectedPhones = draft.phones.map(_normalizePhone).toSet();
    final actualPhones = contact.phones
        .map((phone) => _normalizePhone(phone.number))
        .where((phone) => phone.isNotEmpty)
        .toSet();
    if (!actualPhones.containsAll(expectedPhones)) {
      return false;
    }

    final expectedEmails = draft.emails.map(_normalizeEmail).toSet();
    final actualEmails = contact.emails
        .map((email) => _normalizeEmail(email.address))
        .where((email) => email.isNotEmpty)
        .toSet();
    return actualEmails.containsAll(expectedEmails);
  }

  String _normalizeName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  String _normalizePhone(String value) {
    final compact = value.replaceAll(RegExp(r'[^0-9+]'), '');
    if (compact.isEmpty) {
      return '';
    }

    var normalized = compact;
    if (normalized.startsWith('00')) {
      normalized = '+${normalized.substring(2)}';
    }

    final plusCount = '+'.allMatches(normalized).length;
    if (plusCount > 1 ||
        (normalized.contains('+') && !normalized.startsWith('+'))) {
      return '';
    }

    final digits = normalized.replaceAll('+', '');
    if (digits.length < 7) {
      return '';
    }

    if (normalized.startsWith('0') &&
        _defaultCountryCallingCode != null &&
        normalized.length >= 9) {
      return '+$_defaultCountryCallingCode${normalized.substring(1)}';
    }
    return normalized;
  }

  String _normalizeEmail(String value) {
    final normalized = value.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+$').hasMatch(normalized)) {
      return '';
    }
    return normalized;
  }

  static String? _sanitizeCountryCallingCode(String? value) {
    if (value == null) {
      return null;
    }
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : digits;
  }
}
