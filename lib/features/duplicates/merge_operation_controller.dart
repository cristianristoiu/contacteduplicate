import 'package:flutter/foundation.dart';

import '../dashboard/scan_controller.dart';
import '../history/operation_history.dart';
import 'merge_engine_service.dart';
import 'merge_plan.dart';

enum MergeOperationControllerStatus {
  idle,
  awaitingConfirmation,
  running,
  success,
  partial,
  blocked,
  cancelled,
  failed,
  reconcileRequired,
}

class MergeOperationController extends ChangeNotifier {
  final MergeEngineService _engine;
  final MergeContactGateway _gateway;
  final OperationHistoryRepository _history;
  final OperationHistoryFactory _historyFactory;
  final ScanController _scanController;

  MergeOperationControllerStatus _status = MergeOperationControllerStatus.idle;
  MergeProgress? _progress;
  MergeReport? _report;
  MergePlan? _pendingPlan;
  MergeCancellationToken? _cancellationToken;
  String? _errorCode;
  bool _historyWriteFailed = false;
  bool _isDisposed = false;

  MergeOperationController({
    required MergeEngineService engine,
    required MergeContactGateway gateway,
    required OperationHistoryRepository history,
    required ScanController scanController,
    OperationHistoryFactory historyFactory = const OperationHistoryFactory(),
  })  : _engine = engine,
        _gateway = gateway,
        _history = history,
        _scanController = scanController,
        _historyFactory = historyFactory;

  MergeOperationControllerStatus get status => _status;
  MergeProgress? get progress => _progress;
  MergeReport? get report => _report;
  MergePlan? get pendingPlan => _pendingPlan;
  String? get errorCode => _errorCode;
  bool get historyWriteFailed => _historyWriteFailed;
  bool get isRunning => _status == MergeOperationControllerStatus.running;
  bool get isAwaitingConfirmation =>
      _status == MergeOperationControllerStatus.awaitingConfirmation;
  bool get requiresReconcile =>
      _status == MergeOperationControllerStatus.reconcileRequired ||
      (_report?.requiresReconcile ?? false);
  bool get canCancel =>
      isRunning && (_cancellationToken?.canCancel ?? false);
  bool get editorLocked =>
      isRunning ||
      _status == MergeOperationControllerStatus.success ||
      _status == MergeOperationControllerStatus.partial ||
      requiresReconcile;

  bool prepare(MergePlan plan) {
    if (isRunning || requiresReconcile) return false;
    if (_scanController.resultsStale ||
        _scanController.isScanning ||
        _scanController.scanRevision != plan.scanRevision) {
      _block('merge_scan_revision_invalid');
      return false;
    }
    if (plan.hasUnresolvedConflicts ||
        !plan.hasStableOperationIdentity ||
        plan.safetyBlockers.isNotEmpty) {
      _block('merge_plan_not_ready');
      return false;
    }
    _pendingPlan = plan;
    _status = MergeOperationControllerStatus.awaitingConfirmation;
    _progress = null;
    _report = null;
    _errorCode = null;
    _historyWriteFailed = false;
    _notifySafely();
    return true;
  }

  void rejectConfirmation() {
    if (!isAwaitingConfirmation) return;
    _pendingPlan = null;
    _status = MergeOperationControllerStatus.idle;
    _errorCode = null;
    _notifySafely();
  }

  Future<MergeReport?> confirmAndExecute() async {
    final plan = _pendingPlan;
    if (!isAwaitingConfirmation || plan == null) return null;
    if (_scanController.resultsStale ||
        _scanController.isScanning ||
        _scanController.scanRevision != plan.scanRevision) {
      _block('merge_scan_changed_before_confirmation');
      return null;
    }

    final token = MergeCancellationToken();
    _cancellationToken = token;
    _status = MergeOperationControllerStatus.running;
    _progress = const MergeProgress(
      phase: MergeExecutionPhase.validatingPlan,
      ratio: 0,
    );
    _report = null;
    _errorCode = null;
    _notifySafely();

    MergeReport report;
    try {
      report = await _engine.execute(
        plan,
        cancellationToken: token,
        onProgress: _handleProgress,
      );
    } on Object {
      if (_isDisposed) return null;
      _status = MergeOperationControllerStatus.reconcileRequired;
      _errorCode = 'merge_controller_unexpected_failure';
      _progress = null;
      _cancellationToken = null;
      _notifySafely();
      return null;
    }
    if (_isDisposed) return report;

    _report = report;
    _progress = null;
    _cancellationToken = null;
    _status = _mapStatus(report);
    _errorCode = report.errorCode;
    if (report.changedAgenda) {
      _scanController.markResultsStale();
    }
    await _recordHistory(plan, report);
    _notifySafely();
    return report;
  }

