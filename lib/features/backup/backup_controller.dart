import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../core/backup/contact_backup_service.dart';
import '../../core/contacts/contact_data_normalizer.dart';
import '../../core/contacts/contact_models.dart';

enum BackupStatus {
  idle,
  loading,
  ready,
  creating,
  deleting,
  permissionDenied,
  error,
}

enum MergeBackupValidationStatus {
  valid,
  noEligibleBackup,
  sourceContactsMissing,
  sourceContactsChanged,
  backupExpired,
  failed,
}

@immutable
class MergeSourceSnapshot {
  final String id;
  final String displayName;
  final List<String> phones;
  final List<String> emails;

  const MergeSourceSnapshot({
    required this.id,
    required this.displayName,
    required this.phones,
    required this.emails,
  });

  factory MergeSourceSnapshot.fromRecord(ContactRecord record) {
    return MergeSourceSnapshot(
      id: record.nativeId,
      displayName: record.name.displayName,
      phones: record.phones.map((value) => value.displayValue).toList(),
      emails: record.emails.map((value) => value.displayValue).toList(),
    );
  }
}

@immutable
class MergeBackupValidation {
  final MergeBackupValidationStatus status;
  final String? backupId;
  final BackupAccessScope accessScope;
  final List<String> requestedSourceIds;
  final List<String> missingSourceIds;
  final List<String> changedSourceIds;
  final bool sourceContentValidated;
  final String? sourceSnapshotFingerprint;
  final String? groupRevisionFingerprint;
  final int generation;
  final String? errorCode;

  const MergeBackupValidation({
    required this.status,
    required this.backupId,
    this.accessScope = BackupAccessScope.unknown,
    required this.requestedSourceIds,
    this.missingSourceIds = const <String>[],
    this.changedSourceIds = const <String>[],
    this.sourceContentValidated = false,
    this.sourceSnapshotFingerprint,
    this.groupRevisionFingerprint,
    this.generation = 0,
    this.errorCode,
  });

  bool get isValid => status == MergeBackupValidationStatus.valid;
  bool get isFullAccess => accessScope == BackupAccessScope.full;

  bool matchesSources(Iterable<String> sourceIds) {
    final normalized = sourceIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    return setEquals(normalized, requestedSourceIds.toSet());
  }

  bool matchesContext({
    required Iterable<String> sourceIds,
    String? snapshotFingerprint,
    String? groupFingerprint,
  }) {
    return matchesSources(sourceIds) &&
        (snapshotFingerprint == null ||
            sourceSnapshotFingerprint == snapshotFingerprint) &&
        (groupFingerprint == null ||
            groupRevisionFingerprint == groupFingerprint);
  }
}

typedef BackupControllerClock = DateTime Function();
typedef BackupControllerTimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);

Timer _createBackupControllerTimer(
  Duration duration,
  void Function() callback,
) {
  return Timer(duration, callback);
}

class BackupController extends ChangeNotifier {
  static const Duration defaultMergeBackupMaxAge = Duration(minutes: 5);
  static const Duration _boundaryPrecision = Duration(milliseconds: 1);

  final ContactBackupService _service;
  final BackupControllerClock _clock;
  final BackupControllerTimerFactory _timerFactory;
  final bool _canScheduleEligibilityBoundaries;
  final ContactDataNormalizer _normalizer;
  final Duration mergeBackupMaxAge;

  BackupStatus _status = BackupStatus.idle;
  List<ContactBackup> _backups = const <ContactBackup>[];
  String? _errorCode;
  Timer? _mergeEligibilityTimer;
  MergeBackupValidation? _mergeValidation;
  bool _isValidatingMergeSources = false;
  bool _isDisposed = false;
  int _validationGeneration = 0;
  String? _inFlightValidationKey;
  Future<MergeBackupValidation>? _inFlightValidation;

  BackupController(
    this._service, {
    BackupControllerClock? clock,
    BackupControllerTimerFactory? timerFactory,
    ContactDataNormalizer? normalizer,
    this.mergeBackupMaxAge = defaultMergeBackupMaxAge,
  })  : assert(!mergeBackupMaxAge.isNegative),
        _clock = clock ?? DateTime.now,
        _timerFactory = timerFactory ?? _createBackupControllerTimer,
        _normalizer = normalizer ?? ContactDataNormalizer(),
        _canScheduleEligibilityBoundaries =
            clock == null || timerFactory != null;

