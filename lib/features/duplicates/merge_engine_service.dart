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
  pendingBeforeMutation,
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

  void cancel() {
    if (_criticalPhase) return;
    _cancelRequested = true;
  }

  void enterCriticalPhase() => _criticalPhase = true;
  void leaveCriticalPhase() => _criticalPhase = false;

  void throwIfCancelled() {
    if (_cancelRequested && !_criticalPhase) throw const _MergeCancelled();
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
  })  : deletedSourceIds = List<String>.unmodifiable(
          deletedSourceIds.map((id) => id.trim()).where((id) => id.isNotEmpty),
        ),
        skippedSourceIds = List<String>.unmodifiable(
          skippedSourceIds.map((id) => id.trim()).where((id) => id.isNotEmpty),
        ),
        restoredSourceIds = List<String>.unmodifiable(
          restoredSourceIds.map((id) => id.trim()).where((id) => id.isNotEmpty),
        );

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

class MergeOperationCheckpoint {
  final String operationId;
  final String planFingerprint;
  final MergeExecutionPhase phase;
  final int sourceCount;
  final String? createdContactId;
  final List<String> deletedSourceIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  MergeOperationCheckpoint({
    required this.operationId,
    required this.planFingerprint,
    required this.phase,
    required this.sourceCount,
    this.createdContactId,
    Iterable<String> deletedSourceIds = const <String>[],
    required this.createdAt,
    required this.updatedAt,
  }) : deletedSourceIds = List<String>.unmodifiable(
          deletedSourceIds
              .map((id) => id.trim())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList()
            ..sort(),
        );

  bool get isPreMutation =>
      createdContactId == null &&
      deletedSourceIds.isEmpty &&
      (phase == MergeExecutionPhase.validatingPlan ||
          phase == MergeExecutionPhase.validatingBackup ||
          phase == MergeExecutionPhase.rereadingSources ||
          phase == MergeExecutionPhase.requestingWritePermission ||
          phase == MergeExecutionPhase.pendingBeforeMutation);

  bool get isStructurallyValid =>
      operationId.trim().isNotEmpty &&
      operationId.length <= MergePlan.maxOperationIdLength &&
      planFingerprint.trim().isNotEmpty &&
      planFingerprint.length <= 128 &&
      sourceCount >= 2 &&
      sourceCount <= 10000 &&
      deletedSourceIds.length <= sourceCount &&
      deletedSourceIds.every((id) => id.length <= 256) &&
      (createdContactId == null ||
          (createdContactId!.trim().isNotEmpty &&
              createdContactId!.length <= 256)) &&
      !updatedAt.isBefore(createdAt);
}

abstract interface class MergeOperationJournal {
  Future<void> begin(MergePlan plan);
  Future<void> checkpoint({
    required String operationId,
    required String planFingerprint,
    required MergeExecutionPhase phase,
    required int sourceCount,
    String? createdContactId,
    Iterable<String> deletedSourceIds,
  });
  Future<void> complete(String operationId);
  Future<MergeOperationCheckpoint?> readPending();
  Future<bool> wasCompleted(String operationId);
}

class PreferencesMergeOperationJournal implements MergeOperationJournal {
  static const String _checkpointKey = 'merge_operation_checkpoint_v2';
  static const String _completedKey = 'merge_operation_completed_v1';
  static const int _schemaVersion = 2;
  static const int _maximumCheckpointBytes = 8192;
  static const int _maximumCompletedEntries = 64;

  final SharedPreferencesAsync _preferences;
  final DateTime Function() _clock;
  Future<void> _writeQueue = Future<void>.value();

  PreferencesMergeOperationJournal({
    SharedPreferencesAsync? preferences,
    DateTime Function()? clock,
  })  : _preferences = preferences ?? SharedPreferencesAsync(),
        _clock = clock ?? DateTime.now;

