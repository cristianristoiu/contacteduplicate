import 'package:flutter/foundation.dart';

import '../../core/contacts/contact_copy_service.dart';

enum ContactCopyControllerStatus {
  idle,
  creating,
  success,
  permissionDenied,
  failed,
  rollbackFailed,
  removing,
  removed,
  removalPermissionDenied,
  removalFailed,
}

class ContactCopyController extends ChangeNotifier {
  final ContactCopyService _service;

  ContactCopyControllerStatus _status = ContactCopyControllerStatus.idle;
  ContactCopyResult? _result;
  ContactCopyRemovalResult? _removalResult;
  Set<String> _lastSourceContactIds = const <String>{};
  String? _lastDraftFingerprint;
  bool _isDisposed = false;

  ContactCopyController(this._service);

  ContactCopyControllerStatus get status => _status;

  ContactCopyResult? get result => _result;

  ContactCopyRemovalResult? get removalResult => _removalResult;

  bool get isBusy =>
      _status == ContactCopyControllerStatus.creating ||
      _status == ContactCopyControllerStatus.removing;

  bool matchesSources(Iterable<String> sourceContactIds) {
    final normalized = sourceContactIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    return setEquals(normalized, _lastSourceContactIds);
  }

  bool matchesDraft(ContactCopyDraft draft) {
    return matchesSources(draft.sourceContactIds) &&
        _lastDraftFingerprint == draft.fingerprint;
  }

  Future<ContactCopyResult?> create(ContactCopyDraft draft) async {
    if (isBusy || _mustBlockRepeatedCreate(draft)) {
      return null;
    }

    _lastSourceContactIds = draft.sourceContactIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    _lastDraftFingerprint = draft.fingerprint;
    _status = ContactCopyControllerStatus.creating;
    _result = null;
    _removalResult = null;
    _notifySafely();

    final ContactCopyResult result;
    try {
      result = await _service.createVerifiedCopy(draft);
    } on Object {
      _result = const ContactCopyResult(
        status: ContactCopyStatus.createFailed,
        errorCode: 'contact_copy_unexpected_failure',
      );
      _status = ContactCopyControllerStatus.failed;
      _notifySafely();
      return _result;
    }

    _result = result;
    _status = switch (result.status) {
      ContactCopyStatus.success => ContactCopyControllerStatus.success,
      ContactCopyStatus.permissionDenied =>
        ContactCopyControllerStatus.permissionDenied,
      ContactCopyStatus.rollbackFailed =>
        ContactCopyControllerStatus.rollbackFailed,
      ContactCopyStatus.invalidDraft ||
      ContactCopyStatus.createFailed ||
      ContactCopyStatus.verificationFailed => ContactCopyControllerStatus.failed,
    };
    _notifySafely();
    return result;
  }

  Future<ContactCopyRemovalResult?> removeCurrentCopy(
    ContactCopyDraft expectedDraft,
  ) async {
    final createdContactId = _result?.createdContactId?.trim();
    if (isBusy ||
        _status != ContactCopyControllerStatus.success ||
        !matchesDraft(expectedDraft) ||
        createdContactId == null ||
        createdContactId.isEmpty) {
      return null;
    }

    _status = ContactCopyControllerStatus.removing;
    _removalResult = null;
    _notifySafely();

    final ContactCopyRemovalResult result;
    try {
      result = await _service.removeVerifiedCopy(
        createdContactId: createdContactId,
        expectedDraft: expectedDraft,
      );
    } on Object {
      _removalResult = const ContactCopyRemovalResult(
        status: ContactCopyRemovalStatus.deleteFailed,
        errorCode: 'contact_copy_removal_unexpected_failure',
      );
      _status = ContactCopyControllerStatus.removalFailed;
      _notifySafely();
      return _removalResult;
    }

    _removalResult = result;
    _status = switch (result.status) {
      ContactCopyRemovalStatus.success ||
      ContactCopyRemovalStatus.alreadyAbsent =>
        ContactCopyControllerStatus.removed,
      ContactCopyRemovalStatus.permissionDenied =>
        ContactCopyControllerStatus.removalPermissionDenied,
      ContactCopyRemovalStatus.invalidRequest ||
      ContactCopyRemovalStatus.identityMismatch ||
      ContactCopyRemovalStatus.deleteFailed ||
      ContactCopyRemovalStatus.verificationFailed =>
        ContactCopyControllerStatus.removalFailed,
    };
    _notifySafely();
    return result;
  }

  bool _mustBlockRepeatedCreate(ContactCopyDraft draft) {
    if (!matchesDraft(draft)) {
      return false;
    }
    return _status == ContactCopyControllerStatus.success ||
        _status == ContactCopyControllerStatus.rollbackFailed ||
        _status == ContactCopyControllerStatus.removalPermissionDenied ||
        _status == ContactCopyControllerStatus.removalFailed;
  }

  void reset() {
    if (isBusy ||
        (_status == ContactCopyControllerStatus.idle &&
            _result == null &&
            _removalResult == null)) {
      return;
    }
    _status = ContactCopyControllerStatus.idle;
    _result = null;
    _removalResult = null;
    _lastSourceContactIds = const <String>{};
    _lastDraftFingerprint = null;
    _notifySafely();
  }

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
