import 'package:flutter/foundation.dart';

import '../../core/contacts/contact_copy_service.dart';

enum ContactCopyControllerStatus {
  idle,
  creating,
  success,
  permissionDenied,
  failed,
  rollbackFailed,
}

class ContactCopyController extends ChangeNotifier {
  final ContactCopyService _service;

  ContactCopyControllerStatus _status = ContactCopyControllerStatus.idle;
  ContactCopyResult? _result;
  Set<String> _lastSourceContactIds = const <String>{};
  bool _isDisposed = false;

  ContactCopyController(this._service);

  ContactCopyControllerStatus get status => _status;

  ContactCopyResult? get result => _result;

  bool get isBusy => _status == ContactCopyControllerStatus.creating;

  bool matchesSources(Iterable<String> sourceContactIds) {
    final normalized = sourceContactIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    return setEquals(normalized, _lastSourceContactIds);
  }

  Future<ContactCopyResult?> create(ContactCopyDraft draft) async {
    if (isBusy) {
      return null;
    }

    _lastSourceContactIds = draft.sourceContactIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    _status = ContactCopyControllerStatus.creating;
    _result = null;
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

  void reset() {
    if (isBusy ||
        (_status == ContactCopyControllerStatus.idle && _result == null)) {
      return;
    }
    _status = ContactCopyControllerStatus.idle;
    _result = null;
    _lastSourceContactIds = const <String>{};
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