  BackupStatus get status => _status;
  List<ContactBackup> get backups => _backups;
  String? get errorCode => _errorCode;
  MergeBackupValidation? get mergeValidation => _mergeValidation;
  bool get isValidatingMergeSources => _isValidatingMergeSources;
  int get validationGeneration => _validationGeneration;

  bool get isBusy =>
      _status == BackupStatus.loading ||
      _status == BackupStatus.creating ||
      _status == BackupStatus.deleting ||
      _isValidatingMergeSources;

  bool get hasValidatedBackup => _backups.any((backup) => backup.isValid);

  ContactBackup? get latestValidatedBackup {
    for (final backup in _backups) {
      if (backup.isValid) return backup;
    }
    return null;
  }

  ContactBackup? get latestMergeEligibleBackup {
    for (final backup in _backups) {
      if (isMergeEligible(backup)) return backup;
    }
    return null;
  }

  bool isMergeEligible(ContactBackup backup) {
    if (!backup.isValid) return false;
    final age = _clock().toUtc().difference(backup.createdAt.toUtc());
    return !age.isNegative && age <= mergeBackupMaxAge;
  }

  Future<void> load() async {
    if (isBusy) return;
    _invalidateMergeValidation(notify: false);
    _status = BackupStatus.loading;
    _errorCode = null;
    _notifySafely();
    try {
      final backups = await _service.listBackups();
      if (_isDisposed) return;
      _backups = List<ContactBackup>.unmodifiable(backups);
      _status = BackupStatus.ready;
      _scheduleMergeEligibilityBoundary();
    } on ContactBackupException catch (error) {
      if (_isDisposed) return;
      _status = BackupStatus.error;
      _errorCode = error.code;
    } on Object {
      if (_isDisposed) return;
      _status = BackupStatus.error;
      _errorCode = 'backup_list_failed';
    }
    _notifySafely();
  }

  Future<ContactBackup?> create() async {
    if (isBusy) return null;
    _invalidateMergeValidation(notify: false);
    _status = BackupStatus.creating;
    _errorCode = null;
    _notifySafely();
    try {
      final backup = await _service.createBackup();
      if (_isDisposed) return backup;
      _backups = List<ContactBackup>.unmodifiable(
        <ContactBackup>[
          backup,
          ..._backups.where((existing) => existing.id != backup.id),
        ]..sort((left, right) => right.createdAt.compareTo(left.createdAt)),
      );
      _status = BackupStatus.ready;
      _scheduleMergeEligibilityBoundary();
      _notifySafely();
      return backup;
    } on ContactBackupException catch (error) {
      if (_isDisposed) return null;
      _status = error.code == 'contacts_permission_denied'
          ? BackupStatus.permissionDenied
          : BackupStatus.error;
      _errorCode = error.code;
    } on Object {
      if (_isDisposed) return null;
      _status = BackupStatus.error;
      _errorCode = 'backup_create_failed';
    }
    _notifySafely();
    return null;
  }

  Future<bool> delete(String id) async {
    if (isBusy) return false;
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return false;
    _invalidateMergeValidation(notify: false);
    _status = BackupStatus.deleting;
    _errorCode = null;
    _notifySafely();
    try {
      await _service.deleteBackup(normalizedId);
      if (_isDisposed) return true;
      _backups = List<ContactBackup>.unmodifiable(
        _backups.where((backup) => backup.id != normalizedId),
      );
      _status = BackupStatus.ready;
      _scheduleMergeEligibilityBoundary();
      _notifySafely();
      return true;
    } on ContactBackupException catch (error) {
      if (_isDisposed) return false;
      _status = BackupStatus.error;
      _errorCode = error.code;
    } on Object {
      if (_isDisposed) return false;
      _status = BackupStatus.error;
      _errorCode = 'backup_delete_failed';
    }
    _notifySafely();
    return false;
  }

  Future<MergeBackupValidation> validateMergeRecords(
    Map<String, ContactRecord> records, {
    required String expectedBackupId,
    String? groupRevisionFingerprint,
  }) {
    return validateMergeSources(
      records.keys,
      sourceSnapshots: records.values.map(MergeSourceSnapshot.fromRecord),
      expectedBackupId: expectedBackupId,
      groupRevisionFingerprint: groupRevisionFingerprint,
      requireContentValidation: true,
    );
  }

