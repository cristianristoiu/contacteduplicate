import 'package:flutter/foundation.dart';

import '../dashboard/scan_controller.dart';
import '../history/operation_history.dart';
import 'restore_service.dart';

enum RestoreControllerStatus {
  idle,
  previewing,
  ready,
  restoring,
  success,
  partial,
  blocked,
  cancelled,
  failed,
  reconcileRequired,
}

class RestoreController extends ChangeNotifier {
  final ContactRestoreService _service;
  final OperationHistoryRepository _history;
  final OperationHistoryFactory _historyFactory;
  final ScanController _scanController;
  final DateTime Function() _clock;

  RestoreControllerStatus _status = RestoreControllerStatus.idle;
  RestorePreview? _preview;
  RestoreReport? _report;
  String? _backupId;
  RestoreMode _mode = RestoreMode.full;
  RestoreConflictPolicy _conflictPolicy = RestoreConflictPolicy.block;
  Set<String> _targetContactIds = <String>{};
  RestoreCancellationToken? _token;
  String? _errorCode;
  bool _historyWriteFailed = false;
  bool _isDisposed = false;
  int _generation = 0;

  RestoreController({
    required ContactRestoreService service,
    required OperationHistoryRepository history,
    required ScanController scanController,
    OperationHistoryFactory historyFactory = const OperationHistoryFactory(),
    DateTime Function()? clock,
  })  : _service = service,
        _history = history,
        _scanController = scanController,
        _historyFactory = historyFactory,
        _clock = clock ?? DateTime.now;

  RestoreControllerStatus get status => _status;
  RestorePreview? get preview => _preview;
  RestoreReport? get report => _report;
  String? get backupId => _backupId;
  RestoreMode get mode => _mode;
  RestoreConflictPolicy get conflictPolicy => _conflictPolicy;
  Set<String> get targetContactIds => Set<String>.unmodifiable(_targetContactIds);
  String? get errorCode => _errorCode;
  bool get historyWriteFailed => _historyWriteFailed;
  bool get isBusy =>
      _status == RestoreControllerStatus.previewing ||
      _status == RestoreControllerStatus.restoring;
  bool get canCancel =>
      _status == RestoreControllerStatus.restoring && (_token?.canCancel ?? false);
  bool get requiresReconcile =>
      _status == RestoreControllerStatus.reconcileRequired ||
      (_report?.requiresReconcile ?? false);
  bool get canExecute =>
      _status == RestoreControllerStatus.ready &&
      (_preview?.hasWork ?? false) &&
      !(_preview?.hasConflicts ?? true);

  Future<RestorePreview?> prepare({
    required String backupId,
    RestoreMode mode = RestoreMode.full,
    Set<String> targetContactIds = const <String>{},
    RestoreConflictPolicy conflictPolicy = RestoreConflictPolicy.block,
  }) async {
    if (isBusy || requiresReconcile) return null;
    final id = backupId.trim();
    if (id.isEmpty ||
        (mode == RestoreMode.targeted && targetContactIds.isEmpty)) {
      _status = RestoreControllerStatus.blocked;
      _errorCode = mode == RestoreMode.targeted
          ? 'restore_target_selection_required'
          : 'restore_backup_id_missing';
      _notifySafely();
      return null;
    }

    final generation = ++_generation;
    _backupId = id;
    _mode = mode;
    _conflictPolicy = conflictPolicy;
    _targetContactIds = targetContactIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    _preview = null;
    _report = null;
    _errorCode = null;
    _historyWriteFailed = false;
    _status = RestoreControllerStatus.previewing;
    _notifySafely();

    try {
      final preview = await _service.preview(
        backupId: id,
        mode: mode,
        targetContactIds: _targetContactIds,
        conflictPolicy: conflictPolicy,
      );
      if (_isDisposed || generation != _generation) return null;
      _preview = preview;
      if (preview.hasConflicts && conflictPolicy == RestoreConflictPolicy.block) {
        _status = RestoreControllerStatus.blocked;
        _errorCode = 'restore_conflict_requires_resolution';
      } else {
        _status = RestoreControllerStatus.ready;
      }
      _notifySafely();
      return preview;
    } on Object {
      if (_isDisposed || generation != _generation) return null;
      _status = RestoreControllerStatus.failed;
      _errorCode = 'restore_preview_failed';
      _notifySafely();
      return null;
    }
  }

