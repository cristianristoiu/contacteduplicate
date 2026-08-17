import 'dart:async';

import '../duplicates/merge_engine_service.dart';
import '../history/operation_history.dart';
import 'restore_service.dart';

enum UndoExecutionStatus {
  success,
  blocked,
  restoreFailed,
  identityMismatch,
  permissionDenied,
  deleteFailed,
  reconcileRequired,
}

class UndoReport {
  final String parentOperationId;
  final UndoExecutionStatus status;
  final RestoreReport? restoreReport;
  final bool consolidatedContactRemoved;
  final String? errorCode;
  final DateTime startedAt;
  final DateTime finishedAt;
  final bool requiresReconcile;

  const UndoReport({
    required this.parentOperationId,
    required this.status,
    this.restoreReport,
    this.consolidatedContactRemoved = false,
    this.errorCode,
    required this.startedAt,
    required this.finishedAt,
    this.requiresReconcile = false,
  });

  bool get isSuccess => status == UndoExecutionStatus.success;
}

class UndoService {
  final OperationHistoryRepository _history;
  final ContactRestoreService _restoreService;
  final MergeContactGateway _mergeGateway;
  final Duration operationTimeout;
  final DateTime Function() _clock;
  Future<void> _mutex = Future<void>.value();

  UndoService({
    required OperationHistoryRepository history,
    required ContactRestoreService restoreService,
    required MergeContactGateway mergeGateway,
    this.operationTimeout = const Duration(seconds: 20),
    DateTime Function()? clock,
  })  : assert(operationTimeout > Duration.zero),
        _history = history,
        _restoreService = restoreService,
        _mergeGateway = mergeGateway,
        _clock = clock ?? DateTime.now;

