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
  externalStateUnknown,
}

class ContactCopyController extends ChangeNotifier {
  final ContactCopyService _service;

  ContactCopyControllerStatus _status = ContactCopyControllerStatus.idle;
  ContactCopyResult? _result;
  ContactCopyRemovalResult? _removalResult;
  Set<String> _lastSourceContactIds = const <String>{};
  String? _lastDraftFingerprint;
  int _operationGeneration = 0;
  bool _isDisposed = false;

  ContactCopyController(this._service);

  ContactCopyControllerStatus get status => _status;
  ContactCopyResult? get result => _result;
  ContactCopyRemovalResult? get removalResult => _removalResult;
  String? get createdContactId => _result?.createdContactId?.trim();
  bool get isBusy => _status == ContactCopyControllerStatus.creating || _status == ContactCopyControllerStatus.removing;
  bool get requiresManualReconciliation =>
      _status == ContactCopyControllerStatus.rollbackFailed ||
      _status == ContactCopyControllerStatus.removalFailed ||
      _status == ContactCopyControllerStatus.externalStateUnknown;

  bool matchesSources(Iterable<String> sourceContactIds) {
    final normalized = sourceContactIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    return setEquals(normalized, _lastSourceContactIds);
  }

  bool matchesDraft(ContactCopyDraft draft) {
    return matchesSources(draft.sourceContactIds) && _lastDraftFingerprint == draft.fingerprint;
  }

  Future<ContactCopyResult?> create(ContactCopyDraft draft) async {
    if (isBusy || _mustBlockRepeatedCreate(draft)) return null;
    final generation = ++_operationGeneration;
    _lastSourceContactIds = draft.sourceContactIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    _lastDraftFingerprint = draft.fingerprint;
    _status = ContactCopyControllerStatus.creating;
    _result = null;
    _removalResult = null;
    _notifySafely();

    final ContactCopyResult result;
    try {
      result = await _service.createVerifiedCopy(draft);
    } on Object {
      if (!_isCurrent(generation)) return null;
      _result = const ContactCopyResult(
        status: ContactCopyStatus.createFailed,
        errorCode: 'contact_copy_unexpected_failure',
      );
      _status = ContactCopyControllerStatus.failed;
      _notifySafely();
      return _result;
    }
    if (!_isCurrent(generation)) return null;
    _result = result;
    _status = switch (result.status) {
      ContactCopyStatus.success => ContactCopyControllerStatus.success,
      ContactCopyStatus.permissionDenied => ContactCopyControllerStatus.permissionDenied,
      ContactCopyStatus.rollbackFailed => ContactCopyControllerStatus.rollbackFailed,
      ContactCopyStatus.invalidDraft || ContactCopyStatus.createFailed || ContactCopyStatus.verificationFailed => ContactCopyControllerStatus.failed,
    };
    _notifySafely();
    return result;
  }

  Future<ContactCopyRemovalResult?> removeCurrentCopy(ContactCopyDraft expectedDraft) async {
    final id = createdContactId;
    if (isBusy || _status != ContactCopyControllerStatus.success || !matchesDraft(expectedDraft) || id == null || id.isEmpty) return null;
    final generation = ++_operationGeneration;
    _status = ContactCopyControllerStatus.removing;
    _removalResult = null;
    _notifySafely();

    final ContactCopyRemovalResult result;
    try {
      result = await _service.removeVerifiedCopy(createdContactId: id, expectedDraft: expectedDraft);
    } on Object {
      if (!_isCurrent(generation)) return null;
      _removalResult = const ContactCopyRemovalResult(
        status: ContactCopyRemovalStatus.deleteFailed,
        errorCode: 'contact_copy_removal_unexpected_failure',
      );
      _status = ContactCopyControllerStatus.removalFailed;
      _notifySafely();
      return _removalResult;
    }
    if (!_isCurrent(generation)) return null;
    _removalResult = result;
    _status = switch (result.status) {
      ContactCopyRemovalStatus.success || ContactCopyRemovalStatus.alreadyAbsent => ContactCopyControllerStatus.removed,
      ContactCopyRemovalStatus.permissionDenied => ContactCopyControllerStatus.removalPermissionDenied,
      ContactCopyRemovalStatus.invalidRequest || ContactCopyRemovalStatus.identityMismatch || ContactCopyRemovalStatus.deleteFailed || ContactCopyRemovalStatus.verificationFailed => ContactCopyControllerStatus.removalFailed,
    };
    _notifySafely();
    return result;
  }

  void markExternalStateUnknown() {
    if (isBusy) _operationGeneration++;
    if (_status == ContactCopyControllerStatus.idle || _status == ContactCopyControllerStatus.removed) return;
    _status = ContactCopyControllerStatus.externalStateUnknown;
    _notifySafely();
  }

  void acknowledgeExternalStateAndReset() {
    if (isBusy) return;
    reset(force: true);
  }

  bool _mustBlockRepeatedCreate(ContactCopyDraft draft) {
    if (!matchesDraft(draft)) return false;
    return _status == ContactCopyControllerStatus.success ||
        _status == ContactCopyControllerStatus.rollbackFailed ||
        _status == ContactCopyControllerStatus.removalPermissionDenied ||
        _status == ContactCopyControllerStatus.removalFailed ||
        _status == ContactCopyControllerStatus.externalStateUnknown;
  }

  void reset({bool force = false}) {
    if (isBusy && !force) return;
    if (_status == ContactCopyControllerStatus.idle && _result == null && _removalResult == null) return;
    _operationGeneration++;
    _status = ContactCopyControllerStatus.idle;
    _result = null;
    _removalResult = null;
    _lastSourceContactIds = const <String>{};
    _lastDraftFingerprint = null;
    _notifySafely();
  }

  bool _isCurrent(int generation) => !_isDisposed && generation == _operationGeneration;

  void _notifySafely() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _operationGeneration++;
    super.dispose();
  }
}
