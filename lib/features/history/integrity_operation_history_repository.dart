import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/contacts/contact_models.dart';
import 'operation_history.dart';

class IntegrityOperationHistoryRepository implements OperationHistoryRepository {
  static const String _key = 'operation_history_v4';
  static const String _legacyKey = 'operation_history_v1';
  static const int _schemaVersion = 4;
  static const int _writerVersion = 1;
  static const int _maximumBytes = 768 * 1024;
  static const int _maximumEntriesHard = 1000;
  static const Duration _futureTolerance = Duration(minutes: 5);

  final SharedPreferencesAsync _preferences;
  final int maxEntries;
  final Duration maxAge;
  final DateTime Function() _clock;
  Future<void> _writeQueue = Future<void>.value();

  IntegrityOperationHistoryRepository({
    SharedPreferencesAsync? preferences,
    int maxEntries = 100,
    Duration maxAge = const Duration(days: 90),
    DateTime Function()? clock,
  })  : _preferences = preferences ?? SharedPreferencesAsync(),
        maxEntries = maxEntries.clamp(10, _maximumEntriesHard),
        maxAge = maxAge.isNegative || maxAge == Duration.zero
            ? const Duration(days: 90)
            : maxAge,
        _clock = clock ?? DateTime.now;

  @override
  Future<List<OperationHistoryEntry>> list() async {
    await _afterWrites();
    final read = await _readUnlocked();
    final compacted = _compactAndValidateGraph(read);
    if (!_sameEntries(read, compacted)) {
      await _enqueueWrite(() => _writeUnlocked(compacted));
    }
    return List<OperationHistoryEntry>.unmodifiable(compacted);
  }

  @override
  Future<OperationHistoryEntry?> find(String operationId) async {
    final id = _normalizeOperationId(operationId, allowMissing: true);
    if (id == null) return null;
    for (final entry in await list()) {
      if (entry.operationId == id) return entry;
    }
    return null;
  }

  @override
  Future<void> append(OperationHistoryEntry entry) async {
    _validateEntry(entry);
    await _enqueueMutation((entries) {
      final existing = entries
          .where((item) => item.operationId == entry.operationId)
          .firstOrNull;
      if (existing != null &&
          existing.resultFingerprint != entry.resultFingerprint) {
        throw StateError('operation_history_id_collision');
      }
      final next = entries
          .where((item) => item.operationId != entry.operationId)
          .toList(growable: true)
        ..add(entry);
      return _compactAndValidateGraph(next);
    });
  }

  @override
  Future<bool> markUndoConsumed(String operationId) async {
    final id = _normalizeOperationId(operationId, allowMissing: true);
    if (id == null) return false;
    var changed = false;
    await _enqueueMutation((entries) {
      final next = entries.map((entry) {
        if (entry.operationId != id || !entry.canUndo) return entry;
        changed = true;
        return entry.consumeUndo();
      }).toList(growable: false);
      return _compactAndValidateGraph(next);
    });
    return changed;
  }

  @override
  Future<bool> delete(String operationId) async {
    final id = _normalizeOperationId(operationId, allowMissing: true);
    if (id == null) return false;
    var removed = false;
    await _enqueueMutation((entries) {
      final descendants = _descendantIds(entries, id);
      final next = <OperationHistoryEntry>[];
      for (final entry in entries) {
        if (entry.operationId != id) {
          next.add(entry);
          continue;
        }
        if (entry.canUndo || descendants.isNotEmpty) {
          next.add(entry);
        } else {
          removed = true;
        }
      }
      return _compactAndValidateGraph(next);
    });
    return removed;
  }

  @override
  Future<void> clear({bool preserveUndoable = true}) async {
    await _enqueueMutation((entries) {
      if (!preserveUndoable) {
        final requiredAncestors = _requiredAncestors(
          entries,
          entries.where((entry) => entry.canUndo).map((entry) => entry.operationId),
        );
        return entries
            .where(
              (entry) => entry.canUndo || requiredAncestors.contains(entry.operationId),
            )
            .toList(growable: false);
      }
      final roots = entries.where((entry) => entry.canUndo).map((entry) => entry.operationId);
      final keep = <String>{
        ...roots,
        ..._requiredAncestors(entries, roots),
      };
      return entries
          .where((entry) => keep.contains(entry.operationId))
          .toList(growable: false);
    });
  }