  @override
  Future<void> begin(MergePlan plan) async {
    final pending = await readPending();
    if (pending != null) throw StateError('merge_checkpoint_already_exists');
    if (await wasCompleted(plan.operationId)) {
      throw StateError('merge_operation_already_completed');
    }
    final now = _clock().toUtc();
    await _enqueueWrite(
      () => _writeCheckpoint(
        MergeOperationCheckpoint(
          operationId: plan.operationId,
          planFingerprint: plan.fingerprint,
          phase: MergeExecutionPhase.validatingPlan,
          sourceCount: plan.sourceContactIds.length,
          createdAt: now,
          updatedAt: now,
        ),
      ),
    );
  }

  @override
  Future<void> checkpoint({
    required String operationId,
    required String planFingerprint,
    required MergeExecutionPhase phase,
    required int sourceCount,
    String? createdContactId,
    Iterable<String> deletedSourceIds = const <String>[],
  }) async {
    final current = await readPending();
    if (current == null || current.operationId != operationId) {
      throw StateError('merge_checkpoint_missing');
    }
    if (current.planFingerprint != planFingerprint ||
        current.sourceCount != sourceCount) {
      throw StateError('merge_checkpoint_identity_mismatch');
    }
    if (phase.index < current.phase.index) {
      throw StateError('merge_checkpoint_phase_regressed');
    }
    final created = createdContactId?.trim();
    if (current.createdContactId != null &&
        created != null &&
        current.createdContactId != created) {
      throw StateError('merge_checkpoint_created_id_changed');
    }
    final deleted = deletedSourceIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (!deleted.containsAll(current.deletedSourceIds)) {
      throw StateError('merge_checkpoint_deleted_set_regressed');
    }
    if (deleted.length > sourceCount) {
      throw StateError('merge_checkpoint_deleted_set_invalid');
    }
    await _enqueueWrite(
      () => _writeCheckpoint(
        MergeOperationCheckpoint(
          operationId: operationId,
          planFingerprint: planFingerprint,
          phase: phase,
          sourceCount: sourceCount,
          createdContactId: created ?? current.createdContactId,
          deletedSourceIds: deleted,
          createdAt: current.createdAt,
          updatedAt: _clock().toUtc(),
        ),
      ),
    );
  }

  @override
  Future<void> complete(String operationId) async {
    final id = operationId.trim();
    if (id.isEmpty) return;
    await _enqueueWrite(() async {
      final pending = await _readCheckpointUnlocked();
      if (pending != null && pending.operationId != id) {
        throw StateError('merge_checkpoint_other_operation_pending');
      }
      if (pending != null) await _preferences.remove(_checkpointKey);
      final completed = await _readCompletedUnlocked();
      completed.remove(id);
      completed.insert(0, id);
      if (completed.length > _maximumCompletedEntries) {
        completed.removeRange(_maximumCompletedEntries, completed.length);
      }
      await _preferences.setStringList(_completedKey, completed);
    });
  }

  @override
  Future<MergeOperationCheckpoint?> readPending() => _readCheckpointUnlocked();

  @override
  Future<bool> wasCompleted(String operationId) async {
    final id = operationId.trim();
    if (id.isEmpty) return false;
    return (await _readCompletedUnlocked()).contains(id);
  }

