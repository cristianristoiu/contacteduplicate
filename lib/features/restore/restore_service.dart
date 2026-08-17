import 'dart:async';

import 'package:flutter_contacts/flutter_contacts.dart';

import '../../core/backup/contact_backup_service.dart';
import '../../core/contacts/contact_data_normalizer.dart';
import '../../core/contacts/contact_models.dart';

enum RestoreMode { targeted, full }
enum RestoreConflictPolicy { block, skipExisting, restoreMissingOnly }
enum RestoreItemStatus {
  restore,
  skipExisting,
  conflict,
  invalid,
  notTargeted,
}
enum RestoreExecutionStatus {
  success,
  partialSuccess,
  blocked,
  permissionDenied,
  cancelled,
  rollbackSucceeded,
  rollbackFailed,
  reconcileRequired,
}

class RestoreCancellationToken {
  bool _cancelRequested = false;
  bool _critical = false;

  bool get isCancelled => _cancelRequested;
  bool get canCancel => !_critical;

  void cancel() => _cancelRequested = true;
  void enterCritical() => _critical = true;
  void leaveCritical() => _critical = false;

  void throwIfCancelled() {
    if (_cancelRequested && !_critical) throw const _RestoreCancelled();
  }
}

class RestorePreviewItem {
  final String backupContactId;
  final RestoreItemStatus status;
  final String backupFingerprint;
  final String? liveFingerprint;

  const RestorePreviewItem({
    required this.backupContactId,
    required this.status,
    required this.backupFingerprint,
    this.liveFingerprint,
  });
}

class RestorePreview {
  final String backupId;
  final RestoreMode mode;
  final List<RestorePreviewItem> items;
  final int restoreCount;
  final int skipCount;
  final int conflictCount;
  final int invalidCount;

  RestorePreview({
    required this.backupId,
    required this.mode,
    required Iterable<RestorePreviewItem> items,
  })  : items = List<RestorePreviewItem>.unmodifiable(items),
        restoreCount = items
            .where((item) => item.status == RestoreItemStatus.restore)
            .length,
        skipCount = items
            .where((item) =>
                item.status == RestoreItemStatus.skipExisting ||
                item.status == RestoreItemStatus.notTargeted)
            .length,
        conflictCount = items
            .where((item) => item.status == RestoreItemStatus.conflict)
            .length,
        invalidCount = items
            .where((item) => item.status == RestoreItemStatus.invalid)
            .length;

  bool get hasConflicts => conflictCount > 0;
  bool get hasWork => restoreCount > 0;
}

class RestoreReport {
  final RestoreExecutionStatus status;
  final String sourceBackupId;
  final String? safetyBackupId;
  final List<String> restoredIds;
  final List<String> skippedIds;
  final String? errorCode;
  final bool requiresReconcile;

  RestoreReport({
    required this.status,
    required this.sourceBackupId,
    this.safetyBackupId,
    Iterable<String> restoredIds = const <String>[],
    Iterable<String> skippedIds = const <String>[],
    this.errorCode,
    this.requiresReconcile = false,
  })  : restoredIds = List<String>.unmodifiable(restoredIds),
        skippedIds = List<String>.unmodifiable(skippedIds);

  bool get isSuccess => status == RestoreExecutionStatus.success;
}

abstract interface class RestoreContactGateway {
  Future<bool> requestWritePermission();
  Future<Map<String, Contact>> readContacts(Iterable<String> ids);
  Future<String> createContact(Contact contact);
  Future<Contact?> readContact(String id);
  Future<void> deleteContact(String id);
}

class NativeRestoreContactGateway implements RestoreContactGateway {
  @override
  Future<bool> requestWritePermission() async {
    final status = await FlutterContacts.permissions.request(
      PermissionType.readWrite,
    );
    return status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
  }

  @override
  Future<Map<String, Contact>> readContacts(Iterable<String> ids) async {
    final result = <String, Contact>{};
    for (final rawId in ids) {
      final id = rawId.trim();
      if (id.isEmpty) continue;
      final contact = await FlutterContacts.get(
        id,
        properties: ContactProperties.all,
      );
      if (contact != null) result[id] = contact;
    }
    return result;
  }

