import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/contacts/contact_data_normalizer.dart';
import '../../core/contacts/contact_models.dart';
import '../../core/contacts/contacts_scan_service.dart';

enum DuplicateSortMode { confidenceDesc, contactCountDesc, nameAsc, reason }
enum DuplicateConfidenceFilter { all, safe, probable, manualReview }

class DuplicateListFilter {
  final String query;
  final DuplicateConfidenceFilter confidence;
  final Set<DuplicateMatchReason> reasons;
  final bool mergeableOnly;
  final bool includeIgnored;

  const DuplicateListFilter({
    this.query = '',
    this.confidence = DuplicateConfidenceFilter.all,
    this.reasons = const <DuplicateMatchReason>{},
    this.mergeableOnly = false,
    this.includeIgnored = false,
  });

  DuplicateListFilter copyWith({
    String? query,
    DuplicateConfidenceFilter? confidence,
    Set<DuplicateMatchReason>? reasons,
    bool? mergeableOnly,
    bool? includeIgnored,
  }) {
    return DuplicateListFilter(
      query: query ?? this.query,
      confidence: confidence ?? this.confidence,
      reasons: reasons ?? this.reasons,
      mergeableOnly: mergeableOnly ?? this.mergeableOnly,
      includeIgnored: includeIgnored ?? this.includeIgnored,
    );
  }
}

abstract interface class IgnoredDuplicateStore {
  Future<Set<String>> load();
  Future<void> save(Set<String> fingerprints);
}

class PreferencesIgnoredDuplicateStore implements IgnoredDuplicateStore {
  static const String _key = 'ignored_duplicate_fingerprints_v1';
  final SharedPreferencesAsync _preferences;

  PreferencesIgnoredDuplicateStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  @override
  Future<Set<String>> load() async {
    final values = await _preferences.getStringList(_key) ?? const <String>[];
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && value.length <= 96)
        .toSet();
  }

  @override
  Future<void> save(Set<String> fingerprints) async {
    final values = fingerprints
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && value.length <= 96)
        .toSet()
        .toList()
      ..sort();
    await _preferences.setStringList(_key, values);
  }
}

class DuplicateListController extends ChangeNotifier {
  final ContactDataNormalizer _normalizer;
  final IgnoredDuplicateStore _ignoredStore;
  final Duration debounceDuration;

  List<DuplicateContactGroup> _groups = const <DuplicateContactGroup>[];
  List<DuplicateContactGroup> _visibleGroups = const <DuplicateContactGroup>[];
  DuplicateListFilter _filter = const DuplicateListFilter();
  DuplicateSortMode _sortMode = DuplicateSortMode.confidenceDesc;
  Set<String> _ignoredFingerprints = <String>{};
  Set<String> _selectedGroupIds = <String>{};
  Timer? _debounce;
  int _scanRevision = -1;
  int _generation = 0;
  bool _loadingIgnored = false;
  bool _persistenceFailed = false;
  bool _datasetBusy = false;
  bool _isDisposed = false;
  ScanAccessScope _accessScope = ScanAccessScope.unknown;

  DuplicateListController({
    ContactDataNormalizer? normalizer,
    IgnoredDuplicateStore? ignoredStore,
    this.debounceDuration = const Duration(milliseconds: 220),
  })  : assert(!debounceDuration.isNegative),
        _normalizer = normalizer ?? ContactDataNormalizer(),
        _ignoredStore = ignoredStore ?? PreferencesIgnoredDuplicateStore();