  Future<MergeOperationCheckpoint?> _readCheckpointUnlocked() async {
    final raw = await _preferences.getString(_checkpointKey);
    if (raw == null || raw.isEmpty) return null;
    if (raw.length > _maximumCheckpointBytes) {
      throw StateError('merge_checkpoint_too_large');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on Object {
      throw StateError('merge_checkpoint_corrupt');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['schemaVersion'] != _schemaVersion) {
      throw StateError('merge_checkpoint_schema_invalid');
    }
    final operationId = decoded['operationId'];
    final planFingerprint = decoded['planFingerprint'];
    final phaseName = decoded['phase'];
    final sourceCount = decoded['sourceCount'];
    final createdAtRaw = decoded['createdAt'];
    final updatedAtRaw = decoded['updatedAt'];
    final createdContactIdRaw = decoded['createdContactId'];
    final deletedRaw = decoded['deletedSourceIds'];
    if (operationId is! String ||
        planFingerprint is! String ||
        phaseName is! String ||
        sourceCount is! int ||
        createdAtRaw is! String ||
        updatedAtRaw is! String ||
        (createdContactIdRaw != null && createdContactIdRaw is! String) ||
        deletedRaw is! List ||
        deletedRaw.any((value) => value is! String)) {
      throw StateError('merge_checkpoint_fields_invalid');
    }
    final phase = MergeExecutionPhase.values
        .where((value) => value.name == phaseName)
        .firstOrNull;
    final createdAt = DateTime.tryParse(createdAtRaw)?.toUtc();
    final updatedAt = DateTime.tryParse(updatedAtRaw)?.toUtc();
    if (phase == null || createdAt == null || updatedAt == null) {
      throw StateError('merge_checkpoint_values_invalid');
    }
    final checkpoint = MergeOperationCheckpoint(
      operationId: operationId.trim(),
      planFingerprint: planFingerprint.trim(),
      phase: phase,
      sourceCount: sourceCount,
      createdContactId: (createdContactIdRaw as String?)?.trim(),
      deletedSourceIds: deletedRaw.cast<String>(),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
    if (!checkpoint.isStructurallyValid) {
      throw StateError('merge_checkpoint_structurally_invalid');
    }
    return checkpoint;
  }

  Future<List<String>> _readCompletedUnlocked() async {
    final raw = await _preferences.getStringList(_completedKey) ?? <String>[];
    return raw
        .map((id) => id.trim())
        .where(
          (id) =>
              id.isNotEmpty && id.length <= MergePlan.maxOperationIdLength,
        )
        .toSet()
        .take(_maximumCompletedEntries)
        .toList(growable: true);
  }

  Future<void> _writeCheckpoint(MergeOperationCheckpoint checkpoint) async {
    if (!checkpoint.isStructurallyValid) {
      throw StateError('merge_checkpoint_invalid');
    }
    final encoded = jsonEncode(<String, Object?>{
      'schemaVersion': _schemaVersion,
      'operationId': checkpoint.operationId,
      'planFingerprint': checkpoint.planFingerprint,
      'phase': checkpoint.phase.name,
      'sourceCount': checkpoint.sourceCount,
      'createdContactId': checkpoint.createdContactId,
      'deletedSourceIds': checkpoint.deletedSourceIds,
      'createdAt': checkpoint.createdAt.toUtc().toIso8601String(),
      'updatedAt': checkpoint.updatedAt.toUtc().toIso8601String(),
    });
    if (encoded.length > _maximumCheckpointBytes) {
      throw StateError('merge_checkpoint_too_large');
    }
    await _preferences.setString(_checkpointKey, encoded);
  }

  Future<void> _enqueueWrite(Future<void> Function() action) {
    final completer = Completer<void>();
    _writeQueue = _writeQueue.catchError((Object _) {}).then((_) async {
      try {
        await action();
        completer.complete();
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
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

    try {
      if (await _journal.wasCompleted(plan.operationId)) {
        return _report(
          plan,
          startedAt,
          MergeExecutionStatus.blocked,
          'merge_operation_already_completed',
        );
      }

      final pending = await _journal.readPending();
      if (pending != null) {
        if (pending.operationId != plan.operationId) {
          return _report(
            plan,
            startedAt,
            MergeExecutionStatus.reconcileRequired,
            'merge_other_operation_pending',
            requiresReconcile: true,
          );
        }
        if (pending.planFingerprint != plan.fingerprint) {
          return _report(
            plan,
            startedAt,
            MergeExecutionStatus.reconcileRequired,
            'merge_pending_plan_mismatch',
            requiresReconcile: true,
          );
        }
        if (!pending.isPreMutation) {
          return _reconcilePending(plan, pending, startedAt);
        }
        await _journal.complete(plan.operationId);
      }

      if (!plan.hasStableOperationIdentity ||
          plan.displayNameFieldCount != 1 ||
          plan.hasUnresolvedConflicts ||
          plan.safetyBlockers.isNotEmpty) {
        return _report(
          plan,
          startedAt,
          MergeExecutionStatus.blocked,
          'merge_plan_preflight_invalid',
        );
      }

      await _journal.begin(plan);
      _progress(onProgress, MergeExecutionPhase.validatingPlan, 0.03);
      token.throwIfCancelled();

      _progress(onProgress, MergeExecutionPhase.rereadingSources, 0.10);
      var live = await _readAndValidateLive(plan);
      if (live == null) {
        return _finalizedReport(
          plan,
          startedAt,
          MergeExecutionStatus.preflightFailed,
          'merge_live_preflight_failed',
        );
      }

      _progress(onProgress, MergeExecutionPhase.validatingBackup, 0.18);
      var backup = await _validateBackup(plan, live);
      if (!_backupValidationMatches(plan, backup)) {
        return _finalizedReport(
          plan,
          startedAt,
          MergeExecutionStatus.preflightFailed,
          'merge_backup_preflight_failed',
        );
      }

      token.throwIfCancelled();
      _progress(
        onProgress,
        MergeExecutionPhase.requestingWritePermission,
        0.24,
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

      token.throwIfCancelled();
      live = await _readAndValidateLive(plan);
      if (live == null) {
        return _finalizedReport(
          plan,
          startedAt,
          MergeExecutionStatus.preflightFailed,
          'merge_source_changed_after_permission',
        );
      }
      backup = await _validateBackup(plan, live);
      if (!_backupValidationMatches(plan, backup)) {
        return _finalizedReport(
          plan,
          startedAt,
          MergeExecutionStatus.preflightFailed,
          'merge_backup_changed_before_write',
        );
      }

      token.throwIfCancelled();
      final finalLive = await _readAndValidateLive(plan);
      if (finalLive == null) {
        return _finalizedReport(
          plan,
          startedAt,
          MergeExecutionStatus.preflightFailed,
          'merge_source_changed_immediately_before_write',
        );
      }
      final finalBackup = await _validateBackup(plan, finalLive);
      if (!_backupValidationMatches(plan, finalBackup)) {
        return _finalizedReport(
          plan,
          startedAt,
          MergeExecutionStatus.preflightFailed,
          'merge_backup_changed_immediately_before_write',
        );
      }

      await _journal.checkpoint(
        operationId: plan.operationId,
        planFingerprint: plan.fingerprint,
        phase: MergeExecutionPhase.pendingBeforeMutation,
        sourceCount: plan.sourceContactIds.length,
      );
      return _mutate(plan, finalLive, startedAt, token, onProgress);
    } on _MergeCancelled {
      return _finalizedReport(
        plan,
        startedAt,
        MergeExecutionStatus.cancelled,
        'merge_cancelled',
      );
    } on TimeoutException catch (error) {
      return _report(
        plan,
        startedAt,
        MergeExecutionStatus.reconcileRequired,
        _safeTimeoutCode(error),
        requiresReconcile: true,
      );
    } on StateError catch (error) {
      return _report(
        plan,
        startedAt,
        MergeExecutionStatus.reconcileRequired,
        _safeStateErrorCode(error, fallback: 'merge_journal_failure'),
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

  Future<MergeBackupValidation> _validateBackup(
    MergePlan plan,
    Map<String, ContactRecord> live,
  ) {
    return _backupController.validateMergeRecords(
      live,
      expectedBackupId: plan.backupId,
      groupRevisionFingerprint: plan.groupRevisionFingerprint,
    );
  }

  bool _backupValidationMatches(
    MergePlan plan,
    MergeBackupValidation validation,
  ) {
    return validation.isValid &&
        validation.sourceContentValidated &&
        validation.backupId == plan.backupId &&
        validation.groupRevisionFingerprint == plan.groupRevisionFingerprint &&
        validation.sourceSnapshotFingerprint != null &&
        validation.isFullAccess;
  }

  Future<Map<String, ContactRecord>?> _readAndValidateLive(
    MergePlan plan,
  ) async {
    final live = await _withTimeout(
      _gateway.readContacts(plan.sourceContactIds),
      'merge_source_read_timeout',
    );
    if (live.length != plan.sourceContactIds.length ||
        !setEqualsStrings(live.keys.toSet(), plan.sourceContactIds.toSet())) {
      return null;
    }
    final validation = _validator.validate(
      plan,
      sourceRecords: live,
      expectedGroupFingerprint: plan.groupRevisionFingerprint,
      now: _clock(),
    );
    if (!validation.isValid) return null;
    return plan.matchesContext(
      currentScanRevision: plan.scanRevision,
      currentGroupFingerprint: plan.groupRevisionFingerprint,
      currentSourceRecords: live,
    )
        ? live
        : null;
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
    final skipped = <String>[...plan.retainedSourceIds];
    final restored = <String>[];
    try {
      _progress(onProgress, MergeExecutionPhase.creatingContact, 0.34);
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
        planFingerprint: plan.fingerprint,
        phase: MergeExecutionPhase.creatingContact,
        sourceCount: plan.sourceContactIds.length,
        createdContactId: createdId,
      );

      _progress(
        onProgress,
        MergeExecutionPhase.verifyingCreatedContact,
        0.46,
      );
      final createdValid = await _withTimeout(
        _gateway.verifyCreatedContact(createdId, plan),
        'merge_created_verification_timeout',
      );
      if (!createdValid) {
        final removed = await _rollbackCreated(createdId);
        if (removed) await _journal.complete(plan.operationId);
        return _report(
          plan,
          startedAt,
          removed
              ? MergeExecutionStatus.rollbackSucceeded
              : MergeExecutionStatus.rollbackFailed,
          removed
              ? 'merge_created_verification_failed_rolled_back'
              : 'merge_created_verification_failed_rollback_failed',
          createdContactId: removed ? null : createdId,
          skippedSourceIds: skipped,
          requiresReconcile: !removed,
        );
      }

      if (plan.executionMode == MergeExecutionMode.copyOnly) {
        final finalValid = await _verifyFinalState(
          plan: plan,
          live: live,
          createdId: createdId,
          deleted: const <String>{},
          retained: plan.sourceContactIds.toSet(),
        );
        if (!finalValid) {
          return _report(
            plan,
            startedAt,
            MergeExecutionStatus.reconcileRequired,
            'merge_copy_final_state_unknown',
            createdContactId: createdId,
            skippedSourceIds: plan.sourceContactIds,
            requiresReconcile: true,
          );
        }
        await _journal.complete(plan.operationId);
        _progress(onProgress, MergeExecutionPhase.completed, 1);
        return _report(
          plan,
          startedAt,
          MergeExecutionStatus.success,
          null,
          createdContactId: createdId,
          skippedSourceIds: plan.sourceContactIds,
        );
      }

      _progress(
        onProgress,
        MergeExecutionPhase.deletingSources,
        0.56,
        total: plan.deletionTargetIds.length,
      );
      for (var index = 0; index < plan.deletionTargetIds.length; index++) {
        final id = plan.deletionTargetIds[index];
        final source = live[id];
        if (source == null || !source.capabilities.isFullyWritable) {
          return _rollbackMutation(
            plan: plan,
            live: live,
            startedAt: startedAt,
            createdId: createdId,
            deleted: deleted,
            skipped: skipped,
            restored: restored,
            errorCode: 'merge_delete_target_not_writable',
            onProgress: onProgress,
          );
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
            planFingerprint: plan.fingerprint,
            phase: MergeExecutionPhase.deletingSources,
            sourceCount: plan.sourceContactIds.length,
            createdContactId: createdId,
            deletedSourceIds: deleted,
          );
        } on TimeoutException catch (error) {
          return _report(
            plan,
            startedAt,
            MergeExecutionStatus.reconcileRequired,
            _safeTimeoutCode(error),
            createdContactId: createdId,
            deletedSourceIds: deleted,
            skippedSourceIds: skipped,
            requiresReconcile: true,
          );
        } on Object {
          return _rollbackMutation(
            plan: plan,
            live: live,
            startedAt: startedAt,
            createdId: createdId,
            deleted: deleted,
            skipped: skipped,
            restored: restored,
            errorCode: 'merge_delete_failed',
            onProgress: onProgress,
          );
        }
        _progress(
          onProgress,
          MergeExecutionPhase.deletingSources,
          0.56 + 0.25 * ((index + 1) / plan.deletionTargetIds.length),
          processed: index + 1,
          total: plan.deletionTargetIds.length,
        );
      }

      await _journal.checkpoint(
        operationId: plan.operationId,
        planFingerprint: plan.fingerprint,
        phase: MergeExecutionPhase.verifyingFinalState,
        sourceCount: plan.sourceContactIds.length,
        createdContactId: createdId,
        deletedSourceIds: deleted,
      );
      _progress(onProgress, MergeExecutionPhase.verifyingFinalState, 0.9);
      final finalValid = await _verifyFinalState(
        plan: plan,
        live: live,
        createdId: createdId,
        deleted: deleted.toSet(),
        retained: plan.retainedSourceIds.toSet(),
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

      await _journal.complete(plan.operationId);
      _progress(onProgress, MergeExecutionPhase.completed, 1);
      return _report(
        plan,
        startedAt,
        MergeExecutionStatus.success,
        null,
        createdContactId: createdId,
        deletedSourceIds: deleted,
        skippedSourceIds: skipped,
      );
    } on TimeoutException catch (error) {
      return _report(
        plan,
        startedAt,
        MergeExecutionStatus.reconcileRequired,
        _safeTimeoutCode(error),
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

  Future<MergeReport> _rollbackMutation({
    required MergePlan plan,
    required Map<String, ContactRecord> live,
    required DateTime startedAt,
    required String createdId,
    required List<String> deleted,
    required List<String> skipped,
    required List<String> restored,
    required String errorCode,
    required void Function(MergeProgress progress)? onProgress,
  }) async {
    final sourcesRestored = await _restoreDeleted(
      live,
      deleted,
      restored,
      onProgress,
    );
    final createdRemoved = await _rollbackCreated(createdId);
    final rollbackComplete = sourcesRestored && createdRemoved;
    if (rollbackComplete) await _journal.complete(plan.operationId);
    return _report(
      plan,
      startedAt,
      rollbackComplete
          ? MergeExecutionStatus.rollbackSucceeded
          : MergeExecutionStatus.rollbackFailed,
      rollbackComplete
          ? '${errorCode}_rolled_back'
          : '${errorCode}_rollback_incomplete',
      createdContactId: createdRemoved ? null : createdId,
      deletedSourceIds: deleted,
      skippedSourceIds: skipped,
      restoredSourceIds: restored,
      requiresReconcile: !rollbackComplete,
    );
  }

  Future<MergeReport> _reconcilePending(
    MergePlan plan,
    MergeOperationCheckpoint checkpoint,
    DateTime startedAt,
  ) async {
    final createdId = checkpoint.createdContactId;
    final createdExists = createdId != null &&
        await _withTimeout(
          _gateway.contactExists(createdId),
          'merge_reconcile_created_timeout',
        );
    final sourceExists = <String, bool>{};
    for (final id in plan.sourceContactIds) {
      sourceExists[id] = await _withTimeout(
        _gateway.contactExists(id),
        'merge_reconcile_source_timeout',
      );
    }

    if (!createdExists && sourceExists.values.every((exists) => exists)) {
      await _journal.complete(plan.operationId);
      return _report(
        plan,
        startedAt,
        MergeExecutionStatus.rollbackSucceeded,
        'merge_reconcile_proved_rolled_back',
      );
    }

    if (createdExists && createdId != null) {
      final createdValid = await _withTimeout(
        _gateway.verifyCreatedContact(createdId, plan),
        'merge_reconcile_verify_created_timeout',
      );
      final expectedDeleted = checkpoint.deletedSourceIds.toSet();
      final deletedAbsent =
          expectedDeleted.every((id) => sourceExists[id] == false);
      final retainedPresent = plan.retainedSourceIds.every(
        (id) => sourceExists[id] == true,
      );
      final undeletedTargetsPresent = plan.deletionTargetIds
          .where((id) => !expectedDeleted.contains(id))
          .every((id) => sourceExists[id] == true);
      final targetSetValid = expectedDeleted.every(
        plan.deletionTargetIds.contains,
      );
      final finalPhase =
          checkpoint.phase == MergeExecutionPhase.verifyingFinalState;
      final copyOnlyFinal = plan.executionMode == MergeExecutionMode.copyOnly &&
          expectedDeleted.isEmpty &&
          sourceExists.values.every((exists) => exists);
      if (createdValid &&
          targetSetValid &&
          deletedAbsent &&
          retainedPresent &&
          undeletedTargetsPresent &&
          (finalPhase || copyOnlyFinal)) {
        await _journal.complete(plan.operationId);
        return _report(
          plan,
          startedAt,
          MergeExecutionStatus.success,
          null,
          createdContactId: createdId,
          deletedSourceIds: checkpoint.deletedSourceIds,
          skippedSourceIds: plan.retainedSourceIds,
        );
      }
    }

    return _report(
      plan,
      startedAt,
      MergeExecutionStatus.reconcileRequired,
      'merge_pending_operation_requires_reconcile',
      createdContactId: createdExists ? createdId : null,
      deletedSourceIds: checkpoint.deletedSourceIds,
      skippedSourceIds: plan.retainedSourceIds,
      requiresReconcile: true,
    );
  }

  Future<bool> _verifyFinalState({
    required MergePlan plan,
    required Map<String, ContactRecord> live,
    required String createdId,
    required Set<String> deleted,
    required Set<String> retained,
  }) async {
    if (!await _withTimeout(
      _gateway.verifyCreatedContact(createdId, plan),
      'merge_final_created_timeout',
    )) {
      return false;
    }
    if (!setEqualsStrings(deleted, plan.deletionTargetIds.toSet()) &&
        plan.isDestructive) {
      return false;
    }
    for (final id in deleted) {
      if (await _withTimeout(
        _gateway.contactExists(id),
        'merge_final_deleted_timeout',
      )) {
        return false;
      }
    }
    for (final id in retained) {
      if (!await _withTimeout(
        _gateway.contactExists(id),
        'merge_final_retained_timeout',
      )) {
        return false;
      }
      if (!live.containsKey(id)) return false;
    }
    return true;
  }

  Future<bool> _rollbackCreated(String id) async {
    try {
      await _withTimeout(
        _gateway.deleteContact(id),
        'merge_rollback_timeout',
      );
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
      _progress(
        onProgress,
        MergeExecutionPhase.restoringSources,
        0.72 + 0.12 * ((deleted.length - index) / deleted.length),
        processed: deleted.length - index,
        total: deleted.length,
      );
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

  String _safeTimeoutCode(TimeoutException error) {
    final message = error.message;
    if (message != null &&
        RegExp(r'^[a-z0-9_]{1,96}$').hasMatch(message)) {
      return message;
    }
    return 'merge_native_timeout_unknown_state';
  }

  String _safeStateErrorCode(StateError error, {required String fallback}) {
    final message = error.message;
    if (message is String &&
        RegExp(r'^[a-z0-9_]{1,96}$').hasMatch(message)) {
      return message;
    }
    return fallback;
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

extension _FirstOrNullMergeJournal<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
