import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/contacts/contact_models.dart';
import '../duplicates/merge_engine_service.dart';
import '../restore/restore_service.dart';

enum OperationHistoryType { scan, merge, restore, undo }
enum OperationHistoryOutcome { success, partial, blocked, failed, cancelled, reconcile }

class OperationHistoryEntry {
  static const int maxUndoTargetIds = 500;
  static const int maxOpaqueIdLength = 256;

  final String operationId;
  final OperationHistoryType type;
  final OperationHistoryOutcome outcome;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int sourceCount;
  final int changedCount;
  final int skippedCount;
  final String? backupId;
  final String? safetyBackupId;
  final String resultFingerprint;
  final bool canUndo;
  final String? undoBackupId;
  final List<String> undoTargetIds;
  final String? createdContactId;
  final String? createdContactFingerprint;
  final String? parentOperationId;

  OperationHistoryEntry({
    required this.operationId,
    required this.type,
    required this.outcome,
    required this.startedAt,
    required this.finishedAt,
    required this.sourceCount,
    required this.changedCount,
    required this.skippedCount,
    this.backupId,
    this.safetyBackupId,
    required this.resultFingerprint,
    required this.canUndo,
    this.undoBackupId,
    Iterable<String> undoTargetIds = const <String>[],
    this.createdContactId,
    this.createdContactFingerprint,
    this.parentOperationId,
  })  : undoTargetIds = List<String>.unmodifiable(
          undoTargetIds
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort(),
        ),
        assert(sourceCount >= 0),
        assert(changedCount >= 0),
        assert(skippedCount >= 0);

  bool get hasVerifiedMergeUndoIdentity =>
      type == OperationHistoryType.merge &&
      createdContactId != null &&
      createdContactId!.trim().isNotEmpty &&
      createdContactFingerprint != null &&
      createdContactFingerprint!.trim().isNotEmpty;

  bool get isStructurallyValid =>
      operationId.trim().isNotEmpty &&
      operationId.length <= 128 &&
      !finishedAt.isBefore(startedAt) &&
      sourceCount >= 0 &&
      changedCount >= 0 &&
      skippedCount >= 0 &&
      resultFingerprint.trim().isNotEmpty &&
      undoTargetIds.length <= maxUndoTargetIds &&
      undoTargetIds.every(
        (id) => id.isNotEmpty && id.length <= maxOpaqueIdLength,
      ) &&
      (createdContactId == null ||
          (createdContactId!.trim().isNotEmpty &&
              createdContactId!.length <= maxOpaqueIdLength)) &&
      (createdContactFingerprint == null ||
          (createdContactFingerprint!.trim().isNotEmpty &&
              createdContactFingerprint!.length <= 128)) &&
      (parentOperationId == null ||
          (parentOperationId!.isNotEmpty && parentOperationId!.length <= 128)) &&
      (!canUndo ||
          (undoBackupId != null &&
              undoBackupId!.isNotEmpty &&
              undoTargetIds.isNotEmpty &&
              (type != OperationHistoryType.merge ||
                  hasVerifiedMergeUndoIdentity)));

  Set<String> get protectedBackupIds => <String>{
        if (canUndo && undoBackupId != null && undoBackupId!.isNotEmpty)
          undoBackupId!,
        if (canUndo && safetyBackupId != null && safetyBackupId!.isNotEmpty)
          safetyBackupId!,
      };