  List<DuplicateContactGroup> get groups => _groups;
  List<DuplicateContactGroup> get visibleGroups => _visibleGroups;
  DuplicateListFilter get filter => _filter;
  DuplicateSortMode get sortMode => _sortMode;
  Set<String> get selectedGroupIds => Set<String>.unmodifiable(_selectedGroupIds);
  bool get loadingIgnored => _loadingIgnored;
  bool get persistenceFailed => _persistenceFailed;
  bool get datasetBusy => _datasetBusy;
  int get scanRevision => _scanRevision;
  ScanAccessScope get accessScope => _accessScope;
  bool get limitedAccess => _accessScope == ScanAccessScope.limited;
  int get visibleCount => _visibleGroups.length;
  int get totalCount => _groups.length;
  int get ignoredCount => _groups.where(isIgnored).length;
  int get mergeableCount => _groups.where(_isSelectable).length;
  int get manualReviewCount => _groups
      .where((group) => group.requiresManualReview)
      .length;
  int get overlappingCount => _groups
      .where((group) => group.overlapsAnotherGroup)
      .length;
  int get selectedCount => _selectedGroupIds.length;
  bool get hasSelection => _selectedGroupIds.isNotEmpty;
  bool get hasActiveFilters =>
      _filter.query.trim().isNotEmpty ||
      _filter.confidence != DuplicateConfidenceFilter.all ||
      _filter.reasons.isNotEmpty ||
      _filter.mergeableOnly ||
      _filter.includeIgnored ||
      _sortMode != DuplicateSortMode.confidenceDesc;

  Future<void> initialize() async {
    if (_loadingIgnored) return;
    final generation = ++_generation;
    _loadingIgnored = true;
    _persistenceFailed = false;
    _notifySafely();
    try {
      final ignored = await _ignoredStore.load();
      if (_isDisposed || generation != _generation) return;
      _ignoredFingerprints = ignored;
      _recompute();
    } on Object {
      if (_isDisposed || generation != _generation) return;
      _persistenceFailed = true;
    } finally {
      if (!_isDisposed && generation == _generation) {
        _loadingIgnored = false;
        _notifySafely();
      }
    }
  }

  Future<void> retryIgnoredPersistence() async {
    if (_loadingIgnored || !_persistenceFailed) return;
    await _persistIgnored();
  }

  void replaceDataset(
    List<DuplicateContactGroup> groups, {
    required int scanRevision,
    ScanAccessScope accessScope = ScanAccessScope.unknown,
    bool busy = false,
  }) {
    final revisionChanged = _scanRevision != scanRevision;
    _scanRevision = scanRevision;
    _accessScope = accessScope;
    _datasetBusy = busy;
    _groups = List<DuplicateContactGroup>.unmodifiable(groups);
    if (revisionChanged) {
      _selectedGroupIds.clear();
    }
    _removeInvalidSelections();
    _recompute();
    _notifySafely();
  }

  void setDatasetBusy(bool value) {
    if (_datasetBusy == value) return;
    _datasetBusy = value;
    if (value) _selectedGroupIds.clear();
    _notifySafely();
  }

  void updateQuery(String query) {
    if (_filter.query == query) return;
    _filter = _filter.copyWith(query: query);
    _debounce?.cancel();
    if (debounceDuration == Duration.zero) {
      _recomputeAndNotify();
      return;
    }
    _debounce = Timer(debounceDuration, () {
      if (_isDisposed) return;
      _recompute();
      _notifySafely();
    });
  }

  void submitQuery() {
    _debounce?.cancel();
    _debounce = null;
    _recomputeAndNotify();
  }

  void clearQuery() {
    if (_filter.query.isEmpty) return;
    _debounce?.cancel();
    _debounce = null;
    _filter = _filter.copyWith(query: '');
    _recomputeAndNotify();
  }

  void setConfidenceFilter(DuplicateConfidenceFilter confidence) {
    if (_filter.confidence == confidence) return;
    _filter = _filter.copyWith(confidence: confidence);
    _recomputeAndNotify();
  }

  void setReasonEnabled(DuplicateMatchReason reason, bool enabled) {
    final reasons = _filter.reasons.toSet();
    final changed = enabled ? reasons.add(reason) : reasons.remove(reason);
    if (!changed) return;
    _filter = _filter.copyWith(
      reasons: Set<DuplicateMatchReason>.unmodifiable(reasons),
    );
    _recomputeAndNotify();
  }

