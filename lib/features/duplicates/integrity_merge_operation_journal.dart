import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/contacts/contact_models.dart';
import 'merge_engine_service.dart';
import 'merge_plan.dart';

class IntegrityMergeOperationJournal implements MergeOperationJournal {
  static const String _checkpointKey = 'merge_operation_checkpoint_v3';
  static const String _legacyCheckpointKey = 'merge_operation_checkpoint_v2';
  static const String _completedKey = 'merge_operation_completed_v2';
  static const String _legacyCompletedKey = 'merge_operation_completed_v1';
  static const int _schemaVersion = 3;
  static const int _writerVersion = 1;
  static const int _maxCheckpointBytes = 12288;
  static const int _maxCompletedBytes = 32768;
  static const int _maxCompletedEntries = 128;
  static const Duration _futureTolerance = Duration(minutes: 5);

  final SharedPreferencesAsync _preferences;
  final DateTime Function() _clock;
  Future<void> _writeQueue = Future<void>.value();

  IntegrityMergeOperationJournal({
    SharedPreferencesAsync? preferences,
    DateTime Function()? clock,
  })  : _preferences = preferences ?? SharedPreferencesAsync(),
        _clock = clock ?? DateTime.now;

  @override
  Future<void> begin(MergePlan plan) async {
    _validatePlanIdentity(plan);
    await _afterWrites();
    final pending = await _readPendingUnlocked();
    if (pending != null) {
      throw StateError('merge_checkpoint_already_exists');
    }
    if (await _wasCompletedUnlocked(plan.operationId)) {
      throw StateError('merge_operation_already_completed');
    }
    final now = _safeNow();
    final checkpoint = MergeOperationCheckpoint(
      operationId: plan.operationId,
      planFingerprint: plan.fingerprint,
      phase: MergeExecutionPhase.validatingPlan,
      sourceCount: plan.sourceContactIds.length,
      createdAt: now,
      updatedAt: now,
    );
    await _enqueueWrite(() => _writeCheckpointUnlocked(checkpoint));
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
    final id = _validOperationId(operationId);
    final fingerprint = _validFingerprint(planFingerprint);
    if (sourceCount < 2 || sourceCount > 10000) {
      throw StateError('merge_checkpoint_source_count_invalid');
    }
    await _afterWrites();
    final current = await _readPendingUnlocked();
    if (current == null || current.operationId != id) {
      throw StateError('merge_checkpoint_missing');
    }
    if (current.planFingerprint != fingerprint ||
        current.sourceCount != sourceCount) {
      throw StateError('merge_checkpoint_identity_mismatch');
    }
    if (phase.index < current.phase.index) {
      throw StateError('merge_checkpoint_phase_regressed');
    }

    final created = _normalizeOptionalId(createdContactId);
    if (current.createdContactId != null &&
        created != null &&
        current.createdContactId != created) {
      throw StateError('merge_checkpoint_created_id_changed');
    }
    if (current.createdContactId != null && created == null) {
      throw StateError('merge_checkpoint_created_id_regressed');
    }
    final effectiveCreated = created ?? current.createdContactId;

    final deleted = _normalizeDeleted(deletedSourceIds, sourceCount);
    if (!deleted.containsAll(current.deletedSourceIds)) {
      throw StateError('merge_checkpoint_deleted_set_regressed');
    }
    _validatePhaseState(
      phase,
      createdContactId: effectiveCreated,
      deletedSourceIds: deleted,
    );

    final now = _safeNow();
    final updatedAt = now.isBefore(current.updatedAt) ? current.updatedAt : now;
    final next = MergeOperationCheckpoint(
      operationId: id,
      planFingerprint: fingerprint,
      phase: phase,
      sourceCount: sourceCount,
      createdContactId: effectiveCreated,
      deletedSourceIds: deleted,
      createdAt: current.createdAt,
      updatedAt: updatedAt,
    );
    await _enqueueWrite(() => _writeCheckpointUnlocked(next));
  }

