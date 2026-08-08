import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../core/backup/contact_backup_service.dart';

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
}

@immutable
class MergeBackupValidation {
  final MergeBackupValidationStatus status;
  final String? backupId;
  final List<String> requestedSourceIds;
  final List<String> missingSourceIds;
  final List<String> changedSourceIds;
  final bool sourceContentValidated;
  final String? errorCode;

  const MergeBackupValidation({
    required this.status,
    required this.backupId,
    required this.requestedSourceIds,
    this.missingSourceIds = const <String>[],
    this.changedSourceIds = const <String>[],
    this.sourceContentValidated = false,
    this.errorCode,
  });

  bool get isValid => status == MergeBackupValidationStatus.valid;

  bool matchesSources(Iterable<String> sourceIds) {
    final normalized = sourceIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    return setEquals(normalized, requestedSourceIds.toSet());
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
  static const String _defaultCountryCallingCode = '40';

  final ContactBackupService _service;
  final BackupControllerClock _clock;
  final BackupControllerTimerFactory _timerFactory;
  final bool _canScheduleEligibilityBoundaries;
  final Duration mergeBackupMaxAge;

  BackupStatus _status = BackupStatus.idle;
  List<ContactBackup> _backups = const <ContactBackup>[];
  String? _errorCode;
  Timer? _mergeEligibilityTimer;
  MergeBackupValidation? _mergeValidation;
  bool _isValidatingMergeSources = false;
  bool _isDisposed = false;

  BackupController(
    this._service, {
    BackupControllerClock? clock,
    BackupControllerTimerFactory? timerFactory,
    this.mergeBackupMaxAge = defaultMergeBackupMaxAge,
  })  : assert(!mergeBackupMaxAge.isNegative),
        _clock = clock ?? DateTime.now,
        _timerFactory = timerFactory ?? _createBackupControllerTimer,
        _canScheduleEligibilityBoundaries =
            clock == null || timerFactory != null;

  BackupStatus get status => _status;

  List<ContactBackup> get backups => _backups;

  String? get errorCode => _errorCode;

  MergeBackupValidation? get mergeValidation => _mergeValidation;

  bool get isValidatingMergeSources => _isValidatingMergeSources;

  bool get isBusy =>
      _status == BackupStatus.loading ||
      _status == BackupStatus.creating ||
      _status == BackupStatus.deleting ||
      _isValidatingMergeSources;

  bool get hasValidatedBackup => _backups.any((backup) => backup.isValid);

  ContactBackup? get latestValidatedBackup {
    for (final backup in _backups) {
      if (backup.isValid) {
        return backup;
      }
    }
    return null;
  }

  ContactBackup? get latestMergeEligibleBackup {
    for (final backup in _backups) {
      if (isMergeEligible(backup)) {
        return backup;
      }
    }
    return null;
  }

  bool isMergeEligible(ContactBackup backup) {
    if (!backup.isValid) {
      return false;
    }

    final age = _clock().toUtc().difference(backup.createdAt.toUtc());
    return !age.isNegative && age <= mergeBackupMaxAge;
  }

  Future<void> load() async {
    if (isBusy) {
      return;
    }

    _status = BackupStatus.loading;
    _errorCode = null;
    _mergeValidation = null;
    _notifySafely();

    try {
      _backups = await _service.listBackups();
      _status = BackupStatus.ready;
      _scheduleMergeEligibilityBoundary();
    } on ContactBackupException catch (error) {
      _status = BackupStatus.error;
      _errorCode = error.code;
    } on Object {
      _status = BackupStatus.error;
      _errorCode = 'backup_list_failed';
    }
    _notifySafely();
  }

  Future<ContactBackup?> create() async {
    if (isBusy) {
      return null;
    }

    _status = BackupStatus.creating;
    _errorCode = null;
    _mergeValidation = null;
    _notifySafely();

    try {
      final backup = await _service.createBackup();
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
      _status = error.code == 'contacts_permission_denied'
          ? BackupStatus.permissionDenied
          : BackupStatus.error;
      _errorCode = error.code;
    } on Object {
      _status = BackupStatus.error;
      _errorCode = 'backup_create_failed';
    }
    _notifySafely();
    return null;
  }

  Future<bool> delete(String id) async {
    if (isBusy) {
      return false;
    }

    _status = BackupStatus.deleting;
    _errorCode = null;
    _mergeValidation = null;
    _notifySafely();

    try {
      await _service.deleteBackup(id);
      _backups = List<ContactBackup>.unmodifiable(
        _backups.where((backup) => backup.id != id),
      );
      _status = BackupStatus.ready;
      _scheduleMergeEligibilityBoundary();
      _notifySafely();
      return true;
    } on ContactBackupException catch (error) {
      _status = BackupStatus.error;
      _errorCode = error.code;
    } on Object {
      _status = BackupStatus.error;
      _errorCode = 'backup_delete_failed';
    }
    _notifySafely();
    return false;
  }

  Future<MergeBackupValidation> validateMergeSources(
    Iterable<String> sourceIds, {
    Iterable<MergeSourceSnapshot> sourceSnapshots =
        const <MergeSourceSnapshot>[],
  }) async {
    final requestedIds = sourceIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final sortedRequestedIds = requestedIds.toList()..sort();
    final snapshotsById = <String, MergeSourceSnapshot>{};
    for (final snapshot in sourceSnapshots) {
      final id = snapshot.id.trim();
      if (id.isNotEmpty) {
        snapshotsById[id] = snapshot;
      }
    }
    final validateContent = snapshotsById.isNotEmpty;

    if (requestedIds.isEmpty) {
      final validation = MergeBackupValidation(
        status: MergeBackupValidationStatus.failed,
        backupId: null,
        requestedSourceIds: const <String>[],
        errorCode: 'merge_source_ids_missing',
      );
      _mergeValidation = validation;
      _notifySafely();
      return validation;
    }

    if (validateContent && !setEquals(requestedIds, snapshotsById.keys.toSet())) {
      final validation = MergeBackupValidation(
        status: MergeBackupValidationStatus.failed,
        backupId: latestMergeEligibleBackup?.id,
        requestedSourceIds: List<String>.unmodifiable(sortedRequestedIds),
        errorCode: 'merge_source_snapshot_mismatch',
      );
      _mergeValidation = validation;
      _notifySafely();
      return validation;
    }

    if (isBusy) {
      final validation = MergeBackupValidation(
        status: MergeBackupValidationStatus.failed,
        backupId: latestMergeEligibleBackup?.id,
        requestedSourceIds: List<String>.unmodifiable(sortedRequestedIds),
        errorCode: 'backup_operation_busy',
      );
      _mergeValidation = validation;
      _notifySafely();
      return validation;
    }

    final backup = latestMergeEligibleBackup;
    if (backup == null) {
      final validation = MergeBackupValidation(
        status: MergeBackupValidationStatus.noEligibleBackup,
        backupId: null,
        requestedSourceIds: List<String>.unmodifiable(sortedRequestedIds),
      );
      _mergeValidation = validation;
      _notifySafely();
      return validation;
    }

    _isValidatingMergeSources = true;
    _mergeValidation = null;
    _notifySafely();

    try {
      final data = await _service.readBackup(backup.id);
      if (data.backup.id != backup.id || !isMergeEligible(data.backup)) {
        final validation = MergeBackupValidation(
          status: MergeBackupValidationStatus.backupExpired,
          backupId: backup.id,
          requestedSourceIds: List<String>.unmodifiable(sortedRequestedIds),
        );
        _mergeValidation = validation;
        return validation;
      }

      final backedUpContacts = <String, Contact>{};
      for (final contact in data.contacts) {
        final id = contact.id?.trim();
        if (id != null && id.isNotEmpty) {
          backedUpContacts[id] = contact;
        }
      }
      final missingIds = requestedIds.difference(backedUpContacts.keys.toSet())
        ..removeWhere((id) => id.isEmpty);
      final sortedMissingIds = missingIds.toList()..sort();
      if (sortedMissingIds.isNotEmpty) {
        final validation = MergeBackupValidation(
          status: MergeBackupValidationStatus.sourceContactsMissing,
          backupId: backup.id,
          requestedSourceIds: List<String>.unmodifiable(sortedRequestedIds),
          missingSourceIds: List<String>.unmodifiable(sortedMissingIds),
        );
        _mergeValidation = validation;
        return validation;
      }

      if (validateContent) {
        final changedIds = <String>[];
        for (final id in sortedRequestedIds) {
          final snapshot = snapshotsById[id];
          final backedUpContact = backedUpContacts[id];
          if (snapshot == null ||
              backedUpContact == null ||
              !_matchesSourceSnapshot(backedUpContact, snapshot)) {
            changedIds.add(id);
          }
        }
        if (changedIds.isNotEmpty) {
          final validation = MergeBackupValidation(
            status: MergeBackupValidationStatus.sourceContactsChanged,
            backupId: backup.id,
            requestedSourceIds: List<String>.unmodifiable(sortedRequestedIds),
            changedSourceIds: List<String>.unmodifiable(changedIds),
          );
          _mergeValidation = validation;
          return validation;
        }
      }

      final validation = MergeBackupValidation(
        status: MergeBackupValidationStatus.valid,
        backupId: backup.id,
        requestedSourceIds: List<String>.unmodifiable(sortedRequestedIds),
        sourceContentValidated: validateContent,
      );
      _mergeValidation = validation;
      return validation;
    } on ContactBackupException catch (error) {
      final validation = MergeBackupValidation(
        status: MergeBackupValidationStatus.failed,
        backupId: backup.id,
        requestedSourceIds: List<String>.unmodifiable(sortedRequestedIds),
        errorCode: error.code,
      );
      _mergeValidation = validation;
      return validation;
    } on Object {
      final validation = MergeBackupValidation(
        status: MergeBackupValidationStatus.failed,
        backupId: backup.id,
        requestedSourceIds: List<String>.unmodifiable(sortedRequestedIds),
        errorCode: 'merge_backup_validation_failed',
      );
      _mergeValidation = validation;
      return validation;
    } finally {
      _isValidatingMergeSources = false;
      _notifySafely();
    }
  }

  bool _matchesSourceSnapshot(
    Contact backedUpContact,
    MergeSourceSnapshot snapshot,
  ) {
    final expectedName = _normalizeName(snapshot.displayName);
    final actualNames = <String>{};
    final displayName = backedUpContact.displayName;
    final firstName = backedUpContact.name?.first;
    if (displayName != null && displayName.trim().isNotEmpty) {
      actualNames.add(_normalizeName(displayName));
    }
    if (firstName != null && firstName.trim().isNotEmpty) {
      actualNames.add(_normalizeName(firstName));
    }
    if (actualNames.isEmpty) {
      actualNames.add(_normalizeName('Contact fara nume'));
    }
    if (!actualNames.contains(expectedName)) {
      return false;
    }

    final expectedPhones = snapshot.phones
        .map(_normalizePhoneForSnapshot)
        .where((value) => value.isNotEmpty)
        .toSet();
    final actualPhones = backedUpContact.phones
        .map((phone) => _normalizePhoneForSnapshot(phone.number))
        .where((value) => value.isNotEmpty)
        .toSet();
    if (!setEquals(expectedPhones, actualPhones)) {
      return false;
    }

    final expectedEmails = snapshot.emails
        .map(_normalizeEmailForSnapshot)
        .where((value) => value.isNotEmpty)
        .toSet();
    final actualEmails = backedUpContact.emails
        .map((email) => _normalizeEmailForSnapshot(email.address))
        .where((value) => value.isNotEmpty)
        .toSet();
    return setEquals(expectedEmails, actualEmails);
  }

  String _normalizeName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  String _normalizePhoneForSnapshot(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final compact = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
    if (compact.isEmpty) {
      return 'raw:${trimmed.toLowerCase()}';
    }

    var normalized = compact;
    if (normalized.startsWith('00')) {
      normalized = '+${normalized.substring(2)}';
    }
    final plusCount = '+'.allMatches(normalized).length;
    if (plusCount > 1 ||
        (normalized.contains('+') && !normalized.startsWith('+'))) {
      return 'raw:${trimmed.toLowerCase()}';
    }

    final digits = normalized.replaceAll('+', '');
    if (normalized.startsWith('0') && digits.length >= 9) {
      return '+$_defaultCountryCallingCode${normalized.substring(1)}';
    }
    return normalized;
  }

  String _normalizeEmailForSnapshot(String value) {
    return value.trim().toLowerCase();
  }

  void clearMergeValidation() {
    if (_mergeValidation == null) {
      return;
    }
    _mergeValidation = null;
    _notifySafely();
  }

  void clearError() {
    if (_status != BackupStatus.error &&
        _status != BackupStatus.permissionDenied) {
      return;
    }

    _status = BackupStatus.ready;
    _errorCode = null;
    _notifySafely();
  }

  @override
  void addListener(VoidCallback listener) {
    final hadListeners = hasListeners;
    super.addListener(listener);
    if (!hadListeners) {
      _scheduleMergeEligibilityBoundary();
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _cancelMergeEligibilityTimer();
    }
  }

  void _scheduleMergeEligibilityBoundary() {
    _cancelMergeEligibilityTimer();
    if (_isDisposed ||
        !hasListeners ||
        !_canScheduleEligibilityBoundaries) {
      return;
    }

    final now = _clock().toUtc();
    DateTime? nextBoundary;

    for (final backup in _backups) {
      if (!backup.isValid) {
        continue;
      }

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

    if (nextBoundary == null) {
      return;
    }

    final remaining = nextBoundary.difference(now);
    final delay = remaining <= Duration.zero ? _boundaryPrecision : remaining;
    _mergeEligibilityTimer = _timerFactory(delay, () {
      _mergeEligibilityTimer = null;
      if (_isDisposed) {
        return;
      }
      _invalidateExpiredMergeValidation();
      _notifySafely();
      _scheduleMergeEligibilityBoundary();
    });
  }

  void _invalidateExpiredMergeValidation() {
    final validation = _mergeValidation;
    if (validation == null || validation.backupId == null) {
      return;
    }
    final backup = _backups.cast<ContactBackup?>().firstWhere(
          (candidate) => candidate?.id == validation.backupId,
          orElse: () => null,
        );
    if (backup == null || !isMergeEligible(backup)) {
      _mergeValidation = null;
    }
  }

  void _cancelMergeEligibilityTimer() {
    _mergeEligibilityTimer?.cancel();
    _mergeEligibilityTimer = null;
  }

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelMergeEligibilityTimer();
    super.dispose();
  }
}