  OperationHistoryEntry consumeUndo() {
    if (!canUndo) return this;
    return OperationHistoryEntry(
      operationId: operationId,
      type: type,
      outcome: outcome,
      startedAt: startedAt,
      finishedAt: finishedAt,
      sourceCount: sourceCount,
      changedCount: changedCount,
      skippedCount: skippedCount,
      backupId: backupId,
      safetyBackupId: safetyBackupId,
      resultFingerprint: resultFingerprint,
      canUndo: false,
      createdContactId: createdContactId,
      createdContactFingerprint: createdContactFingerprint,
      parentOperationId: parentOperationId,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'operationId': operationId,
        'type': type.name,
        'outcome': outcome.name,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'finishedAt': finishedAt.toUtc().toIso8601String(),
        'sourceCount': sourceCount,
        'changedCount': changedCount,
        'skippedCount': skippedCount,
        'backupId': backupId,
        'safetyBackupId': safetyBackupId,
        'resultFingerprint': resultFingerprint,
        'canUndo': canUndo,
        'undoBackupId': undoBackupId,
        'undoTargetIds': undoTargetIds,
        'createdContactId': createdContactId,
        'createdContactFingerprint': createdContactFingerprint,
        'parentOperationId': parentOperationId,
      };

  static OperationHistoryEntry? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = <String, Object?>{};
    for (final entry in raw.entries) {
      if (entry.key is! String) return null;
      map[entry.key as String] = entry.value;
    }
    final operationId = map['operationId'];
    final typeName = map['type'];
    final outcomeName = map['outcome'];
    final startedRaw = map['startedAt'];
    final finishedRaw = map['finishedAt'];
    final sourceCount = map['sourceCount'];
    final changedCount = map['changedCount'];
    final skippedCount = map['skippedCount'];
    final resultFingerprint = map['resultFingerprint'];
    final canUndoRaw = map['canUndo'];
    if (operationId is! String ||
        typeName is! String ||
        outcomeName is! String ||
        startedRaw is! String ||
        finishedRaw is! String ||
        sourceCount is! int ||
        changedCount is! int ||
        skippedCount is! int ||
        resultFingerprint is! String ||
        canUndoRaw is! bool) {
      return null;
    }
    final type = OperationHistoryType.values
        .where((value) => value.name == typeName)
        .firstOrNull;
    final outcome = OperationHistoryOutcome.values
        .where((value) => value.name == outcomeName)
        .firstOrNull;
    final startedAt = DateTime.tryParse(startedRaw)?.toUtc();
    final finishedAt = DateTime.tryParse(finishedRaw)?.toUtc();
    if (type == null || outcome == null || startedAt == null || finishedAt == null) {
      return null;
    }

    String? optionalString(String key, {int maxLength = 128}) {
      final value = map[key];
      if (value == null) return null;
      if (value is! String || value.length > maxLength) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final rawTargets = map['undoTargetIds'];
    final targets = <String>[];
    if (rawTargets != null) {
      if (rawTargets is! List ||
          rawTargets.length > maxUndoTargetIds ||
          rawTargets.any((value) =>
              value is! String || value.length > maxOpaqueIdLength)) {
        return null;
      }
      targets.addAll(
        rawTargets
            .cast<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      );
    }

    final createdContactId = optionalString(
      'createdContactId',
      maxLength: maxOpaqueIdLength,
    );
    final createdFingerprint = optionalString('createdContactFingerprint');
    final hasMergeIdentity = type != OperationHistoryType.merge ||
        (createdContactId != null && createdFingerprint != null);
    final effectiveCanUndo =
        canUndoRaw && targets.isNotEmpty && hasMergeIdentity;
    final entry = OperationHistoryEntry(
      operationId: operationId.trim(),
      type: type,
      outcome: outcome,
      startedAt: startedAt,
      finishedAt: finishedAt,
      sourceCount: sourceCount,
      changedCount: changedCount,
      skippedCount: skippedCount,
      backupId: optionalString('backupId'),
      safetyBackupId: optionalString('safetyBackupId'),
      resultFingerprint: resultFingerprint.trim(),
      canUndo: effectiveCanUndo,
      undoBackupId:
          effectiveCanUndo ? optionalString('undoBackupId') : null,
      undoTargetIds: effectiveCanUndo ? targets : const <String>[],
      createdContactId: createdContactId,
      createdContactFingerprint: createdFingerprint,
      parentOperationId: optionalString('parentOperationId'),
    );
    return entry.isStructurallyValid ? entry : null;
  }
}

abstract interface class OperationHistoryRepository {
  Future<List<OperationHistoryEntry>> list();
  Future<OperationHistoryEntry?> find(String operationId);
  Future<void> append(OperationHistoryEntry entry);
  Future<bool> markUndoConsumed(String operationId);
  Future<bool> delete(String operationId);
  Future<void> clear({bool preserveUndoable = true});
  Future<Set<String>> protectedBackupIds();
}

class PreferencesOperationHistoryRepository implements OperationHistoryRepository {
  static const String _key = 'operation_history_v1';
  static const int _schemaVersion = 3;
  static const Set<int> _supportedSchemaVersions = <int>{1, 2, 3};
  static const int _maximumBytes = 512 * 1024;