  void setMergeableOnly(bool value) {
    if (_filter.mergeableOnly == value) return;
    _filter = _filter.copyWith(mergeableOnly: value);
    _recomputeAndNotify();
  }

  void setIncludeIgnored(bool value) {
    if (_filter.includeIgnored == value) return;
    _filter = _filter.copyWith(includeIgnored: value);
    _recomputeAndNotify();
  }

  void setSortMode(DuplicateSortMode mode) {
    if (_sortMode == mode) return;
    _sortMode = mode;
    _recomputeAndNotify();
  }

  Future<bool> ignoreGroup(DuplicateContactGroup group) async {
    final fingerprint = _ignoreFingerprint(group);
    if (_ignoredFingerprints.contains(fingerprint)) return true;
    _ignoredFingerprints = <String>{..._ignoredFingerprints, fingerprint};
    _selectedGroupIds.remove(group.id);
    _recomputeAndNotify();
    return _persistIgnored();
  }

  Future<bool> restoreIgnoredGroup(DuplicateContactGroup group) async {
    final fingerprint = _ignoreFingerprint(group);
    if (!_ignoredFingerprints.contains(fingerprint)) return true;
    final next = _ignoredFingerprints.toSet()..remove(fingerprint);
    _ignoredFingerprints = next;
    _recomputeAndNotify();
    return _persistIgnored();
  }

  bool isIgnored(DuplicateContactGroup group) =>
      _ignoredFingerprints.contains(_ignoreFingerprint(group));

  bool canQuickMerge(DuplicateContactGroup group) =>
      !_datasetBusy &&
      !isIgnored(group) &&
      group.confidenceLabel == DuplicateConfidenceLabel.safe &&
      group.confidenceScore >= 95 &&
      _isSelectable(group);

  bool canOpenDetails(DuplicateContactGroup group) =>
      !_datasetBusy && !isIgnored(group);

  bool toggleSelection(DuplicateContactGroup group) {
    if (_datasetBusy || !_isSelectable(group) || isIgnored(group)) return false;
    if (_selectedGroupIds.contains(group.id)) {
      _selectedGroupIds.remove(group.id);
      _notifySafely();
      return true;
    }
    if (group.confidenceScore < 95 || group.requiresManualReview) return false;
    if (_selectionOverlaps(group)) return false;
    _selectedGroupIds.add(group.id);
    _notifySafely();
    return true;
  }

  void clearSelection() {
    if (_selectedGroupIds.isEmpty) return;
    _selectedGroupIds.clear();
    _notifySafely();
  }

  List<DuplicateContactGroup> selectedGroups() {
    final ids = _selectedGroupIds;
    return List<DuplicateContactGroup>.unmodifiable(
      _groups.where((group) => ids.contains(group.id)),
    );
  }

  Set<String> selectedContactIds() => Set<String>.unmodifiable(
        selectedGroups()
            .expand((group) => group.contacts)
            .map((contact) => contact.nativeId),
      );

  void clearFilters() {
    _debounce?.cancel();
    _debounce = null;
    _filter = const DuplicateListFilter();
    _sortMode = DuplicateSortMode.confidenceDesc;
    _recomputeAndNotify();
  }

  bool _selectionOverlaps(DuplicateContactGroup candidate) {
    final candidateContacts = candidate.contacts
        .map((contact) => contact.nativeId)
        .toSet();
    return selectedContactIds().intersection(candidateContacts).isNotEmpty;
  }

  bool _isSelectable(DuplicateContactGroup group) =>
      group.canBeMerged &&
      !group.overlapsAnotherGroup &&
      group.contacts.every((contact) => contact.hasStableNativeId);

  void _removeInvalidSelections() {
    final validIds = _groups
        .where(_isSelectable)
        .where((group) => !isIgnored(group))
        .map((group) => group.id)
        .toSet();
    _selectedGroupIds.removeWhere((id) => !validIds.contains(id));
  }