  Future<RestoreReport?> executeConfirmed() async {
    final backupId = _backupId;
    if (!canExecute || backupId == null) return null;
    final generation = ++_generation;
    final startedAt = _clock().toUtc();
    final token = RestoreCancellationToken();
    _token = token;
    _status = RestoreControllerStatus.restoring;
    _report = null;
    _errorCode = null;
    _notifySafely();

    final RestoreReport report;
    try {
      report = await _service.restore(
        backupId: backupId,
        userConfirmed: true,
        mode: _mode,
        targetContactIds: _targetContactIds,
        conflictPolicy: _conflictPolicy,
        cancellationToken: token,
      );
    } on Object {
      if (_isDisposed || generation != _generation) return null;
      _token = null;
      _status = RestoreControllerStatus.reconcileRequired;
      _errorCode = 'restore_controller_unexpected_failure';
      _notifySafely();
      return null;
    }
    if (_isDisposed || generation != _generation) return report;

    _token = null;
    _report = report;
    _errorCode = report.errorCode;
    _status = _mapStatus(report);
    if (report.restoredIds.isNotEmpty || report.requiresReconcile) {
      _scanController.markResultsStale();
    }
    await _recordHistory(report, startedAt);
    _notifySafely();
    return report;
  }

  bool requestCancel() {
    final token = _token;
    if (!canCancel || token == null) return false;
    token.cancel();
    _notifySafely();
    return true;
  }

  Future<RestorePreview?> retryPreview() async {
    final backupId = _backupId;
    if (backupId == null || isBusy || requiresReconcile) return null;
    return prepare(
      backupId: backupId,
      mode: _mode,
      targetContactIds: _targetContactIds,
      conflictPolicy: _conflictPolicy,
    );
  }

  void reset() {
    if (isBusy || requiresReconcile) return;
    _generation++;
    _backupId = null;
    _mode = RestoreMode.full;
    _conflictPolicy = RestoreConflictPolicy.block;
    _targetContactIds = <String>{};
    _preview = null;
    _report = null;
    _token = null;
    _errorCode = null;
    _historyWriteFailed = false;
    _status = RestoreControllerStatus.idle;
    _notifySafely();
  }

  RestoreControllerStatus _mapStatus(RestoreReport report) {
    return switch (report.status) {
      RestoreExecutionStatus.success => RestoreControllerStatus.success,
      RestoreExecutionStatus.partialSuccess => RestoreControllerStatus.partial,
      RestoreExecutionStatus.blocked || RestoreExecutionStatus.permissionDenied =>
        RestoreControllerStatus.blocked,
      RestoreExecutionStatus.cancelled => RestoreControllerStatus.cancelled,
      RestoreExecutionStatus.rollbackFailed ||
      RestoreExecutionStatus.reconcileRequired =>
        RestoreControllerStatus.reconcileRequired,
      RestoreExecutionStatus.rollbackSucceeded => RestoreControllerStatus.failed,
    };
  }

  Future<void> _recordHistory(RestoreReport report, DateTime startedAt) async {
    _historyWriteFailed = false;
    try {
      final operationId = 'restore-${startedAt.microsecondsSinceEpoch}';
      final entry = _historyFactory.fromRestore(
        report,
        operationId: operationId,
        startedAt: startedAt,
      );
      await _history.append(entry);
    } on Object {
      _historyWriteFailed = true;
    }
  }

  void _notifySafely() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _generation++;
    final token = _token;
    if (token != null && token.canCancel) token.cancel();
    super.dispose();
  }
}