  @override
  Future<void> complete(String operationId) async {
    final id = _validOperationId(operationId);
    await _enqueueWrite(() async {
      final pending = await _readPendingUnlocked();
      if (pending != null && pending.operationId != id) {
        throw StateError('merge_checkpoint_other_operation_pending');
      }
      final completed = await _readCompletedUnlocked();
      final planFingerprint = pending?.planFingerprint ??
          completed
              .where((entry) => entry.operationId == id)
              .map((entry) => entry.planFingerprint)
              .firstOrNull ??
          'unknown';
      final entry = _CompletedOperation(
        operationId: id,
        planFingerprint: planFingerprint,
        completedAt: _safeNow(),
      );
      completed.removeWhere((item) => item.operationId == id);
      completed.insert(0, entry);
      if (completed.length > _maxCompletedEntries) {
        completed.removeRange(_maxCompletedEntries, completed.length);
      }
      await _writeCompletedUnlocked(completed);
      if (pending != null) {
        await _preferences.remove(_checkpointKey);
        await _preferences.remove(_legacyCheckpointKey);
      }
    });
  }

  @override
  Future<MergeOperationCheckpoint?> readPending() async {
    await _afterWrites();
    return _readPendingUnlocked();
  }

  @override
  Future<bool> wasCompleted(String operationId) async {
    final id = operationId.trim();
    if (id.isEmpty || id.length > MergePlan.maxOperationIdLength) return false;
    await _afterWrites();
    return _wasCompletedUnlocked(id);
  }

  Future<MergeOperationCheckpoint?> _readPendingUnlocked() async {
    final raw = await _preferences.getString(_checkpointKey);
    if (raw != null && raw.isNotEmpty) {
      return _parseV3Checkpoint(raw);
    }
    final legacy = await _preferences.getString(_legacyCheckpointKey);
    if (legacy == null || legacy.isEmpty) return null;
    return _parseLegacyCheckpoint(legacy);
  }

  MergeOperationCheckpoint _parseV3Checkpoint(String raw) {
    if (raw.length > _maxCheckpointBytes) {
      throw StateError('merge_checkpoint_too_large');
    }
    final decoded = _decodeMap(raw, 'merge_checkpoint_corrupt');
    if (decoded['schemaVersion'] != _schemaVersion ||
        decoded['writerVersion'] != _writerVersion) {
      throw StateError('merge_checkpoint_schema_invalid');
    }
    final payloadRaw = decoded['payload'];
    final checksum = decoded['checksum'];
    if (payloadRaw is! Map || checksum is! String) {
      throw StateError('merge_checkpoint_envelope_invalid');
    }
    final payload = _stringMap(payloadRaw, 'merge_checkpoint_payload_invalid');
    final expected = _checksum(payload, namespace: 'merge-checkpoint');
    if (checksum != expected) {
      throw StateError('merge_checkpoint_checksum_invalid');
    }
    return _parseCheckpointPayload(payload);
  }

  MergeOperationCheckpoint _parseLegacyCheckpoint(String raw) {
    if (raw.length > _maxCheckpointBytes) {
      throw StateError('merge_legacy_checkpoint_too_large');
    }
    final decoded = _decodeMap(raw, 'merge_legacy_checkpoint_corrupt');
    if (decoded['schemaVersion'] != 2) {
      throw StateError('merge_legacy_checkpoint_schema_invalid');
    }
    return _parseCheckpointPayload(decoded);
  }