  void _recompute() {
    final rawQuery = _normalizer.sanitizeText(_filter.query);
    final nameQuery = _normalizer.fuzzyNameKey(rawQuery);
    final phoneQuery = _normalizer.normalizePhone(rawQuery);
    final emailQuery = _normalizer.normalizeEmail(rawQuery);
    final companyQuery = _normalizer.companyKey(rawQuery);
    final filtered = _groups.where((group) {
      if (!_filter.includeIgnored && isIgnored(group)) return false;
      if (_filter.mergeableOnly && !_isSelectable(group)) return false;
      if (_filter.reasons.isNotEmpty &&
          group.reasons.intersection(_filter.reasons).isEmpty) {
        return false;
      }
      if (!_confidenceMatches(group)) return false;
      if (rawQuery.isEmpty) return true;
      return group.contacts.any((contact) {
        final record = contact.record;
        if (nameQuery.isNotEmpty &&
            _normalizer.fuzzyNameKey(contact.displayName).contains(nameQuery)) {
          return true;
        }
        if (phoneQuery.isNotEmpty && contact.phones.any((value) => value.contains(phoneQuery))) {
          return true;
        }
        if (emailQuery.isNotEmpty && contact.emails.any((value) => value.contains(emailQuery))) {
          return true;
        }
        if (companyQuery.isNotEmpty &&
            (record?.organizations.any(
                  (organization) => organization.companyKey.contains(companyQuery),
                ) ??
                false)) {
          return true;
        }
        return false;
      });
    }).toList(growable: false);
    filtered.sort(_compareGroups);
    _visibleGroups = List<DuplicateContactGroup>.unmodifiable(filtered);
  }

  bool _confidenceMatches(DuplicateContactGroup group) {
    return switch (_filter.confidence) {
      DuplicateConfidenceFilter.all => true,
      DuplicateConfidenceFilter.safe =>
        group.confidenceLabel == DuplicateConfidenceLabel.safe,
      DuplicateConfidenceFilter.probable =>
        group.confidenceLabel == DuplicateConfidenceLabel.probable,
      DuplicateConfidenceFilter.manualReview =>
        group.confidenceLabel == DuplicateConfidenceLabel.manualReview,
    };
  }

  int _compareGroups(DuplicateContactGroup left, DuplicateContactGroup right) {
    final result = switch (_sortMode) {
      DuplicateSortMode.confidenceDesc =>
        right.confidenceScore.compareTo(left.confidenceScore),
      DuplicateSortMode.contactCountDesc =>
        right.contacts.length.compareTo(left.contacts.length),
      DuplicateSortMode.nameAsc => _normalizer
          .exactNameKey(left.contacts.first.displayName)
          .compareTo(_normalizer.exactNameKey(right.contacts.first.displayName)),
      DuplicateSortMode.reason => _sortedReasonKey(left)
          .compareTo(_sortedReasonKey(right)),
    };
    return result != 0 ? result : left.id.compareTo(right.id);
  }

  String _sortedReasonKey(DuplicateContactGroup group) {
    final values = group.reasons.map((reason) => reason.name).toList()..sort();
    return values.join(',');
  }

  String _ignoreFingerprint(DuplicateContactGroup group) {
    return group.revisionFingerprint.isNotEmpty
        ? group.revisionFingerprint
        : stableOpaqueId(
            group.contacts.map(
              (contact) =>
                  '${contact.nativeId}:${contact.record?.revision.fingerprint ?? ''}',
            ),
            namespace: 'ignored',
          );
  }

  Future<bool> _persistIgnored() async {
    _persistenceFailed = false;
    try {
      await _ignoredStore.save(_ignoredFingerprints);
      if (_isDisposed) return false;
      _notifySafely();
      return true;
    } on Object {
      if (_isDisposed) return false;
      _persistenceFailed = true;
      _notifySafely();
      return false;
    }
  }

  void _recomputeAndNotify() {
    _recompute();
    _notifySafely();
  }

  void _notifySafely() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _generation++;
    _debounce?.cancel();
    _debounce = null;
    super.dispose();
  }
}