  Future<MergeBackupValidation> validateMergeSources(
    Iterable<String> sourceIds, {
    Iterable<MergeSourceSnapshot> sourceSnapshots =
        const <MergeSourceSnapshot>[],
    String? expectedBackupId,
    String? expectedSourceSnapshotFingerprint,
    String? groupRevisionFingerprint,
    bool requireContentValidation = false,
  }) {
    final rawIds = sourceIds.map((id) => id.trim()).toList(growable: false);
    final requestedIds = rawIds.where((id) => id.isNotEmpty).toSet();
    final sortedRequestedIds = requestedIds.toList()..sort();
    final invalidIds = rawIds.any((id) => id.isEmpty) ||
        rawIds.length != requestedIds.length;

    final snapshotsById = <String, MergeSourceSnapshot>{};
    var invalidSnapshot = false;
    for (final snapshot in sourceSnapshots) {
      final id = snapshot.id.trim();
      if (id.isEmpty || snapshotsById.containsKey(id)) {
        invalidSnapshot = true;
        continue;
      }
      snapshotsById[id] = snapshot;
    }
    final validateContent = snapshotsById.isNotEmpty;

    if (invalidIds) {
      return Future<MergeBackupValidation>.value(_immediateValidation(
        requestedIds: sortedRequestedIds,
        errorCode: 'merge_source_ids_invalid_or_duplicate',
      ));
    }
    if (requestedIds.isEmpty) {
      return Future<MergeBackupValidation>.value(_immediateValidation(
        requestedIds: const <String>[],
        errorCode: 'merge_source_ids_missing',
      ));
    }
    if (invalidSnapshot ||
        (validateContent &&
            !setEquals(requestedIds, snapshotsById.keys.toSet()))) {
      return Future<MergeBackupValidation>.value(_immediateValidation(
        requestedIds: sortedRequestedIds,
        errorCode: 'merge_source_snapshot_mismatch',
      ));
    }
    if (requireContentValidation && !validateContent) {
      return Future<MergeBackupValidation>.value(_immediateValidation(
        requestedIds: sortedRequestedIds,
        errorCode: 'merge_source_snapshot_required',
      ));
    }
    if (_status == BackupStatus.loading ||
        _status == BackupStatus.creating ||
        _status == BackupStatus.deleting) {
      return Future<MergeBackupValidation>.value(_immediateValidation(
        requestedIds: sortedRequestedIds,
        errorCode: 'backup_operation_busy',
      ));
    }

    final snapshotFingerprint = validateContent
        ? _snapshotFingerprint(snapshotsById.values)
        : null;
    if (expectedSourceSnapshotFingerprint != null &&
        snapshotFingerprint != expectedSourceSnapshotFingerprint) {
      return Future<MergeBackupValidation>.value(_immediateValidation(
        requestedIds: sortedRequestedIds,
        errorCode: 'merge_source_snapshot_fingerprint_mismatch',
        sourceSnapshotFingerprint: snapshotFingerprint,
        groupRevisionFingerprint: groupRevisionFingerprint,
      ));
    }

    final requestKey = stableOpaqueId(
      <String>[
        ...sortedRequestedIds,
        expectedBackupId ?? '',
        snapshotFingerprint ?? 'informational',
        groupRevisionFingerprint ?? '',
        requireContentValidation ? 'required' : 'optional',
      ],
      namespace: 'backup-validation',
    );
    final inFlight = _inFlightValidation;
    if (_isValidatingMergeSources &&
        _inFlightValidationKey == requestKey &&
        inFlight != null) {
      return inFlight;
    }
    if (_isValidatingMergeSources) {
      return Future<MergeBackupValidation>.value(_immediateValidation(
        requestedIds: sortedRequestedIds,
        errorCode: 'backup_validation_busy',
        sourceSnapshotFingerprint: snapshotFingerprint,
        groupRevisionFingerprint: groupRevisionFingerprint,
      ));
    }

    final generation = ++_validationGeneration;
    _isValidatingMergeSources = true;
    _mergeValidation = null;
    _inFlightValidationKey = requestKey;
    final future = Future<MergeBackupValidation>.microtask(
      () => _validateMergeSourcesInternal(
        generation: generation,
        requestedIds: requestedIds,
        sortedRequestedIds: sortedRequestedIds,
        snapshotsById: snapshotsById,
        expectedBackupId: expectedBackupId,
        snapshotFingerprint: snapshotFingerprint,
        groupRevisionFingerprint: groupRevisionFingerprint,
        validateContent: validateContent,
      ),
    );
    _inFlightValidation = future;
    _notifySafely();
    return future;
  }

