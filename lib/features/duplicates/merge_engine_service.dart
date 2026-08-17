import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/contacts/contact_models.dart';
import '../backup/backup_controller.dart';
import 'merge_plan.dart';

enum MergeExecutionStatus {
  success,
  blocked,
  permissionDenied,
  preflightFailed,
  createFailed,
  verificationFailed,
  partialFailure,
  rollbackSucceeded,
  rollbackFailed,
  reconcileRequired,
  cancelled,
}

enum MergeExecutionPhase {
  idle,
  validatingPlan,
  validatingBackup,
  rereadingSources,
  requestingWritePermission,
  creatingContact,
  verifyingCreatedContact,
  deletingSources,
  restoringSources,
  verifyingFinalState,
  completed,
}

class MergeProgress {
  final MergeExecutionPhase phase;
  final double ratio;
  final int processed;
  final int total;

  const MergeProgress({
    required this.phase,
    required this.ratio,
    this.processed = 0,
    this.total = 0,
  });
}

class MergeCancellationToken {
  bool _cancelRequested = false;
  bool _criticalPhase = false;

  bool get isCancelled => _cancelRequested;
  bool get canCancel => !_criticalPhase;

  void cancel() => _cancelRequested = true;
  void enterCriticalPhase() => _criticalPhase = true;
  void leaveCriticalPhase() => _criticalPhase = false;

  void throwIfCancelled() {
    if (_cancelRequested && !_criticalPhase) {
      throw const _MergeCancelled();
    }
  }
}

class MergeReport {
  final String operationId;
  final MergeExecutionStatus status;
  final String? createdContactId;
  final List<String> deletedSourceIds;
  final List<String> skippedSourceIds;
  final List<String> restoredSourceIds;
  final String? errorCode;
  final DateTime startedAt;
  final DateTime finishedAt;
  final bool requiresReconcile;

  MergeReport({
    required this.operationId,
    required this.status,
    this.createdContactId,
    Iterable<String> deletedSourceIds = const <String>[],
    Iterable<String> skippedSourceIds = const <String>[],
    Iterable<String> restoredSourceIds = const <String>[],
    this.errorCode,
    required this.startedAt,
    required this.finishedAt,
    this.requiresReconcile = false,
  })  : deletedSourceIds = List<String>.unmodifiable(deletedSourceIds),
        skippedSourceIds = List<String>.unmodifiable(skippedSourceIds),
        restoredSourceIds = List<String>.unmodifiable(restoredSourceIds);

  bool get isSuccess => status == MergeExecutionStatus.success;
  bool get changedAgenda =>
      createdContactId != null ||
      deletedSourceIds.isNotEmpty ||
      restoredSourceIds.isNotEmpty;
}

class MergeCreatedContact {
  final String id;
  final ContactRevisionInfo revision;

  const MergeCreatedContact({required this.id, required this.revision});
}

abstract interface class MergeContactGateway {
  Future<bool> requestWritePermission();
  Future<Map<String, ContactRecord>> readContacts(Iterable<String> ids);
  Future<MergeCreatedContact> createFromPlan(MergePlan plan);
  Future<bool> verifyCreatedContact(String id, MergePlan plan);
  Future<void> deleteContact(String id);
  Future<bool> contactExists(String id);
  Future<bool> restoreContact(ContactRecord record);
  Future<bool> verifyRestoredContact(ContactRecord record);
}

abstract interface class MergeOperationJournal {
  Future<void> begin(MergePlan plan);
  Future<void> checkpoint({
    required String operationId,
    required MergeExecutionPhase phase,
    bool createdContactKnown,
    int deletedSourceCount,
  });
  Future<void> complete(String operationId);
  Future<String?> pendingOperationId();
}

class PreferencesMergeOperationJournal implements MergeOperationJournal {
  static const String _key = 'merge_operation_checkpoint_v1';
  final SharedPreferencesAsync _preferences;

