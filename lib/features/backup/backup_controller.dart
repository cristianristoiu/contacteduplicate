import 'package:flutter/foundation.dart';

import '../../core/backup/contact_backup_service.dart';

enum BackupStatus {
  idle,
  loading,
  ready,
  creating,
  deleting,
  permissionDenied,
  error,
}

class BackupController extends ChangeNotifier {
  final ContactBackupService _service;

  BackupStatus _status = BackupStatus.idle;
  List<ContactBackup> _backups = const <ContactBackup>[];
  String? _errorCode;
  bool _isDisposed = false;

  BackupController(this._service);

  BackupStatus get status => _status;

  List<ContactBackup> get backups => _backups;

  String? get errorCode => _errorCode;

  bool get isBusy =>
      _status == BackupStatus.loading ||
      _status == BackupStatus.creating ||
      _status == BackupStatus.deleting;

  bool get hasValidatedBackup => _backups.any((backup) => backup.isValid);

  ContactBackup? get latestValidatedBackup {
    for (final backup in _backups) {
      if (backup.isValid) {
        return backup;
      }
    }
    return null;
  }

  Future<void> load() async {
    if (isBusy) {
      return;
    }

    _status = BackupStatus.loading;
    _errorCode = null;
    _notifySafely();

    try {
      _backups = await _service.listBackups();
      _status = BackupStatus.ready;
    } on ContactBackupException catch (error) {
      _status = BackupStatus.error;
      _errorCode = error.code;
    } on Object {
      _status = BackupStatus.error;
      _errorCode = 'backup_list_failed';
    }
    _notifySafely();
  }

  Future<ContactBackup?> create() async {
    if (isBusy) {
      return null;
    }

    _status = BackupStatus.creating;
    _errorCode = null;
    _notifySafely();

    try {
      final backup = await _service.createBackup();
      _backups = List<ContactBackup>.unmodifiable(
        <ContactBackup>[
          backup,
          ..._backups.where((existing) => existing.id != backup.id),
        ]..sort((left, right) => right.createdAt.compareTo(left.createdAt)),
      );
      _status = BackupStatus.ready;
      _notifySafely();
      return backup;
    } on ContactBackupException catch (error) {
      _status = error.code == 'contacts_permission_denied'
          ? BackupStatus.permissionDenied
          : BackupStatus.error;
      _errorCode = error.code;
    } on Object {
      _status = BackupStatus.error;
      _errorCode = 'backup_create_failed';
    }
    _notifySafely();
    return null;
  }

  Future<bool> delete(String id) async {
    if (isBusy) {
      return false;
    }

    _status = BackupStatus.deleting;
    _errorCode = null;
    _notifySafely();

    try {
      await _service.deleteBackup(id);
      _backups = List<ContactBackup>.unmodifiable(
        _backups.where((backup) => backup.id != id),
      );
      _status = BackupStatus.ready;
      _notifySafely();
      return true;
    } on ContactBackupException catch (error) {
      _status = BackupStatus.error;
      _errorCode = error.code;
    } on Object {
      _status = BackupStatus.error;
      _errorCode = 'backup_delete_failed';
    }
    _notifySafely();
    return false;
  }

  void clearError() {
    if (_status != BackupStatus.error &&
        _status != BackupStatus.permissionDenied) {
      return;
    }

    _status = BackupStatus.ready;
    _errorCode = null;
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