  MergeOperationCheckpoint _parseCheckpointPayload(Map<String, Object?> map) {
    final operationId = map['operationId'];
    final planFingerprint = map['planFingerprint'];
    final phaseName = map['phase'];
    final sourceCount = map['sourceCount'];
    final createdAtRaw = map['createdAt'];
    final updatedAtRaw = map['updatedAt'];
    final createdContactIdRaw = map['createdContactId'];
    final deletedRaw = map['deletedSourceIds'];
    if (operationId is! String ||
        planFingerprint is! String ||
        phaseName is! String ||
        sourceCount is! int ||
        createdAtRaw is! String ||
        updatedAtRaw is! String ||
        (createdContactIdRaw != null && createdContactIdRaw is! String) ||
        deletedRaw is! List ||
        deletedRaw.length > sourceCount ||
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
    final now = _safeNow();
    if (createdAt.isAfter(now.add(_futureTolerance)) ||
        updatedAt.isAfter(now.add(_futureTolerance))) {
      throw StateError('merge_checkpoint_timestamp_future');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw StateError('merge_checkpoint_timestamp_regressed');
    }

    final checkpoint = MergeOperationCheckpoint(
      operationId: _validOperationId(operationId),
      planFingerprint: _validFingerprint(planFingerprint),
      phase: phase,
      sourceCount: sourceCount,
      createdContactId: _normalizeOptionalId(createdContactIdRaw as String?),
      deletedSourceIds: deletedRaw.cast<String>(),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
    if (!checkpoint.isStructurallyValid) {
      throw StateError('merge_checkpoint_structurally_invalid');
    }
    _validatePhaseState(
      checkpoint.phase,
      createdContactId: checkpoint.createdContactId,
      deletedSourceIds: checkpoint.deletedSourceIds.toSet(),
    );
    return checkpoint;
  }

  Future<List<_CompletedOperation>> _readCompletedUnlocked() async {
    final raw = await _preferences.getString(_completedKey);
    if (raw != null && raw.isNotEmpty) {
      if (raw.length > _maxCompletedBytes) {
        throw StateError('merge_completed_too_large');
      }
      final decoded = _decodeMap(raw, 'merge_completed_corrupt');
      if (decoded['schemaVersion'] != _schemaVersion ||
          decoded['writerVersion'] != _writerVersion ||
          decoded['entries'] is! List) {
        throw StateError('merge_completed_schema_invalid');
      }
      final entries = <_CompletedOperation>[];
      for (final rawEntry in (decoded['entries'] as List)) {
        if (rawEntry is! Map) {
          throw StateError('merge_completed_entry_invalid');
        }
        final map = _stringMap(rawEntry, 'merge_completed_entry_invalid');
        final checksum = map['checksum'];
        if (checksum is! String) {
          throw StateError('merge_completed_checksum_missing');
        }
        final payload = <String, Object?>{
          'operationId': map['operationId'],
          'planFingerprint': map['planFingerprint'],
          'completedAt': map['completedAt'],
        };
        if (checksum != _checksum(payload, namespace: 'merge-completed')) {
          throw StateError('merge_completed_checksum_invalid');
        }
        final entry = _CompletedOperation.tryParse(payload);
        if (entry == null) {
          throw StateError('merge_completed_entry_invalid');
        }
        entries.add(entry);
      }
      return _dedupeCompleted(entries);
    }

    final legacy = await _preferences.getStringList(_legacyCompletedKey) ??
        const <String>[];
    final now = _safeNow();
    return _dedupeCompleted(
      legacy
          .map((id) => id.trim())
          .where(
            (id) =>
                id.isNotEmpty && id.length <= MergePlan.maxOperationIdLength,
          )
          .map(
            (id) => _CompletedOperation(
              operationId: id,
              planFingerprint: 'legacy',
              completedAt: now,
            ),
          ),
    );
  }

  Future<void> _writeCheckpointUnlocked(
    MergeOperationCheckpoint checkpoint,
  ) async {
    if (!checkpoint.isStructurallyValid) {
      throw StateError('merge_checkpoint_invalid');
    }
    _validatePhaseState(
      checkpoint.phase,
      createdContactId: checkpoint.createdContactId,
      deletedSourceIds: checkpoint.deletedSourceIds.toSet(),
    );
    final payload = <String, Object?>{
      'operationId': checkpoint.operationId,
      'planFingerprint': checkpoint.planFingerprint,
      'phase': checkpoint.phase.name,
      'sourceCount': checkpoint.sourceCount,
      'createdContactId': checkpoint.createdContactId,
      'deletedSourceIds': checkpoint.deletedSourceIds,
      'createdAt': checkpoint.createdAt.toUtc().toIso8601String(),
      'updatedAt': checkpoint.updatedAt.toUtc().toIso8601String(),
    };
    final envelope = <String, Object?>{
      'schemaVersion': _schemaVersion,
      'writerVersion': _writerVersion,
      'payload': payload,
      'checksum': _checksum(payload, namespace: 'merge-checkpoint'),
    };
    final encoded = jsonEncode(envelope);
    if (encoded.length > _maxCheckpointBytes) {
      throw StateError('merge_checkpoint_too_large');
    }
    await _preferences.setString(_checkpointKey, encoded);
    await _preferences.remove(_legacyCheckpointKey);
  }

  Future<void> _writeCompletedUnlocked(
    List<_CompletedOperation> entries,
  ) async {
    final encodedEntries = entries.take(_maxCompletedEntries).map((entry) {
      final payload = <String, Object?>{
        'operationId': entry.operationId,
        'planFingerprint': entry.planFingerprint,
        'completedAt': entry.completedAt.toUtc().toIso8601String(),
      };
      return <String, Object?>{
        ...payload,
        'checksum': _checksum(payload, namespace: 'merge-completed'),
      };
    }).toList(growable: false);
    final envelope = <String, Object?>{
      'schemaVersion': _schemaVersion,
      'writerVersion': _writerVersion,
      'entries': encodedEntries,
    };
    final encoded = jsonEncode(envelope);
    if (encoded.length > _maxCompletedBytes) {
      throw StateError('merge_completed_too_large');
    }
    await _preferences.setString(_completedKey, encoded);
    await _preferences.remove(_legacyCompletedKey);
  }

  Future<bool> _wasCompletedUnlocked(String operationId) async =>
      (await _readCompletedUnlocked())
          .any((entry) => entry.operationId == operationId);

  void _validatePlanIdentity(MergePlan plan) {
    _validOperationId(plan.operationId);
    _validFingerprint(plan.fingerprint);
    if (plan.sourceContactIds.length < 2 ||
        plan.sourceContactIds.length > 10000) {
      throw StateError('merge_operation_source_count_invalid');
    }
  }

  void _validatePhaseState(
    MergeExecutionPhase phase, {
    required String? createdContactId,
    required Set<String> deletedSourceIds,
  }) {
    final preMutation = phase.index <=
        MergeExecutionPhase.pendingBeforeMutation.index;
    if (preMutation &&
        (createdContactId != null || deletedSourceIds.isNotEmpty)) {
      throw StateError('merge_checkpoint_premutation_has_mutation');
    }
    final requiresCreated = phase == MergeExecutionPhase.verifyingCreatedContact ||
        phase == MergeExecutionPhase.deletingSources ||
        phase == MergeExecutionPhase.restoringSources ||
        phase == MergeExecutionPhase.verifyingFinalState ||
        phase == MergeExecutionPhase.completed;
    if (requiresCreated && createdContactId == null) {
      throw StateError('merge_checkpoint_created_id_missing');
    }
    if (phase.index < MergeExecutionPhase.deletingSources.index &&
        deletedSourceIds.isNotEmpty) {
      throw StateError('merge_checkpoint_deleted_too_early');
    }
  }

  Set<String> _normalizeDeleted(Iterable<String> values, int sourceCount) {
    final list = values.map((id) => id.trim()).where((id) => id.isNotEmpty);
    final result = <String>{};
    for (final id in list) {
      if (id.length > 256) {
        throw StateError('merge_checkpoint_deleted_id_invalid');
      }
      result.add(id);
    }
    if (result.length > sourceCount) {
      throw StateError('merge_checkpoint_deleted_set_invalid');
    }
    return result;
  }

  String _validOperationId(String value) {
    final id = value.trim();
    if (id.length < 8 ||
        id.length > MergePlan.maxOperationIdLength ||
        !RegExp(r'^[a-z][a-z0-9_-]+$').hasMatch(id)) {
      throw StateError('merge_operation_id_invalid');
    }
    return id;
  }

  String _validFingerprint(String value) {
    final fingerprint = value.trim();
    if (fingerprint.isEmpty ||
        fingerprint.length > 128 ||
        !RegExp(r'^[a-z0-9-]+$').hasMatch(fingerprint)) {
      throw StateError('merge_plan_fingerprint_invalid');
    }
    return fingerprint;
  }

  String? _normalizeOptionalId(String? value) {
    if (value == null) return null;
    final id = value.trim();
    if (id.isEmpty || id.length > 256) {
      throw StateError('merge_created_contact_id_invalid');
    }
    return id;
  }

  DateTime _safeNow() => _clock().toUtc();

  String _checksum(Map<String, Object?> payload, {required String namespace}) {
    final canonicalEntries = payload.entries.toList(growable: true)
      ..sort((left, right) => left.key.compareTo(right.key));
    return stableOpaqueId(
      canonicalEntries.map((entry) => '${entry.key}=${jsonEncode(entry.value)}'),
      namespace: namespace,
    );
  }

  Map<String, Object?> _decodeMap(String raw, String errorCode) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on Object {
      throw StateError(errorCode);
    }
    if (decoded is! Map) throw StateError(errorCode);
    return _stringMap(decoded, errorCode);
  }

  Map<String, Object?> _stringMap(Map raw, String errorCode) {
    final result = <String, Object?>{};
    for (final entry in raw.entries) {
      if (entry.key is! String) throw StateError(errorCode);
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  List<_CompletedOperation> _dedupeCompleted(
    Iterable<_CompletedOperation> entries,
  ) {
    final byId = <String, _CompletedOperation>{};
    for (final entry in entries) {
      final existing = byId[entry.operationId];
      if (existing == null || entry.completedAt.isAfter(existing.completedAt)) {
        byId[entry.operationId] = entry;
      }
    }
    final result = byId.values.toList(growable: true)
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    if (result.length > _maxCompletedEntries) {
      result.removeRange(_maxCompletedEntries, result.length);
    }
    return result;
  }

  Future<void> _afterWrites() async {
    try {
      await _writeQueue;
    } on Object {
      // Read-ul va verifica continutul persistent, nu eroarea unei scrieri vechi.
    }
  }

  Future<void> _enqueueWrite(Future<void> Function() action) {
    final completer = Completer<void>();
    _writeQueue = _writeQueue.catchError((Object _) {}).then((_) async {
      try {
        await action();
        if (!completer.isCompleted) completer.complete();
      } on Object catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      }
    });
    return completer.future;
  }
}

class _CompletedOperation {
  final String operationId;
  final String planFingerprint;
  final DateTime completedAt;

  const _CompletedOperation({
    required this.operationId,
    required this.planFingerprint,
    required this.completedAt,
  });

  static _CompletedOperation? tryParse(Map<String, Object?> map) {
    final operationId = map['operationId'];
    final planFingerprint = map['planFingerprint'];
    final completedAtRaw = map['completedAt'];
    if (operationId is! String ||
        planFingerprint is! String ||
        completedAtRaw is! String) {
      return null;
    }
    final completedAt = DateTime.tryParse(completedAtRaw)?.toUtc();
    if (operationId.trim().isEmpty ||
        operationId.length > MergePlan.maxOperationIdLength ||
        planFingerprint.trim().isEmpty ||
        planFingerprint.length > 128 ||
        completedAt == null) {
      return null;
    }
    return _CompletedOperation(
      operationId: operationId.trim(),
      planFingerprint: planFingerprint.trim(),
      completedAt: completedAt,
    );
  }
}

extension _FirstOrNullIntegrityJournal<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