  final SharedPreferencesAsync _preferences;
  final int maxEntries;
  final Duration maxAge;
  final DateTime Function() _clock;
  Future<void> _writeQueue = Future<void>.value();

  PreferencesOperationHistoryRepository({
    SharedPreferencesAsync? preferences,
    this.maxEntries = 100,
    this.maxAge = const Duration(days: 90),
    DateTime Function()? clock,
  })  : assert(maxEntries > 0 && maxEntries <= 1000),
        assert(!maxAge.isNegative),
        _preferences = preferences ?? SharedPreferencesAsync(),
        _clock = clock ?? DateTime.now;

  @override
  Future<List<OperationHistoryEntry>> list() async {
    final read = await _readEnvelope();
    final compacted = _compact(read.entries);
    if (read.schemaVersion != _schemaVersion ||
        !_sameEntries(read.entries, compacted)) {
      await _enqueueWrite(compacted);
    }
    return List<OperationHistoryEntry>.unmodifiable(compacted);
  }

  @override
  Future<OperationHistoryEntry?> find(String operationId) async {
    final id = operationId.trim();
    if (id.isEmpty) return null;
    final entries = await list();
    for (final entry in entries) {
      if (entry.operationId == id) return entry;
    }
    return null;
  }

  @override
  Future<void> append(OperationHistoryEntry entry) async {
    if (!entry.isStructurallyValid) {
      throw ArgumentError.value(entry.operationId, 'entry', 'Istoric invalid.');
    }
    if (!_isOpaque(entry.resultFingerprint)) {
      throw ArgumentError.value(
        entry.resultFingerprint,
        'resultFingerprint',
        'Fingerprintul trebuie sa fie opac.',
      );
    }
    if (entry.createdContactFingerprint != null &&
        !_isOpaque(entry.createdContactFingerprint!)) {
      throw ArgumentError.value(
        entry.createdContactFingerprint,
        'createdContactFingerprint',
        'Fingerprintul contactului trebuie sa fie opac.',
      );
    }
    await _enqueueMutation((entries) {
      final next = entries
          .where((existing) => existing.operationId != entry.operationId)
          .toList()
        ..add(entry);
      next.sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
      return _compact(next);
    });
  }

  @override
  Future<bool> markUndoConsumed(String operationId) async {
    final id = operationId.trim();
    if (id.isEmpty) return false;
    var consumed = false;
    await _enqueueMutation((entries) {
      return entries.map((entry) {
        if (entry.operationId != id || !entry.canUndo) return entry;
        consumed = true;
        return entry.consumeUndo();
      }).toList(growable: false);
    });
    return consumed;
  }

  @override
  Future<bool> delete(String operationId) async {
    final id = operationId.trim();
    if (id.isEmpty) return false;
    var removed = false;
    await _enqueueMutation((entries) {
      final next = <OperationHistoryEntry>[];
      for (final entry in entries) {
        if (entry.operationId == id) {
          if (entry.canUndo) {
            next.add(entry);
          } else {
            removed = true;
          }
        } else {
          next.add(entry);
        }
      }
      return next;
    });
    return removed;
  }

  @override
  Future<void> clear({bool preserveUndoable = true}) async {
    await _enqueueMutation((entries) => preserveUndoable
        ? entries.where((entry) => entry.canUndo).toList()
        : <OperationHistoryEntry>[]);
  }

  @override
  Future<Set<String>> protectedBackupIds() async {
    final entries = await list();
    return entries.expand((entry) => entry.protectedBackupIds).toSet();
  }