  Future<MergeBackupValidation> _validateMergeSourcesInternal({
    required int generation,
    required Set<String> requestedIds,
    required List<String> sortedRequestedIds,
    required Map<String, MergeSourceSnapshot> snapshotsById,
    required String? expectedBackupId,
    required String? snapshotFingerprint,
    required String? groupRevisionFingerprint,
    required bool validateContent,
  }) async {
    final backup = latestMergeEligibleBackup;
    if (backup == null) {
      return _finishValidation(
        generation,
        MergeBackupValidation(
          status: MergeBackupValidationStatus.noEligibleBackup,
          backupId: null,
          requestedSourceIds: List<String>.unmodifiable(sortedRequestedIds),
          sourceSnapshotFingerprint: snapshotFingerprint,
          groupRevisionFingerprint: groupRevisionFingerprint,
          generation: generation,
        ),
      );
    }
    if (expectedBackupId != null && backup.id != expectedBackupId.trim()) {
      return _finishValidation(
        generation,
        MergeBackupValidation(
          status: MergeBackupValidationStatus.failed,
          backupId: backup.id,
          accessScope: backup.accessScope,
          requestedSourceIds: List<String>.unmodifiable(sortedRequestedIds),
          sourceSnapshotFingerprint: snapshotFingerprint,
          groupRevisionFingerprint: groupRevisionFingerprint,
          generation: generation,
          errorCode: 'merge_backup_id_mismatch',
        ),
      );
    }

    try {
      final data = await _service.readBackup(backup.id);
      if (data.backup.id != backup.id || !isMergeEligible(data.backup)) {
        return _finishValidation(
          generation,
          MergeBackupValidation(
            status: MergeBackupValidationStatus.backupExpired,
            backupId: backup.id,
            accessScope: data.backup.accessScope,
            requestedSourceIds: List<String>.unmodifiable(sortedRequestedIds),
            sourceSnapshotFingerprint: snapshotFingerprint,
            groupRevisionFingerprint: groupRevisionFingerprint,
            generation: generation,
          ),
        );
      }

      final backedUpContacts = <String, Contact>{};
      var duplicateNativeId = false;
      for (final contact in data.contacts) {
        final id = contact.id?.trim();
        if (id == null || id.isEmpty) continue;
        if (backedUpContacts.containsKey(id)) duplicateNativeId = true;
        backedUpContacts[id] = contact;
      }
      if (duplicateNativeId) {
        return _finishValidation(
          generation,
          MergeBackupValidation(
            status: MergeBackupValidationStatus.failed,
            backupId: backup.id,
            accessScope: data.backup.accessScope,
            requestedSourceIds: List<String>.unmodifiable(sortedRequestedIds),
            sourceSnapshotFingerprint: snapshotFingerprint,
            groupRevisionFingerprint: groupRevisionFingerprint,
            generation: generation,
            errorCode: 'backup_duplicate_native_ids',
          ),
        );
      }

      final missing = requestedIds.difference(backedUpContacts.keys.toSet());
      final sortedMissing = missing.toList()..sort();
      if (sortedMissing.isNotEmpty) {
        return _finishValidation(
          generation,
          MergeBackupValidation(
            status: MergeBackupValidationStatus.sourceContactsMissing,
            backupId: backup.id,
            accessScope: data.backup.accessScope,
            requestedSourceIds: List<String>.unmodifiable(sortedRequestedIds),
            missingSourceIds: List<String>.unmodifiable(sortedMissing),
            sourceSnapshotFingerprint: snapshotFingerprint,
            groupRevisionFingerprint: groupRevisionFingerprint,
            generation: generation,
          ),
        );
      }

      final changed = <String>[];
      if (validateContent) {
        for (final id in sortedRequestedIds) {
          final snapshot = snapshotsById[id];
          final backedUpContact = backedUpContacts[id];
          if (snapshot == null ||
              backedUpContact == null ||
              !_matchesSourceSnapshot(backedUpContact, snapshot)) {
            changed.add(id);
          }
        }
      }
      if (changed.isNotEmpty) {
        return _finishValidation(
          generation,
          MergeBackupValidation(
            status: MergeBackupValidationStatus.sourceContactsChanged,
            backupId: backup.id,
            accessScope: data.backup.accessScope,
            requestedSourceIds: List<String>.unmodifiable(sortedRequestedIds),
            changedSourceIds: List<String>.unmodifiable(changed),
            sourceSnapshotFingerprint: snapshotFingerprint,
            groupRevisionFingerprint: groupRevisionFingerprint,
            generation: generation,
          ),
        );
      }

      return _finishValidation(
        generation,
        MergeBackupValidation(
          status: MergeBackupValidationStatus.valid,
          backupId: backup.id,
          accessScope: data.backup.accessScope,
          requestedSourceIds: List<String>.unmodifiable(sortedRequestedIds),
          sourceContentValidated: validateContent,
          sourceSnapshotFingerprint: snapshotFingerprint,
          groupRevisionFingerprint: groupRevisionFingerprint,
          generation: generation,
        ),
      );
    } on ContactBackupException catch (error) {
      return _finishValidation(
        generation,
        MergeBackupValidation(
          status: MergeBackupValidationStatus.failed,
          backupId: backup.id,
          accessScope: backup.accessScope,
          requestedSourceIds: List<String>.unmodifiable(sortedRequestedIds),
          sourceSnapshotFingerprint: snapshotFingerprint,
          groupRevisionFingerprint: groupRevisionFingerprint,
          generation: generation,
          errorCode: error.code,
        ),
      );
    } on Object {
      return _finishValidation(
        generation,
        MergeBackupValidation(
          status: MergeBackupValidationStatus.failed,
          backupId: backup.id,
          accessScope: backup.accessScope,
          requestedSourceIds: List<String>.unmodifiable(sortedRequestedIds),
          sourceSnapshotFingerprint: snapshotFingerprint,
          groupRevisionFingerprint: groupRevisionFingerprint,
          generation: generation,
          errorCode: 'merge_backup_validation_failed',
        ),
      );
    }
  }

