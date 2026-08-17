import 'package:flutter/foundation.dart';

import '../../core/contacts/contacts_scan_service.dart';

enum ScanStatus {
  idle,
  scanning,
  completed,
  permissionDenied,
  cancelled,
  error,
}

class ScanController extends ChangeNotifier {
  final ContactsScanService _service;

  ScanStatus _status = ScanStatus.idle;
  ContactsScanResult? _result;
  ScanProgress? _progress;
  String? _errorCode;
  String? _settingsErrorCode;
  bool _resultsStale = false;
  int _scanRevision = 0;
  int _operationGeneration = 0;
  bool _isDisposed = false;
  ScanCancellationToken? _activeCancellation;

  ScanController(this._service);

  ScanStatus get status => _status;
  ContactsScanResult? get result => _result;
  ScanProgress? get progress => _progress;
  String? get errorCode => _errorCode;
  String? get settingsErrorCode => _settingsErrorCode;
  bool get isScanning => _status == ScanStatus.scanning;
  bool get settingsOpenFailed => _settingsErrorCode != null;
  bool get resultsStale => _resultsStale;
  int get scanRevision => _scanRevision;
  int get totalContacts => _result?.totalContacts ?? 0;
  int get duplicateGroupCount => _result?.duplicateGroups.length ?? 0;
  DateTime? get scannedAt => _result?.scannedAt;
  ScanAccessScope get accessScope => _result?.accessScope ?? ScanAccessScope.unknown;
  bool get hasCurrentResults => _status == ScanStatus.completed && !_resultsStale;
  bool get hasLimitedResults => hasCurrentResults && accessScope == ScanAccessScope.limited;

  int get duplicateContactCount {
    final groups = _result?.duplicateGroups;
    if (groups == null || groups.isEmpty) return 0;
    return groups.expand((group) => group.contacts).map((contact) => contact.nativeId).toSet().length;
  }

  int get mergeableGroupCount {
    final groups = _result?.duplicateGroups;
    if (groups == null) return 0;
    return groups.where((group) => group.canBeMerged && !group.overlapsAnotherGroup).length;
  }

  Future<void> scan() async {
    if (isScanning) return;
    final generation = ++_operationGeneration;
    final token = ScanCancellationToken();
    _activeCancellation = token;
    _settingsErrorCode = null;
    _errorCode = null;
    _progress = const ScanProgress(
      phase: ScanPhase.requestingPermission,
      ratio: 0,
      processed: 0,
      total: 0,
    );
    _status = ScanStatus.scanning;
    _notifySafely();

    ContactsScanResult result;
    try {
      result = await _service.scan(
        cancellationToken: token,
        onProgress: (progress) {
          if (_isDisposed || generation != _operationGeneration) return;
          _progress = progress;
          _notifySafely();
        },
      );
    } on Object {
      result = const ContactsScanResult.failure('contacts_scan_unexpected_failure');
    }
    if (_isDisposed || generation != _operationGeneration) return;
    _activeCancellation = null;
    _progress = null;

    if (result.wasCancelled) {
      _status = ScanStatus.cancelled;
      _errorCode = result.errorCode;
      _notifySafely();
      return;
    }

    _result = result;
    _resultsStale = false;
    _scanRevision++;
    _errorCode = result.errorCode;
    if (result.canReadContacts) {
      _status = ScanStatus.completed;
    } else if (result.permissionState == ContactsPermissionState.failure) {
      _status = ScanStatus.error;
    } else {
      _status = ScanStatus.permissionDenied;
    }
    _notifySafely();
  }

  void cancelScan({ScanCancellationReason reason = ScanCancellationReason.user}) {
    if (!isScanning) return;
    _activeCancellation?.cancel(reason);
  }

  void invalidateForLifecyclePause() {
    if (isScanning) {
      _activeCancellation?.cancel(ScanCancellationReason.lifecycle);
    }
    markResultsStale();
  }

  void invalidateForExternalContactChange() => markResultsStale();

  void markResultsStale() {
    if (_result == null || _resultsStale) return;
    _resultsStale = true;
    _scanRevision++;
    _notifySafely();
  }

  Future<ContactsPermissionState> refreshPermission() async {
    final generation = _operationGeneration;
    final permission = await _service.checkPermission();
    if (_isDisposed || generation != _operationGeneration) return permission;
    if (_result != null &&
        permission != ContactsPermissionState.granted &&
        permission != ContactsPermissionState.limited) {
      _resultsStale = true;
      _notifySafely();
    }
    return permission;
  }

  Future<void> openAppSettings() async {
    _settingsErrorCode = null;
    try {
      await _service.openAppSettings();
    } on Object {
      if (_isDisposed) return;
      _settingsErrorCode = 'contacts_settings_open_failed';
      _notifySafely();
    }
  }

  void clearSettingsError() {
    if (_settingsErrorCode == null) return;
    _settingsErrorCode = null;
    _notifySafely();
  }

  void reset() {
    if (isScanning) return;
    _operationGeneration++;
    _status = ScanStatus.idle;
    _result = null;
    _progress = null;
    _errorCode = null;
    _settingsErrorCode = null;
    _resultsStale = false;
    _scanRevision++;
    _notifySafely();
  }

  void _notifySafely() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _operationGeneration++;
    _activeCancellation?.cancel(ScanCancellationReason.lifecycle);
    _activeCancellation = null;
    super.dispose();
  }
}
