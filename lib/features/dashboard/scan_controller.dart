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
  bool _settingsOpenFailed = false;
  bool _resultsStale = false;
  int _scanRevision = 0;
  bool _isDisposed = false;

  ScanController(this._service);

  ScanStatus get status => _status;

  ContactsScanResult? get result => _result;

  bool get isScanning => _status == ScanStatus.scanning;

  bool get settingsOpenFailed => _settingsOpenFailed;

  bool get resultsStale => _resultsStale;

  int get scanRevision => _scanRevision;

  int get totalContacts => _result?.totalContacts ?? 0;

  int get duplicateGroupCount => _result?.duplicateGroups.length ?? 0;

  int get duplicateContactCount {
    final groups = _result?.duplicateGroups;
    if (groups == null || groups.isEmpty) {
      return 0;
    }

    return groups
        .expand((group) => group.contacts)
        .map((contact) => contact.nativeId)
        .toSet()
        .length;
  }

  Future<void> scan() async {
    if (isScanning) {
      return;
    }

    _settingsOpenFailed = false;
    _status = ScanStatus.scanning;
    _notifySafely();

    final result = await _service.scan();
    if (_isDisposed) {
      return;
    }

    _result = result;
    _resultsStale = false;
    _scanRevision++;
    if (result.canReadContacts) {
      _status = ScanStatus.completed;
    } else if (result.permissionState == ContactsPermissionState.failure) {
      _status = ScanStatus.error;
    } else {
      _status = ScanStatus.permissionDenied;
    }
    _notifySafely();
  }

  void markResultsStale() {
    if (_result == null || _resultsStale) {
      return;
    }

    _resultsStale = true;
    _notifySafely();
  }

  Future<void> openAppSettings() async {
    _settingsOpenFailed = false;
    try {
      await _service.openAppSettings();
    } on Exception {
      if (_isDisposed) {
        return;
      }
      _settingsOpenFailed = true;
      _notifySafely();
    }
  }

  void reset() {
    if (isScanning) {
      return;
    }

    _status = ScanStatus.idle;
    _result = null;
    _settingsOpenFailed = false;
    _resultsStale = false;
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