  MergeBackupValidation _finishValidation(
    int generation,
    MergeBackupValidation validation,
  ) {
    if (!_isDisposed && generation == _validationGeneration) {
      _mergeValidation = validation;
      _isValidatingMergeSources = false;
      _inFlightValidation = null;
      _inFlightValidationKey = null;
      _notifySafely();
    }
    return validation;
  }

  MergeBackupValidation _immediateValidation({
    required List<String> requestedIds,
    required String errorCode,
    String? sourceSnapshotFingerprint,
    String? groupRevisionFingerprint,
  }) {
    final backup = latestMergeEligibleBackup;
    final validation = MergeBackupValidation(
      status: MergeBackupValidationStatus.failed,
      backupId: backup?.id,
      accessScope: backup?.accessScope ?? BackupAccessScope.unknown,
      requestedSourceIds: List<String>.unmodifiable(requestedIds),
      sourceSnapshotFingerprint: sourceSnapshotFingerprint,
      groupRevisionFingerprint: groupRevisionFingerprint,
      generation: _validationGeneration,
      errorCode: errorCode,
    );
    if (!_isDisposed && !_isValidatingMergeSources) {
      _mergeValidation = validation;
      _notifySafely();
    }
    return validation;
  }

  bool _matchesSourceSnapshot(Contact contact, MergeSourceSnapshot snapshot) {
    final expectedName = _normalizer.exactNameKey(snapshot.displayName);
    final actualNames = <String>{
      _normalizer.exactNameKey(contact.displayName ?? ''),
      _normalizer.exactNameKey(contact.name?.first ?? ''),
    }..removeWhere((value) => value.isEmpty);
    if (actualNames.isEmpty) {
      actualNames.add(_normalizer.exactNameKey('Contact fara nume'));
    }
    if (!actualNames.contains(expectedName)) return false;

    final expectedPhones = snapshot.phones
        .map(_normalizer.normalizePhone)
        .where((value) => value.isNotEmpty)
        .toSet();
    final actualPhones = contact.phones
        .map((phone) => _normalizer.normalizePhone(phone.number))
        .where((value) => value.isNotEmpty)
        .toSet();
    if (!setEquals(expectedPhones, actualPhones)) return false;

    final expectedEmails = snapshot.emails
        .map(_normalizer.normalizeEmail)
        .where((value) => value.isNotEmpty)
        .toSet();
    final actualEmails = contact.emails
        .map((email) => _normalizer.normalizeEmail(email.address))
        .where((value) => value.isNotEmpty)
        .toSet();
    return setEquals(expectedEmails, actualEmails);
  }