  Future<_HistoryEnvelope> _readEnvelope() async {
    final raw = await _preferences.getString(_key);
    if (raw == null || raw.isEmpty) {
      return const _HistoryEnvelope(
        schemaVersion: _schemaVersion,
        entries: <OperationHistoryEntry>[],
      );
    }
    if (raw.length > _maximumBytes) {
      await _preferences.remove(_key);
      return const _HistoryEnvelope(
        schemaVersion: _schemaVersion,
        entries: <OperationHistoryEntry>[],
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['entries'] is! List) {
        await _preferences.remove(_key);
        return const _HistoryEnvelope(
          schemaVersion: _schemaVersion,
          entries: <OperationHistoryEntry>[],
        );
      }
      final schemaVersion = decoded['schemaVersion'];
      if (schemaVersion is! int ||
          !_supportedSchemaVersions.contains(schemaVersion)) {
        await _preferences.remove(_key);
        return const _HistoryEnvelope(
          schemaVersion: _schemaVersion,
          entries: <OperationHistoryEntry>[],
        );
      }
      final entries = (decoded['entries'] as List)
          .map(OperationHistoryEntry.tryParse)
          .whereType<OperationHistoryEntry>()
          .toList(growable: true);
      return _HistoryEnvelope(
        schemaVersion: schemaVersion,
        entries: entries,
      );
    } on Object {
      await _preferences.remove(_key);
      return const _HistoryEnvelope(
        schemaVersion: _schemaVersion,
        entries: <OperationHistoryEntry>[],
      );
    }
  }

  Future<List<OperationHistoryEntry>> _readEntriesForMutation() async {
    return (await _readEnvelope()).entries;
  }

  List<OperationHistoryEntry> _compact(List<OperationHistoryEntry> entries) {
    final now = _clock().toUtc();
    final cutoff = now.subtract(maxAge);
    final seen = <String>{};
    final ordered = entries.toList()
      ..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    final kept = <OperationHistoryEntry>[];
    for (final entry in ordered) {
      if (!seen.add(entry.operationId)) continue;
      final expired = entry.finishedAt.isBefore(cutoff);
      if (expired && !entry.canUndo) continue;
      if (kept.length >= maxEntries && !entry.canUndo) continue;
      kept.add(entry);
    }
    return kept;
  }