  PreferencesMergeOperationJournal({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  @override
  Future<void> begin(MergePlan plan) {
    return _write(<String, Object?>{
      'operationId': plan.operationId,
      'planFingerprint': plan.fingerprint,
      'phase': MergeExecutionPhase.validatingPlan.name,
      'sourceCount': plan.sourceContactIds.length,
      'createdAt': plan.createdAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> checkpoint({
    required String operationId,
    required MergeExecutionPhase phase,
    bool createdContactKnown = false,
    int deletedSourceCount = 0,
  }) {
    return _write(<String, Object?>{
      'operationId': operationId,
      'phase': phase.name,
      'created': createdContactKnown,
      'deletedCount': deletedSourceCount,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> complete(String operationId) async {
    final current = await pendingOperationId();
    if (current == operationId) {
      await _preferences.remove(_key);
    }
  }

  @override
  Future<String?> pendingOperationId() async {
    final raw = await _preferences.getString(_key);
    if (raw == null || raw.isEmpty || raw.length > 4096) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final id = decoded['operationId'];
      return id is String && id.trim().isNotEmpty && id.length <= 128
          ? id.trim()
          : null;
    } on Object {
      return null;
    }
  }

  Future<void> _write(Map<String, Object?> value) async {
    final encoded = jsonEncode(value);
    if (encoded.length > 4096) {
      throw StateError('merge_checkpoint_too_large');
    }
    await _preferences.setString(_key, encoded);
  }
}

class MergeEngineService {
  final MergeContactGateway _gateway;
  final BackupController _backupController;
  final MergePlanValidator _validator;
  final MergeOperationJournal _journal;
  final Duration nativeTimeout;
  final DateTime Function() _clock;

  Future<void> _mutex = Future<void>.value();
  final Set<String> _completedOperationIds = <String>{};

  MergeEngineService({
    required MergeContactGateway gateway,
    required BackupController backupController,
    MergePlanValidator validator = const MergePlanValidator(),
    MergeOperationJournal? journal,
    this.nativeTimeout = const Duration(seconds: 20),
    DateTime Function()? clock,
  })  : assert(nativeTimeout > Duration.zero),
        _gateway = gateway,
        _backupController = backupController,
        _validator = validator,
        _journal = journal ?? PreferencesMergeOperationJournal(),
        _clock = clock ?? DateTime.now;

  Future<MergeReport> execute(
    MergePlan plan, {
    MergeCancellationToken? cancellationToken,
    void Function(MergeProgress progress)? onProgress,
  }) {
    final completer = Completer<MergeReport>();
    _mutex = _mutex.catchError((Object _) {}).then((_) async {
      try {
        completer.complete(
          await _executeLocked(
            plan,
            cancellationToken: cancellationToken,
            onProgress: onProgress,
          ),
        );
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<MergeReport> _executeLocked(
    MergePlan plan, {
    MergeCancellationToken? cancellationToken,
    void Function(MergeProgress progress)? onProgress,
  }) async {
    final startedAt = _clock().toUtc();
    final token = cancellationToken ?? MergeCancellationToken();

    if (_completedOperationIds.contains(plan.operationId)) {
      return _report(
        plan,
        startedAt,
        MergeExecutionStatus.blocked,
        'merge_operation_already_completed',
      );
    }

    final pending = await _journal.pendingOperationId();
    if (pending != null && pending != plan.operationId) {
      return _report(
        plan,
        startedAt,
        MergeExecutionStatus.reconcileRequired,
        'merge_other_operation_pending',
        requiresReconcile: true,
      );
    }

    try {
      await _journal.begin(plan);
      _progress(onProgress, MergeExecutionPhase.validatingPlan, 0.04);
      token.throwIfCancelled();

      final structuralRecords = <String, ContactRecord>{
        for (final id in plan.sourceContactIds)
          id: ContactRecord(
            nativeId: id,
            hasStableNativeId: true,
            name: const ContactNameParts(displayName: 'preflight'),
            revision: const ContactRevisionInfo(fingerprint: 'preflight'),
          ),
      };
      final structural = _validator.validate(
        plan,
        sourceRecords: structuralRecords,
      );
      if (!structural.isValid) {
        return _finalizedReport(
          plan,
          startedAt,
          MergeExecutionStatus.blocked,
          'merge_plan_${structural.code.name}',
        );
      }

      _progress(onProgress, MergeExecutionPhase.validatingBackup, 0.1);
      final backup = await _backupController.validateMergeSources(
        plan.sourceContactIds,
      );
      if (!backup.isValid || backup.backupId != plan.backupId) {
        return _finalizedReport(
          plan,
          startedAt,
          MergeExecutionStatus.preflightFailed,
          'merge_backup_preflight_failed',
        );
      }

      token.throwIfCancelled();
      _progress(onProgress, MergeExecutionPhase.rereadingSources, 0.18);
      final live = await _withTimeout(
        _gateway.readContacts(plan.sourceContactIds),
        'merge_source_read_timeout',
      );
      if (live.length != plan.sourceContactIds.length ||
          !live.keys.toSet().containsAll(plan.sourceContactIds)) {
        return _finalizedReport(
          plan,
          startedAt,
          MergeExecutionStatus.preflightFailed,
          'merge_source_missing_live',
        );
      }

      final liveValidation = _validator.validate(
        plan,
        sourceRecords: live,
      );
      if (!liveValidation.isValid) {
        return _finalizedReport(
          plan,
          startedAt,
          MergeExecutionStatus.preflightFailed,
          'merge_live_${liveValidation.code.name}',
        );
      }

      final liveSnapshot = stableOpaqueId(
        plan.sourceContactIds.map((id) => live[id]!.revision.fingerprint),
        namespace: 'merge-snapshot',
      );
      if (liveSnapshot != plan.sourceSnapshotFingerprint) {
        return _finalizedReport(
          plan,
          startedAt,
          MergeExecutionStatus.preflightFailed,
          'merge_source_snapshot_changed',
        );
      }

      token.throwIfCancelled();
      _progress(
        onProgress,
        MergeExecutionPhase.requestingWritePermission,
        0.25,
      );
      final hasPermission = await _withTimeout(
        _gateway.requestWritePermission(),
        'merge_write_permission_timeout',
      );
      if (!hasPermission) {
        return _finalizedReport(
          plan,
          startedAt,
          MergeExecutionStatus.permissionDenied,
          'contacts_write_permission_denied',
        );
      }

      final backupBeforeWrite = await _backupController.validateMergeSources(
        plan.sourceContactIds,
      );
      if (!backupBeforeWrite.isValid ||
          backupBeforeWrite.backupId != plan.backupId) {
        return _finalizedReport(
          plan,
          startedAt,
          MergeExecutionStatus.preflightFailed,
          'merge_backup_changed_before_write',
        );
      }

      return await _mutate(
        plan,
        live,
        startedAt,
        token,
        onProgress,
      );
    } on _MergeCancelled {
      return _finalizedReport(
        plan,
        startedAt,
        MergeExecutionStatus.cancelled,
        'merge_cancelled',
      );
    } on TimeoutException {
      return _report(
        plan,
        startedAt,
        MergeExecutionStatus.reconcileRequired,
        'merge_native_timeout_unknown_state',
        requiresReconcile: true,
      );
    } on Object {
      return _report(
        plan,
        startedAt,
        MergeExecutionStatus.reconcileRequired,
        'merge_unexpected_failure',
        requiresReconcile: true,
      );
    }
  }

  Future<MergeReport> _mutate(
    MergePlan plan,
    Map<String, ContactRecord> live,
    DateTime startedAt,
    MergeCancellationToken token,
    void Function(MergeProgress progress)? onProgress,
  ) async {
    token.enterCriticalPhase();
    String? createdId;
    final deleted = <String>[];
    final skipped = <String>[];
    final restored = <String>[];

    try {
      _progress(onProgress, MergeExecutionPhase.creatingContact, 0.35);
      final created = await _withTimeout(
        _gateway.createFromPlan(plan),
        'merge_create_timeout',
      );
      createdId = created.id.trim();
      if (createdId.isEmpty) {
        return _report(
          plan,
          startedAt,
          MergeExecutionStatus.reconcileRequired,
          'merge_created_id_empty_unknown_state',
          requiresReconcile: true,
        );
      }
      await _journal.checkpoint(
        operationId: plan.operationId,
        phase: MergeExecutionPhase.creatingContact,
        createdContactKnown: true,
      );

      _progress(
        onProgress,
        MergeExecutionPhase.verifyingCreatedContact,
        0.48,
      );
      final createdValid = await _withTimeout(
        _gateway.verifyCreatedContact(createdId, plan),
        'merge_created_verification_timeout',
      );
      if (!createdValid) {
        final removed = await _rollbackCreated(createdId);
        final report = _report(
          plan,
          startedAt,
          removed
              ? MergeExecutionStatus.rollbackSucceeded
              : MergeExecutionStatus.rollbackFailed,
          removed
              ? 'merge_created_verification_failed_rolled_back'
              : 'merge_created_verification_failed_rollback_failed',
          createdContactId: removed ? null : createdId,
          requiresReconcile: !removed,
        );
        if (!report.requiresReconcile) await _journal.complete(plan.operationId);
        return report;
      }

      _progress(
        onProgress,
        MergeExecutionPhase.deletingSources,
        0.58,
        total: plan.sourceContactIds.length,
      );
      for (var index = 0; index < plan.sourceContactIds.length; index++) {
        final id = plan.sourceContactIds[index];
        final source = live[id]!;
        if (!source.capabilities.canDelete) {
          skipped.add(id);
          continue;
        }
        try {
          await _withTimeout(
            _gateway.deleteContact(id),
            'merge_delete_timeout',
          );
          final exists = await _withTimeout(
            _gateway.contactExists(id),
            'merge_delete_verify_timeout',
          );
          if (exists) throw StateError('merge_source_delete_not_applied');
          deleted.add(id);
          await _journal.checkpoint(
            operationId: plan.operationId,
            phase: MergeExecutionPhase.deletingSources,
            createdContactKnown: true,
            deletedSourceCount: deleted.length,
          );
        } on Object {
          final sourcesRestored = await _restoreDeleted(
            live,
            deleted,
            restored,
            onProgress,
          );
          final createdRemoved = await _rollbackCreated(createdId);
          final rollbackComplete = sourcesRestored && createdRemoved;
          final report = _report(
            plan,
            startedAt,
            rollbackComplete
                ? MergeExecutionStatus.rollbackSucceeded
                : MergeExecutionStatus.rollbackFailed,
            rollbackComplete
                ? 'merge_delete_failed_rolled_back'
                : 'merge_delete_failed_rollback_incomplete',
            createdContactId: createdRemoved ? null : createdId,
            deletedSourceIds: deleted,
            skippedSourceIds: skipped,
            restoredSourceIds: restored,
            requiresReconcile: !rollbackComplete,
          );
          if (!report.requiresReconcile) {
            await _journal.complete(plan.operationId);
          }
          return report;
        }
        _progress(
          onProgress,
          MergeExecutionPhase.deletingSources,
          0.58 + 0.25 * ((index + 1) / plan.sourceContactIds.length),
          processed: index + 1,
          total: plan.sourceContactIds.length,
        );
      }

      _progress(onProgress, MergeExecutionPhase.verifyingFinalState, 0.9);
      final finalValid = await _withTimeout(
        _gateway.verifyCreatedContact(createdId, plan),
        'merge_final_verification_timeout',
      );
      if (!finalValid) {
        return _report(
          plan,
          startedAt,
          MergeExecutionStatus.reconcileRequired,
          'merge_final_state_unknown',
          createdContactId: createdId,
          deletedSourceIds: deleted,
          skippedSourceIds: skipped,
          requiresReconcile: true,
        );
      }

      final report = _report(
        plan,
        startedAt,
        skipped.isEmpty
            ? MergeExecutionStatus.success
            : MergeExecutionStatus.partialFailure,
        skipped.isEmpty ? null : 'merge_read_only_sources_skipped',
        createdContactId: createdId,
        deletedSourceIds: deleted,
        skippedSourceIds: skipped,
      );
      _completedOperationIds.add(plan.operationId);
      await _journal.complete(plan.operationId);
      _progress(onProgress, MergeExecutionPhase.completed, 1);
      return report;
    } on TimeoutException {
      return _report(
        plan,
        startedAt,
        MergeExecutionStatus.reconcileRequired,
        'merge_native_timeout_unknown_state',
        createdContactId: createdId,
        deletedSourceIds: deleted,
        skippedSourceIds: skipped,
        restoredSourceIds: restored,
        requiresReconcile: true,
      );
    } on Object {
      return _report(
        plan,
        startedAt,
        MergeExecutionStatus.reconcileRequired,
        'merge_unexpected_mutation_failure',
        createdContactId: createdId,
        deletedSourceIds: deleted,
        skippedSourceIds: skipped,
        restoredSourceIds: restored,
        requiresReconcile: createdId != null || deleted.isNotEmpty,
      );
    } finally {
      token.leaveCriticalPhase();
    }
  }

  Future<bool> _rollbackCreated(String id) async {
    try {
      await _withTimeout(_gateway.deleteContact(id), 'merge_rollback_timeout');
      return !(await _withTimeout(
        _gateway.contactExists(id),
        'merge_rollback_verify_timeout',
      ));
    } on Object {
      return false;
    }
  }

  Future<bool> _restoreDeleted(
    Map<String, ContactRecord> live,
    List<String> deleted,
    List<String> restored,
    void Function(MergeProgress progress)? onProgress,
  ) async {
    var allRestored = true;
    _progress(
      onProgress,
      MergeExecutionPhase.restoringSources,
      0.72,
      total: deleted.length,
    );
    for (var index = deleted.length - 1; index >= 0; index--) {
      final id = deleted[index];
      final source = live[id];
      if (source == null) {
        allRestored = false;
        continue;
      }
      try {
        final restoredOk = await _withTimeout(
          _gateway.restoreContact(source),
          'merge_restore_timeout',
        );
        final verified = restoredOk &&
            await _withTimeout(
              _gateway.verifyRestoredContact(source),
              'merge_restore_verify_timeout',
            );
        if (verified) {
          restored.add(id);
        } else {
          allRestored = false;
        }
      } on Object {
        allRestored = false;
      }
    }
    return allRestored;
  }

  Future<MergeReport> _finalizedReport(
    MergePlan plan,
    DateTime startedAt,
    MergeExecutionStatus status,
    String? errorCode,
  ) async {
    final report = _report(plan, startedAt, status, errorCode);
    await _journal.complete(plan.operationId);
    return report;
  }

  Future<T> _withTimeout<T>(Future<T> future, String code) async {
    try {
      return await future.timeout(nativeTimeout);
    } on TimeoutException {
      throw TimeoutException(code, nativeTimeout);
    }
  }

  MergeReport _report(
    MergePlan plan,
    DateTime startedAt,
    MergeExecutionStatus status,
    String? errorCode, {
    String? createdContactId,
    Iterable<String> deletedSourceIds = const <String>[],
    Iterable<String> skippedSourceIds = const <String>[],
    Iterable<String> restoredSourceIds = const <String>[],
    bool requiresReconcile = false,
  }) {
    return MergeReport(
      operationId: plan.operationId,
      status: status,
      createdContactId: createdContactId,
      deletedSourceIds: deletedSourceIds,
      skippedSourceIds: skippedSourceIds,
      restoredSourceIds: restoredSourceIds,
      errorCode: errorCode,
      startedAt: startedAt,
      finishedAt: _clock().toUtc(),
      requiresReconcile: requiresReconcile,
    );
  }

  void _progress(
    void Function(MergeProgress progress)? callback,
    MergeExecutionPhase phase,
    double ratio, {
    int processed = 0,
    int total = 0,
  }) {
    callback?.call(
      MergeProgress(
        phase: phase,
        ratio: ratio.clamp(0, 1).toDouble(),
        processed: processed,
        total: total,
      ),
    );
  }
}

class _MergeCancelled implements Exception {
  const _MergeCancelled();
}