  String _snapshotFingerprint(Iterable<MergeSourceSnapshot> snapshots) {
    final parts = snapshots.map((snapshot) {
      final phones = snapshot.phones
          .map(_normalizer.normalizePhone)
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      final emails = snapshot.emails
          .map(_normalizer.normalizeEmail)
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return stableOpaqueId(
        <String>[
          snapshot.id.trim(),
          _normalizer.exactNameKey(snapshot.displayName),
          ...phones,
          ...emails,
        ],
        namespace: 'backup-source',
      );
    });
    return stableOpaqueId(parts, namespace: 'backup-snapshot');
  }

  void invalidateMergeContext() => _invalidateMergeValidation();
  void clearMergeValidation() => _invalidateMergeValidation();

  void _invalidateMergeValidation({bool notify = true}) {
    _validationGeneration++;
    _mergeValidation = null;
    _inFlightValidation = null;
    _inFlightValidationKey = null;
    _isValidatingMergeSources = false;
    if (notify) _notifySafely();
  }

  void clearError() {
    if (_status != BackupStatus.error &&
        _status != BackupStatus.permissionDenied) return;
    _status = BackupStatus.ready;
    _errorCode = null;
    _notifySafely();
  }

  @override
  void addListener(VoidCallback listener) {
    final hadListeners = hasListeners;
    super.addListener(listener);
    if (!hadListeners) _scheduleMergeEligibilityBoundary();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) _cancelMergeEligibilityTimer();
  }

  void _scheduleMergeEligibilityBoundary() {
    _cancelMergeEligibilityTimer();
    if (_isDisposed ||
        !hasListeners ||
        !_canScheduleEligibilityBoundaries) return;
    final now = _clock().toUtc();
    DateTime? nextBoundary;
    for (final backup in _backups) {
      if (!backup.isValid) continue;
      final createdAt = backup.createdAt.toUtc();
      DateTime? boundary;
      if (now.isBefore(createdAt)) {
        boundary = createdAt;
      } else {
        final expiresAt = createdAt.add(mergeBackupMaxAge);
        if (!now.isAfter(expiresAt)) {
          boundary = expiresAt.add(_boundaryPrecision);
        }
      }
      if (boundary != null &&
          (nextBoundary == null || boundary.isBefore(nextBoundary))) {
        nextBoundary = boundary;
      }
    }
    if (nextBoundary == null) return;
    final remaining = nextBoundary.difference(now);
    final delay = remaining <= Duration.zero ? _boundaryPrecision : remaining;
    _mergeEligibilityTimer = _timerFactory(delay, () {
      _mergeEligibilityTimer = null;
      if (_isDisposed) return;
      _invalidateExpiredMergeValidation();
      _notifySafely();
      _scheduleMergeEligibilityBoundary();
    });
  }

  void _invalidateExpiredMergeValidation() {
    final validation = _mergeValidation;
    if (validation == null || validation.backupId == null) return;
    ContactBackup? found;
    for (final backup in _backups) {
      if (backup.id == validation.backupId) {
        found = backup;
        break;
      }
    }
    if (found == null || !isMergeEligible(found)) {
      _invalidateMergeValidation(notify: false);
    }
  }

  void _cancelMergeEligibilityTimer() {
    _mergeEligibilityTimer?.cancel();
    _mergeEligibilityTimer = null;
  }

  void _notifySafely() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _validationGeneration++;
    _cancelMergeEligibilityTimer();
    _inFlightValidation = null;
    _inFlightValidationKey = null;
    _isValidatingMergeSources = false;
    super.dispose();
  }
}
