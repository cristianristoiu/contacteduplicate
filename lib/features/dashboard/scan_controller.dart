import 'package:flutter/foundation.dart';

import '../../core/contacts/contacts_scan_service.dart';

enum ScanStatus {
  idle,
  scanning,
  completed,
  permissionDenied,
  error,
}

class ScanController extends ChangeNotifier {
  final ContactsScanService _service;

  ScanStatus _status = ScanStatus.idle;
  ContactsScanResult? _result;
  bool _isDisposed = false;

  ScanController(this._service);

  ScanStatus get status => _status;

  ContactsScanResult? get result => _result;

  bool get isScanning => _status == ScanStatus.scanning;

  int get totalContacts => _result?.totalContacts ?? 0;

  int get duplicateGroupCount => _result?.duplicateGroups.length ?? 0;

  int get duplicateContactCount => _result?.duplicateGroups.fold<int>(
        0,
        (total, group) => total + group.contacts.length,
      ) ??
      0;

  Future<void> scan() async {
    if (isScanning) {
      return;
    }

    _status = ScanStatus.scanning;
    _notifySafely();

    final result = await _service.scan();
    if (_isDisposed) {
      return;
    }

    _result = result;
    if (result.canReadContacts) {
      _status = ScanStatus.completed;
    } else if (result.permissionState == ContactsPermissionState.failure) {
      _status = ScanStatus.error;
    } else {
      _status = ScanStatus.permissionDenied;
    }
    _notifySafely();
  }

  Future<void> openAppSettings() {
    return _service.openAppSettings();
  }

  void reset() {
    if (isScanning) {
      return;
    }

    _status = ScanStatus.idle;
    _result = null;
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