  @override
  Future<String> createContact(Contact contact) => FlutterContacts.create(contact);

  @override
  Future<Contact?> readContact(String id) => FlutterContacts.get(
        id,
        properties: ContactProperties.all,
      );

  @override
  Future<void> deleteContact(String id) => FlutterContacts.delete(id);
}

class ContactRestoreService {
  final ContactBackupService _backupService;
  final RestoreContactGateway _gateway;
  final ContactDataNormalizer _normalizer;
  final Duration operationTimeout;
  final int batchSize;

  Future<void> _mutex = Future<void>.value();

  ContactRestoreService({
    required ContactBackupService backupService,
    RestoreContactGateway? gateway,
    ContactDataNormalizer? normalizer,
    this.operationTimeout = const Duration(seconds: 20),
    this.batchSize = 20,
  })  : assert(operationTimeout > Duration.zero),
        assert(batchSize > 0 && batchSize <= 100),
        _backupService = backupService,
        _gateway = gateway ?? NativeRestoreContactGateway(),
        _normalizer = normalizer ?? ContactDataNormalizer();

  Future<RestorePreview> preview({
    required String backupId,
    RestoreMode mode = RestoreMode.full,
    Set<String> targetContactIds = const <String>{},
    RestoreConflictPolicy conflictPolicy = RestoreConflictPolicy.block,
  }) async {
    final id = backupId.trim();
    if (!RegExp(r'^\d+$').hasMatch(id)) {
      throw const ContactBackupException('backup_id_invalid');
    }
    final data = await _backupService.readBackup(id);
    if (!data.backup.isValid) {
      throw const ContactBackupException('backup_integrity_invalid');
    }

    final selected = _selectedContacts(
      data.contacts,
      mode: mode,
      targetContactIds: targetContactIds,
    );
    final ids = selected
        .map((contact) => contact.id?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet();
    final live = await _gateway.readContacts(ids).timeout(operationTimeout);
    final items = <RestorePreviewItem>[];

    for (final contact in data.contacts) {
      final sourceId = contact.id?.trim() ?? '';
      final sourceFingerprint = _contactFingerprint(contact);
      if (sourceId.isEmpty || sourceFingerprint.isEmpty) {
        items.add(
          RestorePreviewItem(
            backupContactId: sourceId,
            status: RestoreItemStatus.invalid,
            backupFingerprint: sourceFingerprint,
          ),
        );
        continue;
      }
      if (!ids.contains(sourceId)) {
        items.add(
          RestorePreviewItem(
            backupContactId: sourceId,
            status: RestoreItemStatus.notTargeted,
            backupFingerprint: sourceFingerprint,
          ),
        );
        continue;
      }
      final existing = live[sourceId];
      if (existing == null) {
        items.add(
          RestorePreviewItem(
            backupContactId: sourceId,
            status: RestoreItemStatus.restore,
            backupFingerprint: sourceFingerprint,
          ),
        );
        continue;
      }
      final liveFingerprint = _contactFingerprint(existing);
      final identical = liveFingerprint == sourceFingerprint;
      final status = identical || conflictPolicy == RestoreConflictPolicy.skipExisting
          ? RestoreItemStatus.skipExisting
          : conflictPolicy == RestoreConflictPolicy.restoreMissingOnly
              ? RestoreItemStatus.skipExisting
              : RestoreItemStatus.conflict;
      items.add(
        RestorePreviewItem(
          backupContactId: sourceId,
          status: status,
          backupFingerprint: sourceFingerprint,
          liveFingerprint: liveFingerprint,
        ),
      );
    }

    return RestorePreview(backupId: id, mode: mode, items: items);
  }

  Future<RestoreReport> restore({
    required String backupId,
    required bool userConfirmed,
    RestoreMode mode = RestoreMode.full,
    Set<String> targetContactIds = const <String>{},
    RestoreConflictPolicy conflictPolicy = RestoreConflictPolicy.block,
    RestoreCancellationToken? cancellationToken,
  }) {
    final completer = Completer<RestoreReport>();
    _mutex = _mutex.catchError((Object _) {}).then((_) async {
      try {
        completer.complete(
          await _restoreLocked(
            backupId: backupId,
            userConfirmed: userConfirmed,
            mode: mode,
            targetContactIds: targetContactIds,
            conflictPolicy: conflictPolicy,
            cancellationToken: cancellationToken,
          ),
        );
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<RestoreReport> _restoreLocked({
    required String backupId,
    required bool userConfirmed,
    required RestoreMode mode,
    required Set<String> targetContactIds,
    required RestoreConflictPolicy conflictPolicy,
    RestoreCancellationToken? cancellationToken,
  }) async {
    final token = cancellationToken ?? RestoreCancellationToken();
    final sourceBackupId = backupId.trim();
    if (!userConfirmed) {
      return RestoreReport(
        status: RestoreExecutionStatus.blocked,
        sourceBackupId: sourceBackupId,
        errorCode: 'restore_confirmation_required',
      );
    }

    try {
      token.throwIfCancelled();
      final initialPreview = await preview(
        backupId: sourceBackupId,
        mode: mode,
        targetContactIds: targetContactIds,
        conflictPolicy: conflictPolicy,
      );
      if (initialPreview.hasConflicts &&
          conflictPolicy == RestoreConflictPolicy.block) {
        return RestoreReport(
          status: RestoreExecutionStatus.blocked,
          sourceBackupId: sourceBackupId,
          errorCode: 'restore_conflict_requires_resolution',
        );
      }
      if (!initialPreview.hasWork) {
        return RestoreReport(
          status: RestoreExecutionStatus.success,
          sourceBackupId: sourceBackupId,
          skippedIds: initialPreview.items
              .where((item) => item.status != RestoreItemStatus.restore)
              .map((item) => item.backupContactId),
        );
      }

      token.throwIfCancelled();
      final safetyBackup = await _backupService.createBackup();
      if (!safetyBackup.isValid) {
        return RestoreReport(
          status: RestoreExecutionStatus.blocked,
          sourceBackupId: sourceBackupId,
          errorCode: 'restore_safety_backup_invalid',
        );
      }

      final hasPermission = await _gateway
          .requestWritePermission()
          .timeout(operationTimeout);
      if (!hasPermission) {
        return RestoreReport(
          status: RestoreExecutionStatus.permissionDenied,
          sourceBackupId: sourceBackupId,
          safetyBackupId: safetyBackup.id,
          errorCode: 'contacts_write_permission_denied',
        );
      }

      token.throwIfCancelled();
      final sourceData = await _backupService.readBackup(sourceBackupId);
      if (!sourceData.backup.isValid) {
        return RestoreReport(
          status: RestoreExecutionStatus.blocked,
          sourceBackupId: sourceBackupId,
          safetyBackupId: safetyBackup.id,
          errorCode: 'restore_source_backup_changed',
        );
      }
      final finalPreview = await preview(
        backupId: sourceBackupId,
        mode: mode,
        targetContactIds: targetContactIds,
        conflictPolicy: conflictPolicy,
      );
      if (finalPreview.hasConflicts &&
          conflictPolicy == RestoreConflictPolicy.block) {
        return RestoreReport(
          status: RestoreExecutionStatus.blocked,
          sourceBackupId: sourceBackupId,
          safetyBackupId: safetyBackup.id,
          errorCode: 'restore_live_state_changed',
        );
      }

      final restoreIds = finalPreview.items
          .where((item) => item.status == RestoreItemStatus.restore)
          .map((item) => item.backupContactId)
          .toSet();
      final selectedContacts = sourceData.contacts
          .where((contact) => restoreIds.contains(contact.id?.trim()))
          .toList(growable: false);
      final restoredNativeIds = <String>[];
      final restoredSourceIds = <String>[];
      final skippedIds = finalPreview.items
          .where((item) => item.status != RestoreItemStatus.restore)
          .map((item) => item.backupContactId)
          .toList();

      for (var offset = 0; offset < selectedContacts.length; offset += batchSize) {
        token.throwIfCancelled();
        final end = offset + batchSize < selectedContacts.length
            ? offset + batchSize
            : selectedContacts.length;
        final batch = selectedContacts.sublist(offset, end);
        token.enterCritical();
        try {
          for (final contact in batch) {
            final sourceId = contact.id?.trim() ?? '';
            final createdId = await _gateway
                .createContact(contact)
                .timeout(operationTimeout);
            final id = createdId.trim();
            if (id.isEmpty) throw StateError('restore_created_id_empty');
            restoredNativeIds.add(id);
            final created = await _gateway.readContact(id).timeout(operationTimeout);
            if (created == null ||
                _contactFingerprint(created) != _contactFingerprint(contact)) {
              throw StateError('restore_verification_failed');
            }
            restoredSourceIds.add(sourceId);
          }
        } on Object {
          final rollbackOk = await _rollbackCreated(restoredNativeIds);
          return RestoreReport(
            status: rollbackOk
                ? RestoreExecutionStatus.rollbackSucceeded
                : RestoreExecutionStatus.rollbackFailed,
            sourceBackupId: sourceBackupId,
            safetyBackupId: safetyBackup.id,
            restoredIds: rollbackOk ? const <String>[] : restoredSourceIds,
            skippedIds: skippedIds,
            errorCode: rollbackOk
                ? 'restore_failed_rolled_back'
                : 'restore_failed_rollback_incomplete',
            requiresReconcile: !rollbackOk,
          );
        } finally {
          token.leaveCritical();
        }
      }

      return RestoreReport(
        status: skippedIds.isEmpty
            ? RestoreExecutionStatus.success
            : RestoreExecutionStatus.partialSuccess,
        sourceBackupId: sourceBackupId,
        safetyBackupId: safetyBackup.id,
        restoredIds: restoredSourceIds,
        skippedIds: skippedIds,
      );
    } on _RestoreCancelled {
      return RestoreReport(
        status: RestoreExecutionStatus.cancelled,
        sourceBackupId: sourceBackupId,
        errorCode: 'restore_cancelled',
      );
    } on TimeoutException {
      return RestoreReport(
        status: RestoreExecutionStatus.reconcileRequired,
        sourceBackupId: sourceBackupId,
        errorCode: 'restore_native_timeout_unknown_state',
        requiresReconcile: true,
      );
    } on ContactBackupException catch (error) {
      return RestoreReport(
        status: RestoreExecutionStatus.blocked,
        sourceBackupId: sourceBackupId,
        errorCode: error.code,
      );
    } on Object {
      return RestoreReport(
        status: RestoreExecutionStatus.reconcileRequired,
        sourceBackupId: sourceBackupId,
        errorCode: 'restore_unexpected_failure',
        requiresReconcile: true,
      );
    }
  }

  List<Contact> _selectedContacts(
    List<Contact> contacts, {
    required RestoreMode mode,
    required Set<String> targetContactIds,
  }) {
    if (mode == RestoreMode.full) return contacts;
    final targets = targetContactIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    return contacts
        .where((contact) => targets.contains(contact.id?.trim()))
        .toList(growable: false);
  }

  Future<bool> _rollbackCreated(List<String> createdIds) async {
    var ok = true;
    for (final id in createdIds.reversed) {
      try {
        await _gateway.deleteContact(id).timeout(operationTimeout);
        final remaining = await _gateway.readContact(id).timeout(operationTimeout);
        if (remaining != null) ok = false;
      } on Object {
        ok = false;
      }
    }
    return ok;
  }

  String _contactFingerprint(Contact contact) {
    final id = contact.id?.trim() ?? '';
    final names = <String>[
      contact.displayName ?? '',
      contact.name?.first ?? '',
      contact.name?.middle ?? '',
      contact.name?.last ?? '',
    ].map(_normalizer.exactNameKey).where((value) => value.isNotEmpty).toList();
    final phones = contact.phones
        .map((value) => _normalizer.normalizePhone(value.number))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final emails = contact.emails
        .map((value) => _normalizer.normalizeEmail(value.address))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (names.isEmpty && phones.isEmpty && emails.isEmpty) return '';
    return stableOpaqueId(
      <String>[id, ...names, ...phones, ...emails],
      namespace: 'restore-contact',
    );
  }
}

class _RestoreCancelled implements Exception {
  const _RestoreCancelled();
}