  Future<UndoReport> execute({
    required String parentOperationId,
    required bool userConfirmed,
  }) {
    final completer = Completer<UndoReport>();
    _mutex = _mutex.catchError((Object _) {}).then((_) async {
      try {
        completer.complete(
          await _executeLocked(
            parentOperationId: parentOperationId,
            userConfirmed: userConfirmed,
          ),
        );
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<UndoReport> _executeLocked({
    required String parentOperationId,
    required bool userConfirmed,
  }) async {
    final startedAt = _clock().toUtc();
    final operationId = parentOperationId.trim();
    if (operationId.isEmpty || !userConfirmed) {
      return _report(
        operationId,
        startedAt,
        UndoExecutionStatus.blocked,
        'undo_confirmation_required',
      );
    }

    final parent = await _history.find(operationId);
    if (parent == null ||
        parent.type != OperationHistoryType.merge ||
        !parent.canUndo ||
        !parent.hasVerifiedMergeUndoIdentity ||
        parent.undoBackupId == null ||
        parent.undoTargetIds.isEmpty) {
      return _report(
        operationId,
        startedAt,
        UndoExecutionStatus.blocked,
        'undo_parent_not_eligible',
      );
    }

    final backupId = parent.undoBackupId!;
    final targets = parent.undoTargetIds.toSet();
    RestoreReport restoreReport;
    try {
      restoreReport = await _restoreService.restore(
        backupId: backupId,
        userConfirmed: true,
        mode: RestoreMode.targeted,
        targetContactIds: targets,
        conflictPolicy: RestoreConflictPolicy.block,
      );
    } on TimeoutException {
      return _report(
        operationId,
        startedAt,
        UndoExecutionStatus.reconcileRequired,
        'undo_restore_timeout_unknown_state',
        requiresReconcile: true,
      );
    } on Object {
      return _report(
        operationId,
        startedAt,
        UndoExecutionStatus.restoreFailed,
        'undo_restore_unexpected_failure',
      );
    }

    if (restoreReport.requiresReconcile) {
      return _report(
        operationId,
        startedAt,
        UndoExecutionStatus.reconcileRequired,
        restoreReport.errorCode ?? 'undo_restore_requires_reconcile',
        restoreReport: restoreReport,
        requiresReconcile: true,
      );
    }
    if (restoreReport.status != RestoreExecutionStatus.success ||
        restoreReport.restoredIds.toSet().length != targets.length ||
        !restoreReport.restoredIds.toSet().containsAll(targets)) {
      return _report(
        operationId,
        startedAt,
        UndoExecutionStatus.restoreFailed,
        restoreReport.errorCode ?? 'undo_sources_not_fully_restored',
        restoreReport: restoreReport,
      );
    }

    final consolidatedId = parent.createdContactId!;
    final expectedFingerprint = parent.createdContactFingerprint!;
    final current = await _readSingle(consolidatedId);
    if (current == null) {
      // Contactul consolidat a fost deja eliminat extern. Sursele sunt restaurate,
      // iar starea finala dorita este deja demonstrata.
      final consumed = await _history.markUndoConsumed(operationId);
      if (!consumed) {
        return _report(
          operationId,
          startedAt,
          UndoExecutionStatus.reconcileRequired,
          'undo_history_consumption_failed',
          restoreReport: restoreReport,
          consolidatedContactRemoved: true,
          requiresReconcile: true,
        );
      }
      return _report(
        operationId,
        startedAt,
        UndoExecutionStatus.success,
        null,
        restoreReport: restoreReport,
        consolidatedContactRemoved: true,
      );
    }

    if (current.revision.fingerprint != expectedFingerprint) {
      return _report(
        operationId,
        startedAt,
        UndoExecutionStatus.identityMismatch,
        'undo_consolidated_contact_changed',
        restoreReport: restoreReport,
        requiresReconcile: true,
      );
    }

    final hasPermission = await _withTimeout(
      _mergeGateway.requestWritePermission(),
      'undo_write_permission_timeout',
    );
    if (!hasPermission) {
      return _report(
        operationId,
        startedAt,
        UndoExecutionStatus.permissionDenied,
        'contacts_write_permission_denied',
        restoreReport: restoreReport,
      );
    }

    final rechecked = await _readSingle(consolidatedId);
    if (rechecked == null) {
      final consumed = await _history.markUndoConsumed(operationId);
      return _report(
        operationId,
        startedAt,
        consumed
            ? UndoExecutionStatus.success
            : UndoExecutionStatus.reconcileRequired,
        consumed ? null : 'undo_history_consumption_failed',
        restoreReport: restoreReport,
        consolidatedContactRemoved: true,
        requiresReconcile: !consumed,
      );
    }
    if (rechecked.revision.fingerprint != expectedFingerprint) {
      return _report(
        operationId,
        startedAt,
        UndoExecutionStatus.identityMismatch,
        'undo_consolidated_contact_changed_after_permission',
        restoreReport: restoreReport,
        requiresReconcile: true,
      );
    }

    try {
      await _withTimeout(
        _mergeGateway.deleteContact(consolidatedId),
        'undo_delete_timeout',
      );
      final remains = await _withTimeout(
        _mergeGateway.contactExists(consolidatedId),
        'undo_delete_verify_timeout',
      );
      if (remains) {
        return _report(
          operationId,
          startedAt,
          UndoExecutionStatus.deleteFailed,
          'undo_consolidated_delete_not_applied',
          restoreReport: restoreReport,
          requiresReconcile: true,
        );
      }
    } on TimeoutException {
      return _report(
        operationId,
        startedAt,
        UndoExecutionStatus.reconcileRequired,
        'undo_delete_timeout_unknown_state',
        restoreReport: restoreReport,
        requiresReconcile: true,
      );
    } on Object {
      return _report(
        operationId,
        startedAt,
        UndoExecutionStatus.deleteFailed,
        'undo_consolidated_delete_failed',
        restoreReport: restoreReport,
        requiresReconcile: true,
      );
    }

    final consumed = await _history.markUndoConsumed(operationId);
    return _report(
      operationId,
      startedAt,
      consumed
          ? UndoExecutionStatus.success
          : UndoExecutionStatus.reconcileRequired,
      consumed ? null : 'undo_history_consumption_failed',
      restoreReport: restoreReport,
      consolidatedContactRemoved: true,
      requiresReconcile: !consumed,
    );
  }

  Future<dynamic> _readSingle(String id) async {
    try {
      final records = await _withTimeout(
        _mergeGateway.readContacts(<String>[id]),
        'undo_identity_read_timeout',
      );
      if (records.isEmpty) return null;
      if (records.length != 1 || records[id] == null) {
        throw StateError('undo_identity_read_ambiguous');
      }
      return records[id];
    } on TimeoutException {
      rethrow;
    }
  }

  Future<T> _withTimeout<T>(Future<T> future, String code) async {
    try {
      return await future.timeout(operationTimeout);
    } on TimeoutException {
      throw TimeoutException(code, operationTimeout);
    }
  }

  UndoReport _report(
    String parentOperationId,
    DateTime startedAt,
    UndoExecutionStatus status,
    String? errorCode, {
    RestoreReport? restoreReport,
    bool consolidatedContactRemoved = false,
    bool requiresReconcile = false,
  }) {
    return UndoReport(
      parentOperationId: parentOperationId,
      status: status,
      restoreReport: restoreReport,
      consolidatedContactRemoved: consolidatedContactRemoved,
      errorCode: errorCode,
      startedAt: startedAt,
      finishedAt: _clock().toUtc(),
      requiresReconcile: requiresReconcile,
    );
  }
}