  bool requestCancel() {
    final token = _cancellationToken;
    if (!isRunning || token == null || !token.canCancel) return false;
    token.cancel();
    _notifySafely();
    return true;
  }

  void acknowledgeResult() {
    if (isRunning || requiresReconcile) return;
    _pendingPlan = null;
    _report = null;
    _progress = null;
    _errorCode = null;
    _historyWriteFailed = false;
    _status = MergeOperationControllerStatus.idle;
    _notifySafely();
  }

  void clearBlockedState() {
    if (_status != MergeOperationControllerStatus.blocked &&
        _status != MergeOperationControllerStatus.failed &&
        _status != MergeOperationControllerStatus.cancelled) {
      return;
    }
    _pendingPlan = null;
    _report = null;
    _progress = null;
    _errorCode = null;
    _status = MergeOperationControllerStatus.idle;
    _notifySafely();
  }

  void _block(String code) {
    _pendingPlan = null;
    _status = MergeOperationControllerStatus.blocked;
    _errorCode = code;
    _notifySafely();
  }

  MergeOperationControllerStatus _mapStatus(MergeReport report) {
    return switch (report.status) {
      MergeExecutionStatus.success => MergeOperationControllerStatus.success,
      MergeExecutionStatus.partialFailure => MergeOperationControllerStatus.partial,
      MergeExecutionStatus.blocked ||
      MergeExecutionStatus.permissionDenied ||
      MergeExecutionStatus.preflightFailed => MergeOperationControllerStatus.blocked,
      MergeExecutionStatus.cancelled => MergeOperationControllerStatus.cancelled,
      MergeExecutionStatus.reconcileRequired ||
      MergeExecutionStatus.rollbackFailed =>
        MergeOperationControllerStatus.reconcileRequired,
      MergeExecutionStatus.createFailed ||
      MergeExecutionStatus.verificationFailed ||
      MergeExecutionStatus.rollbackSucceeded => MergeOperationControllerStatus.failed,
    };
  }

  Future<void> _recordHistory(MergePlan plan, MergeReport report) async {
    _historyWriteFailed = false;
    try {
      final createdFingerprint = await _verifiedCreatedFingerprint(report);
      await _history.append(
        _historyFactory.fromMerge(
          report,
          sourceCount: plan.sourceContactIds.length,
          backupId: plan.backupId,
          createdContactFingerprint: createdFingerprint,
        ),
      );
    } on Object {
      _historyWriteFailed = true;
    }
  }

  Future<String?> _verifiedCreatedFingerprint(MergeReport report) async {
    if (report.status != MergeExecutionStatus.success ||
        report.requiresReconcile) {
      return null;
    }
    final id = report.createdContactId?.trim();
    if (id == null || id.isEmpty) return null;
    try {
      final records = await _gateway.readContacts(<String>[id]);
      if (records.length != 1) return null;
      final record = records[id];
      if (record == null || !record.hasStableNativeId) return null;
      final fingerprint = record.revision.fingerprint.trim();
      return fingerprint.isEmpty ? null : fingerprint;
    } on Object {
      return null;
    }
  }

  void _handleProgress(MergeProgress progress) {
    if (_isDisposed || !isRunning) return;
    final current = _progress;
    if (current != null && progress.ratio < current.ratio) return;
    _progress = progress;
    _notifySafely();
  }

  void _notifySafely() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    final token = _cancellationToken;
    if (token != null && token.canCancel) token.cancel();
    super.dispose();
  }
}