  Future<void> _enqueueMutation(
    List<OperationHistoryEntry> Function(List<OperationHistoryEntry>) change,
  ) {
    final completer = Completer<void>();
    _writeQueue = _writeQueue.catchError((Object _) {}).then((_) async {
      try {
        final current = await _readEntriesForMutation();
        await _write(_compact(change(current)));
        completer.complete();
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _enqueueWrite(List<OperationHistoryEntry> entries) {
    final completer = Completer<void>();
    _writeQueue = _writeQueue.catchError((Object _) {}).then((_) async {
      try {
        await _write(_compact(entries));
        completer.complete();
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _write(List<OperationHistoryEntry> entries) async {
    final encoded = jsonEncode(<String, Object?>{
      'schemaVersion': _schemaVersion,
      'entries': entries.map((entry) => entry.toJson()).toList(),
    });
    if (encoded.length > _maximumBytes) {
      throw StateError('operation_history_too_large');
    }
    await _preferences.setString(_key, encoded);
  }

  bool _sameEntries(
    List<OperationHistoryEntry> left,
    List<OperationHistoryEntry> right,
  ) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index].operationId != right[index].operationId ||
          left[index].canUndo != right[index].canUndo ||
          left[index].undoBackupId != right[index].undoBackupId ||
          left[index].undoTargetIds.length != right[index].undoTargetIds.length ||
          left[index].createdContactId != right[index].createdContactId ||
          left[index].createdContactFingerprint !=
              right[index].createdContactFingerprint) {
        return false;
      }
    }
    return true;
  }

  bool _isOpaque(String value) {
    final normalized = value.trim();
    return RegExp(r'^[a-z0-9][a-z0-9-]{0,47}-[a-f0-9]{32}$')
        .hasMatch(normalized);
  }
}

class OperationHistoryFactory {
  const OperationHistoryFactory();

  OperationHistoryEntry fromMerge(
    MergeReport report, {
    required int sourceCount,
    required String backupId,
    String? createdContactFingerprint,
  }) {
    final outcome = switch (report.status) {
      MergeExecutionStatus.success => OperationHistoryOutcome.success,
      MergeExecutionStatus.partialFailure => OperationHistoryOutcome.partial,
      MergeExecutionStatus.blocked || MergeExecutionStatus.permissionDenied =>
        OperationHistoryOutcome.blocked,
      MergeExecutionStatus.cancelled => OperationHistoryOutcome.cancelled,
      MergeExecutionStatus.reconcileRequired ||
      MergeExecutionStatus.rollbackFailed => OperationHistoryOutcome.reconcile,
      _ => OperationHistoryOutcome.failed,
    };
    final targetIds = report.deletedSourceIds.toSet();
    final createdId = report.createdContactId?.trim();
    final createdFingerprint = createdContactFingerprint?.trim();
    final canUndo = targetIds.isNotEmpty &&
        createdId != null &&
        createdId.isNotEmpty &&
        createdFingerprint != null &&
        createdFingerprint.isNotEmpty &&
        !report.requiresReconcile &&
        report.status == MergeExecutionStatus.success;
    return OperationHistoryEntry(
      operationId: report.operationId,
      type: OperationHistoryType.merge,
      outcome: outcome,
      startedAt: report.startedAt,
      finishedAt: report.finishedAt,
      sourceCount: sourceCount,
      changedCount: report.deletedSourceIds.length +
          (report.createdContactId == null ? 0 : 1),
      skippedCount: report.skippedSourceIds.length,
      backupId: backupId,
      resultFingerprint: stableOpaqueId(
        <String>[
          report.operationId,
          report.status.name,
          '${report.deletedSourceIds.length}',
          '${report.skippedSourceIds.length}',
          report.createdContactId == null ? 'none' : 'created',
        ],
        namespace: 'history-merge',
      ),
      canUndo: canUndo,
      undoBackupId: canUndo ? backupId : null,
      undoTargetIds: canUndo ? targetIds : const <String>{},
      createdContactId: createdId,
      createdContactFingerprint: createdFingerprint,
    );
  }

  OperationHistoryEntry fromRestore(
    RestoreReport report, {
    required String operationId,
    required DateTime startedAt,
    String? parentOperationId,
  }) {
    final outcome = switch (report.status) {
      RestoreExecutionStatus.success => OperationHistoryOutcome.success,
      RestoreExecutionStatus.partialSuccess => OperationHistoryOutcome.partial,
      RestoreExecutionStatus.blocked || RestoreExecutionStatus.permissionDenied =>
        OperationHistoryOutcome.blocked,
      RestoreExecutionStatus.cancelled => OperationHistoryOutcome.cancelled,
      RestoreExecutionStatus.reconcileRequired ||
      RestoreExecutionStatus.rollbackFailed => OperationHistoryOutcome.reconcile,
      _ => OperationHistoryOutcome.failed,
    };
    final finishedAt = DateTime.now().toUtc();
    // Restore-ul generic nu expune inca ID-urile native nou create. Fara ele,
    // un al doilea undo ar fi nesigur, deci ramane explicit indisponibil.
    return OperationHistoryEntry(
      operationId: operationId,
      type: parentOperationId == null
          ? OperationHistoryType.restore
          : OperationHistoryType.undo,
      outcome: outcome,
      startedAt: startedAt,
      finishedAt: finishedAt,
      sourceCount: report.restoredIds.length + report.skippedIds.length,
      changedCount: report.restoredIds.length,
      skippedCount: report.skippedIds.length,
      backupId: report.sourceBackupId,
      safetyBackupId: report.safetyBackupId,
      resultFingerprint: stableOpaqueId(
        <String>[
          operationId,
          report.status.name,
          '${report.restoredIds.length}',
          '${report.skippedIds.length}',
          parentOperationId ?? 'root',
        ],
        namespace: 'history-restore',
      ),
      canUndo: false,
      parentOperationId: parentOperationId,
    );
  }
}

class _HistoryEnvelope {
  final int schemaVersion;
  final List<OperationHistoryEntry> entries;

  const _HistoryEnvelope({
    required this.schemaVersion,
    required this.entries,
  });
}

extension _FirstOrNullHistory<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
