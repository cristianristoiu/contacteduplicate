import 'package:flutter/foundation.dart';

enum AppOperationKind {
  scan,
  backupCreate,
  backupDelete,
  merge,
  restore,
  contactCopy,
}

class OperationLease {
  final OperationCoordinator _coordinator;
  final String token;
  final AppOperationKind kind;
  bool _released = false;

  OperationLease._(this._coordinator, this.token, this.kind);

  bool get isReleased => _released;
  bool get isCurrent => !_released && _coordinator.owns(token);
  bool get isCritical => isCurrent && _coordinator.isCritical;

  bool enterCritical() {
    if (_released) return false;
    return _coordinator._setCritical(token, true);
  }

  bool leaveCritical() {
    if (_released) return false;
    return _coordinator._setCritical(token, false);
  }

  void release() {
    if (_released) return;
    _released = true;
    _coordinator._release(token);
  }
}

class OperationCoordinator extends ChangeNotifier {
  AppOperationKind? _activeKind;
  String? _ownerToken;
  bool _critical = false;
  int _sequence = 0;
  int _externalStateRevision = 0;
  bool _isDisposed = false;

  AppOperationKind? get activeKind => _activeKind;
  bool get isBusy => _activeKind != null;
  bool get isCritical => _critical && isBusy;
  int get externalStateRevision => _externalStateRevision;

  bool get hasMutation => switch (_activeKind) {
        AppOperationKind.merge ||
        AppOperationKind.restore ||
        AppOperationKind.contactCopy ||
        AppOperationKind.backupCreate ||
        AppOperationKind.backupDelete => true,
        AppOperationKind.scan || null => false,
      };

  bool canStart(AppOperationKind kind) {
    if (_isDisposed || isBusy) return false;
    return true;
  }

  OperationLease? tryAcquire(AppOperationKind kind) {
    if (!canStart(kind)) return null;
    final token = 'operation-${++_sequence}';
    _activeKind = kind;
    _ownerToken = token;
    _critical = false;
    _notifySafely();
    return OperationLease._(this, token, kind);
  }

  bool owns(String token) =>
      !_isDisposed && _ownerToken != null && _ownerToken == token;

  void markExternalContactStateUnknown() {
    _externalStateRevision++;
    _notifySafely();
  }

  bool _setCritical(String token, bool value) {
    if (!owns(token) || _critical == value) return false;
    _critical = value;
    _notifySafely();
    return true;
  }

  void _release(String token) {
    if (!owns(token)) return;
    _ownerToken = null;
    _activeKind = null;
    _critical = false;
    _notifySafely();
  }

  void _notifySafely() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _ownerToken = null;
    _activeKind = null;
    _critical = false;
    super.dispose();
  }
}
