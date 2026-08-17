import 'package:flutter/foundation.dart';

import 'operation_history.dart';

enum HistoryControllerStatus { idle, loading, ready, error }

class HistoryController extends ChangeNotifier {
  final OperationHistoryRepository _repository;

  HistoryControllerStatus _status = HistoryControllerStatus.idle;
  List<OperationHistoryEntry> _entries = const <OperationHistoryEntry>[];
  Set<OperationHistoryType> _types = <OperationHistoryType>{};
  Set<OperationHistoryOutcome> _outcomes = <OperationHistoryOutcome>{};
  bool _undoableOnly = false;
  String? _errorCode;
  bool _isDisposed = false;
  int _generation = 0;

  HistoryController({required OperationHistoryRepository repository})
      : _repository = repository;

  HistoryControllerStatus get status => _status;
  List<OperationHistoryEntry> get entries => _entries;
  String? get errorCode => _errorCode;
  Set<OperationHistoryType> get selectedTypes => Set.unmodifiable(_types);
  Set<OperationHistoryOutcome> get selectedOutcomes => Set.unmodifiable(_outcomes);
  bool get undoableOnly => _undoableOnly;
  bool get isLoading => _status == HistoryControllerStatus.loading;
  bool get hasFilters => _types.isNotEmpty || _outcomes.isNotEmpty || _undoableOnly;

  List<OperationHistoryEntry> get visibleEntries {
    final filtered = _entries.where((entry) {
      if (_types.isNotEmpty && !_types.contains(entry.type)) return false;
      if (_outcomes.isNotEmpty && !_outcomes.contains(entry.outcome)) return false;
      if (_undoableOnly && !entry.canUndo) return false;
      return true;
    }).toList(growable: false)
      ..sort((left, right) => right.finishedAt.compareTo(left.finishedAt));
    return List<OperationHistoryEntry>.unmodifiable(filtered);
  }

  int get undoableCount => _entries.where((entry) => entry.canUndo).length;
  int get reconcileCount => _entries
      .where((entry) => entry.outcome == OperationHistoryOutcome.reconcile)
      .length;
  int get failedCount => _entries
      .where((entry) => entry.outcome == OperationHistoryOutcome.failed)
      .length;
  int get visibleCount => visibleEntries.length;

  Future<void> load() async {
    final generation = ++_generation;
    _status = HistoryControllerStatus.loading;
    _errorCode = null;
    _notifySafely();
    try {
      final entries = await _repository.list();
      if (_isDisposed || generation != _generation) return;
      _entries = List<OperationHistoryEntry>.unmodifiable(entries);
      _status = HistoryControllerStatus.ready;
    } on Object {
      if (_isDisposed || generation != _generation) return;
      _status = HistoryControllerStatus.error;
      _errorCode = 'history_load_failed';
    }
    _notifySafely();
  }

  Future<bool> deleteEntry(String operationId) async {
    if (isLoading) return false;
    final id = operationId.trim();
    if (id.isEmpty) return false;
    final entry = findById(id);
    if (entry == null || entry.canUndo) return false;
    try {
      final removed = await _repository.delete(id);
      if (!removed || _isDisposed) return removed;
      _entries = List<OperationHistoryEntry>.unmodifiable(
        _entries.where((value) => value.operationId != id),
      );
      _notifySafely();
      return true;
    } on Object {
      if (!_isDisposed) {
        _status = HistoryControllerStatus.error;
        _errorCode = 'history_delete_failed';
        _notifySafely();
      }
      return false;
    }
  }

  Future<bool> clear({bool preserveUndoable = true}) async {
    if (isLoading) return false;
    try {
      await _repository.clear(preserveUndoable: preserveUndoable);
      if (_isDisposed) return false;
      _entries = preserveUndoable
          ? List<OperationHistoryEntry>.unmodifiable(
              _entries.where((entry) => entry.canUndo),
            )
          : const <OperationHistoryEntry>[];
      _status = HistoryControllerStatus.ready;
      _errorCode = null;
      _notifySafely();
      return true;
    } on Object {
      if (!_isDisposed) {
        _status = HistoryControllerStatus.error;
        _errorCode = 'history_clear_failed';
        _notifySafely();
      }
      return false;
    }
  }

  Future<Set<String>> protectedBackupIds() async {
    try {
      return await _repository.protectedBackupIds();
    } on Object {
      return <String>{};
    }
  }

  OperationHistoryEntry? findById(String operationId) {
    final id = operationId.trim();
    for (final entry in _entries) {
      if (entry.operationId == id) return entry;
    }
    return null;
  }

  void setTypeEnabled(OperationHistoryType type, bool enabled) {
    final next = _types.toSet();
    final changed = enabled ? next.add(type) : next.remove(type);
    if (!changed) return;
    _types = next;
    _notifySafely();
  }

  void setOutcomeEnabled(OperationHistoryOutcome outcome, bool enabled) {
    final next = _outcomes.toSet();
    final changed = enabled ? next.add(outcome) : next.remove(outcome);
    if (!changed) return;
    _outcomes = next;
    _notifySafely();
  }

  void setUndoableOnly(bool value) {
    if (_undoableOnly == value) return;
    _undoableOnly = value;
    _notifySafely();
  }

  void clearFilters() {
    if (!hasFilters) return;
    _types = <OperationHistoryType>{};
    _outcomes = <OperationHistoryOutcome>{};
    _undoableOnly = false;
    _notifySafely();
  }

  void clearError() {
    if (_status != HistoryControllerStatus.error) return;
    _status = HistoryControllerStatus.ready;
    _errorCode = null;
    _notifySafely();
  }

  void _notifySafely() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _generation++;
    super.dispose();
  }
}