  @override
  Future<Set<String>> protectedBackupIds() async {
    final entries = await list();
    return Set<String>.unmodifiable(
      entries
          .where((entry) => entry.canUndo)
          .expand((entry) => entry.protectedBackupIds)
          .where(_validBackupId),
    );
  }

  Future<List<OperationHistoryEntry>> _readUnlocked() async {
    final raw = await _preferences.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      return _parseV4(raw);
    }
    final legacy = await _preferences.getString(_legacyKey);
    if (legacy == null || legacy.isEmpty) return const <OperationHistoryEntry>[];
    final migrated = _parseLegacy(legacy);
    if (migrated.isNotEmpty) {
      await _writeUnlocked(migrated);
    }
    return migrated;
  }

  List<OperationHistoryEntry> _parseV4(String raw) {
    if (raw.length > _maximumBytes) {
      throw StateError('operation_history_too_large');
    }
    final envelope = _decodeMap(raw, 'operation_history_corrupt');
    final schema = envelope['schemaVersion'];
    if (schema is! int) throw StateError('operation_history_schema_invalid');
    if (schema > _schemaVersion) {
      throw StateError('operation_history_schema_newer');
    }
    if (schema != _schemaVersion ||
        envelope['writerVersion'] != _writerVersion ||
        envelope['entries'] is! List ||
        envelope['checksum'] is! String) {
      throw StateError('operation_history_schema_invalid');
    }
    final rawEntries = envelope['entries'] as List;
    if (rawEntries.length > _maximumEntriesHard * 2) {
      throw StateError('operation_history_entry_count_invalid');
    }
    final expectedEnvelopeChecksum = stableOpaqueId(
      rawEntries.map((entry) => jsonEncode(entry)),
      namespace: 'history-envelope',
    );
    if (envelope['checksum'] != expectedEnvelopeChecksum) {
      throw StateError('operation_history_checksum_invalid');
    }

    final result = <OperationHistoryEntry>[];
    for (final rawEntry in rawEntries) {
      if (rawEntry is! Map) continue;
      final wrapped = _stringMap(rawEntry, allowInvalid: true);
      if (wrapped == null) continue;
      final payload = wrapped['payload'];
      final checksum = wrapped['checksum'];
      if (payload is! Map || checksum is! String) continue;
      final payloadMap = _stringMap(payload, allowInvalid: true);
      if (payloadMap == null) continue;
      if (checksum != _entryChecksum(payloadMap)) continue;
      final entry = OperationHistoryEntry.tryParse(payloadMap);
      if (entry == null || !_entrySafe(entry)) continue;
      result.add(entry);
    }
    return _dedupeOrThrow(result);
  }

  List<OperationHistoryEntry> _parseLegacy(String raw) {
    if (raw.length > _maximumBytes) {
      throw StateError('operation_history_legacy_too_large');
    }
    final decoded = _decodeMap(raw, 'operation_history_legacy_corrupt');
    final schema = decoded['schemaVersion'];
    if (schema is! int || schema < 1 || schema > 3 || decoded['entries'] is! List) {
      throw StateError('operation_history_legacy_schema_invalid');
    }
    final result = <OperationHistoryEntry>[];
    for (final rawEntry in decoded['entries'] as List) {
      final entry = OperationHistoryEntry.tryParse(rawEntry);
      if (entry != null && _entrySafe(entry)) result.add(entry);
    }
    return _dedupeOrThrow(result);
  }

  Future<void> _writeUnlocked(List<OperationHistoryEntry> entries) async {
    final validated = _compactAndValidateGraph(entries);
    final encodedEntries = validated.map((entry) {
      final payload = entry.toJson();
      return <String, Object?>{
        'payload': payload,
        'checksum': _entryChecksum(payload),
      };
    }).toList(growable: false);
    final envelope = <String, Object?>{
      'schemaVersion': _schemaVersion,
      'writerVersion': _writerVersion,
      'entries': encodedEntries,
      'checksum': stableOpaqueId(
        encodedEntries.map((entry) => jsonEncode(entry)),
        namespace: 'history-envelope',
      ),
    };
    final encoded = jsonEncode(envelope);
    if (encoded.length > _maximumBytes) {
      throw StateError('operation_history_too_large');
    }
    await _preferences.setString(_key, encoded);
  }

  List<OperationHistoryEntry> _compactAndValidateGraph(
    Iterable<OperationHistoryEntry> entries,
  ) {
    final current = _dedupeOrThrow(entries);
    _validateGraph(current);
    final now = _clock().toUtc();
    final cutoff = now.subtract(maxAge);
    final protectedRoots = current
        .where((entry) => entry.canUndo)
        .map((entry) => entry.operationId)
        .toSet();
    final protectedAncestors = _requiredAncestors(current, protectedRoots);
    final ordered = current.toList(growable: true)
      ..sort((left, right) {
        final time = right.finishedAt.compareTo(left.finishedAt);
        return time != 0 ? time : left.operationId.compareTo(right.operationId);
      });
    final result = <OperationHistoryEntry>[];
    for (final entry in ordered) {
      final protected = entry.canUndo ||
          protectedAncestors.contains(entry.operationId) ||
          protectedRoots.contains(entry.operationId);
      if (!protected && entry.finishedAt.isBefore(cutoff)) continue;
      if (!protected && result.length >= maxEntries) continue;
      result.add(entry);
    }
    _validateGraph(result);
    return result;
  }

  List<OperationHistoryEntry> _dedupeOrThrow(
    Iterable<OperationHistoryEntry> entries,
  ) {
    final byId = <String, OperationHistoryEntry>{};
    for (final entry in entries) {
      _validateEntry(entry);
      final existing = byId[entry.operationId];
      if (existing != null &&
          existing.resultFingerprint != entry.resultFingerprint) {
        throw StateError('operation_history_id_collision');
      }
      if (existing == null || entry.finishedAt.isAfter(existing.finishedAt)) {
        byId[entry.operationId] = entry;
      }
    }
    return byId.values.toList(growable: true);
  }

  void _validateGraph(List<OperationHistoryEntry> entries) {
    final byId = <String, OperationHistoryEntry>{
      for (final entry in entries) entry.operationId: entry,
    };
    for (final entry in entries) {
      final parentId = entry.parentOperationId;
      if (parentId == null) continue;
      if (parentId == entry.operationId) {
        throw StateError('operation_history_parent_self_reference');
      }
      final parent = byId[parentId];
      if (parent != null && entry.startedAt.isBefore(parent.startedAt)) {
        throw StateError('operation_history_parent_time_invalid');
      }
      final seen = <String>{entry.operationId};
      var cursor = parentId;
      var depth = 0;
      while (cursor.isNotEmpty && depth++ <= entries.length) {
        if (!seen.add(cursor)) {
          throw StateError('operation_history_parent_cycle');
        }
        final next = byId[cursor]?.parentOperationId;
        if (next == null) break;
        cursor = next;
      }
      if (depth > entries.length) {
        throw StateError('operation_history_parent_depth_invalid');
      }
    }
  }

  Set<String> _requiredAncestors(
    List<OperationHistoryEntry> entries,
    Iterable<String> roots,
  ) {
    final byId = <String, OperationHistoryEntry>{
      for (final entry in entries) entry.operationId: entry,
    };
    final result = <String>{};
    for (final root in roots) {
      var current = byId[root]?.parentOperationId;
      var depth = 0;
      while (current != null && depth++ <= entries.length) {
        if (!result.add(current)) break;
        current = byId[current]?.parentOperationId;
      }
    }
    return result;
  }

  Set<String> _descendantIds(
    List<OperationHistoryEntry> entries,
    String operationId,
  ) {
    final result = <String>{};
    var changed = true;
    while (changed) {
      changed = false;
      for (final entry in entries) {
        final parent = entry.parentOperationId;
        if (parent == operationId || (parent != null && result.contains(parent))) {
          if (result.add(entry.operationId)) changed = true;
        }
      }
    }
    return result;
  }

  void _validateEntry(OperationHistoryEntry entry) {
    if (!entry.isStructurallyValid || !_entrySafe(entry)) {
      throw ArgumentError.value(entry.operationId, 'entry', 'Istoric invalid.');
    }
    final now = _clock().toUtc();
    if (entry.startedAt.isAfter(now.add(_futureTolerance)) ||
        entry.finishedAt.isAfter(now.add(_futureTolerance))) {
      throw StateError('operation_history_timestamp_future');
    }
    if (entry.canUndo && !_validBackupId(entry.undoBackupId ?? '')) {
      throw StateError('operation_history_undo_backup_invalid');
    }
    if (entry.safetyBackupId != null && !_validBackupId(entry.safetyBackupId!)) {
      throw StateError('operation_history_safety_backup_invalid');
    }
  }

  bool _entrySafe(OperationHistoryEntry entry) {
    if (!_isOpaque(entry.resultFingerprint)) return false;
    if (entry.createdContactFingerprint != null &&
        !_isOpaque(entry.createdContactFingerprint!)) {
      return false;
    }
    if (entry.parentOperationId != null &&
        _normalizeOperationId(entry.parentOperationId!, allowMissing: true) == null) {
      return false;
    }
    return entry.sourceCount <= 100000 &&
        entry.changedCount <= 100000 &&
        entry.skippedCount <= 100000 &&
        entry.changedCount + entry.skippedCount <=
            entry.sourceCount + 1 + entry.undoTargetIds.length;
  }

  String _entryChecksum(Map<String, Object?> payload) {
    final entries = payload.entries.toList(growable: true)
      ..sort((left, right) => left.key.compareTo(right.key));
    return stableOpaqueId(
      entries.map((entry) => '${entry.key}=${jsonEncode(entry.value)}'),
      namespace: 'history-entry',
    );
  }

  Map<String, Object?> _decodeMap(String raw, String code) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on Object {
      throw StateError(code);
    }
    if (decoded is! Map) throw StateError(code);
    final mapped = _stringMap(decoded);
    if (mapped == null) throw StateError(code);
    return mapped;
  }

  Map<String, Object?>? _stringMap(Map raw, {bool allowInvalid = false}) {
    final result = <String, Object?>{};
    for (final entry in raw.entries) {
      if (entry.key is! String) {
        if (allowInvalid) return null;
        throw StateError('operation_history_map_key_invalid');
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  String? _normalizeOperationId(String value, {required bool allowMissing}) {
    final id = value.trim();
    final valid = id.isNotEmpty &&
        id.length <= 128 &&
        RegExp(r'^[a-z][a-z0-9_-]+$').hasMatch(id);
    if (!valid) {
      if (allowMissing) return null;
      throw StateError('operation_history_operation_id_invalid');
    }
    return id;
  }

  bool _validBackupId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 32) return false;
    final parsed = int.tryParse(trimmed);
    return parsed != null && parsed > 0;
  }

  bool _isOpaque(String value) => RegExp(
        r'^[a-z0-9][a-z0-9-]{0,63}-[a-f0-9]{32}$',
      ).hasMatch(value.trim());

  bool _sameEntries(
    List<OperationHistoryEntry> left,
    List<OperationHistoryEntry> right,
  ) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i].operationId != right[i].operationId ||
          left[i].resultFingerprint != right[i].resultFingerprint ||
          left[i].canUndo != right[i].canUndo ||
          left[i].parentOperationId != right[i].parentOperationId) {
        return false;
      }
    }
    return true;
  }

  Future<void> _enqueueMutation(
    List<OperationHistoryEntry> Function(List<OperationHistoryEntry>) change,
  ) {
    return _enqueueWrite(() async {
      final current = await _readUnlocked();
      await _writeUnlocked(change(current));
    });
  }

  Future<void> _afterWrites() async {
    try {
      await _writeQueue;
    } on Object {
      // Citirea curenta va valida starea persistenta disponibila.
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

extension _FirstOrNullIntegrityHistory<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
