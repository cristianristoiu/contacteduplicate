import 'dart:async';

import 'package:contacte_duplicate/core/backup/contact_backup_service.dart';
import 'package:contacte_duplicate/features/backup/backup_controller.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const snapshots = <MergeSourceSnapshot>[
    MergeSourceSnapshot(
      id: 'a',
      displayName: 'Ana Popescu',
      phones: <String>['0712 345 678'],
      emails: <String>['ANA@example.com'],
    ),
    MergeSourceSnapshot(
      id: 'b',
      displayName: 'Ion Ionescu',
      phones: <String>['+40 722 333 444'],
      emails: <String>[],
    ),
  ];

  test('confirma continutul contactelor sursa prezent in backup', () async {
    final now = DateTime.utc(2026, 7, 27, 12);
    final backup = _backup(now.subtract(const Duration(minutes: 1)));
    final service = _ValidationBackupService(
      backup: backup,
      contacts: const <Contact>[
        Contact(
          id: 'a',
          displayName: 'Ana Popescu',
          name: Name(first: 'Ana Popescu'),
          phones: <Phone>[Phone(number: '+40712345678')],
          emails: <Email>[Email(address: 'ana@example.com')],
        ),
        Contact(
          id: 'b',
          displayName: 'Ion Ionescu',
          name: Name(first: 'Ion Ionescu'),
          phones: <Phone>[Phone(number: '0722333444')],
        ),
      ],
    );
    final controller = BackupController(service, clock: () => now);
    await controller.load();

    final result = await controller.validateMergeSources(
      <String>['a', 'b'],
      sourceSnapshots: snapshots,
    );

    expect(result.status, MergeBackupValidationStatus.valid);
    expect(result.isValid, isTrue);
    expect(result.sourceContentValidated, isTrue);
    expect(result.missingSourceIds, isEmpty);
    expect(result.changedSourceIds, isEmpty);
    expect(result.matchesSources(<String>['b', 'a']), isTrue);
    expect(service.readCalls, 1);
  });

  test('refuza backupul cand continutul unei surse s-a schimbat', () async {
    final now = DateTime.utc(2026, 7, 27, 12);
    final backup = _backup(now.subtract(const Duration(minutes: 1)));
    final service = _ValidationBackupService(
      backup: backup,
      contacts: const <Contact>[
        Contact(
          id: 'a',
          displayName: 'Ana Popescu',
          name: Name(first: 'Ana Popescu'),
          phones: <Phone>[Phone(number: '0799999999')],
          emails: <Email>[Email(address: 'ana@example.com')],
        ),
        Contact(
          id: 'b',
          displayName: 'Ion Ionescu',
          name: Name(first: 'Ion Ionescu'),
          phones: <Phone>[Phone(number: '0722333444')],
        ),
      ],
    );
    final controller = BackupController(service, clock: () => now);
    await controller.load();

    final result = await controller.validateMergeSources(
      <String>['a', 'b'],
      sourceSnapshots: snapshots,
    );

    expect(
      result.status,
      MergeBackupValidationStatus.sourceContactsChanged,
    );
    expect(result.isValid, isFalse);
    expect(result.changedSourceIds, <String>['a']);
    expect(result.sourceContentValidated, isFalse);
  });

  test('refuza backupul care nu contine toate contactele sursa', () async {
    final now = DateTime.utc(2026, 7, 27, 12);
    final backup = _backup(now.subtract(const Duration(minutes: 1)));
    final service = _ValidationBackupService(
      backup: backup,
      contacts: const <Contact>[
        Contact(
          id: 'a',
          displayName: 'Ana Popescu',
          name: Name(first: 'Ana Popescu'),
          phones: <Phone>[Phone(number: '+40712345678')],
          emails: <Email>[Email(address: 'ana@example.com')],
        ),
      ],
    );
    final controller = BackupController(service, clock: () => now);
    await controller.load();

    final result = await controller.validateMergeSources(
      <String>['a', 'b'],
      sourceSnapshots: snapshots,
    );

    expect(
      result.status,
      MergeBackupValidationStatus.sourceContactsMissing,
    );
    expect(result.isValid, isFalse);
    expect(result.missingSourceIds, <String>['b']);
  });

  test('refuza backupul care expira in timpul verificarii', () async {
    var now = DateTime.utc(2026, 7, 27, 12);
    final backup = _backup(now.subtract(const Duration(minutes: 4)));
    final completer = Completer<ContactBackupData>();
    final service = _ValidationBackupService(
      backup: backup,
      contacts: const <Contact>[Contact(id: 'a')],
      readCompleter: completer,
    );
    final controller = BackupController(service, clock: () => now);
    await controller.load();

    final validation = controller.validateMergeSources(<String>['a']);
    now = now.add(const Duration(minutes: 2));
    completer.complete(
      ContactBackupData(
        backup: backup,
        contacts: const <Contact>[Contact(id: 'a')],
      ),
    );

    final result = await validation;

    expect(result.status, MergeBackupValidationStatus.backupExpired);
    expect(result.isValid, isFalse);
  });

  test('refuza snapshoturile care nu corespund identificatorilor ceruti', () async {
    final now = DateTime.utc(2026, 7, 27, 12);
    final backup = _backup(now.subtract(const Duration(minutes: 1)));
    final controller = BackupController(
      _ValidationBackupService(backup: backup),
      clock: () => now,
    );
    await controller.load();

    final result = await controller.validateMergeSources(
      const <String>['a', 'b'],
      sourceSnapshots: const <MergeSourceSnapshot>[
        MergeSourceSnapshot(
          id: 'a',
          displayName: 'Ana Popescu',
          phones: <String>[],
          emails: <String>['ana@example.com'],
        ),
      ],
    );

    expect(result.status, MergeBackupValidationStatus.failed);
    expect(result.errorCode, 'merge_source_snapshot_mismatch');
  });

  test('refuza validarea fara identificatori de contact', () async {
    final now = DateTime.utc(2026, 7, 27, 12);
    final backup = _backup(now.subtract(const Duration(minutes: 1)));
    final controller = BackupController(
      _ValidationBackupService(backup: backup),
      clock: () => now,
    );
    await controller.load();

    final result = await controller.validateMergeSources(
      const <String>['', '   '],
    );

    expect(result.status, MergeBackupValidationStatus.failed);
    expect(result.errorCode, 'merge_source_ids_missing');
  });
}

ContactBackup _backup(DateTime createdAt) {
  return ContactBackup(
    id: '100',
    createdAt: createdAt,
    contactCount: 2,
    accessScope: BackupAccessScope.full,
    isValid: true,
  );
}

class _ValidationBackupService implements ContactBackupService {
  final ContactBackup backup;
  final List<Contact> contacts;
  final Completer<ContactBackupData>? readCompleter;
  int readCalls = 0;

  _ValidationBackupService({
    required this.backup,
    this.contacts = const <Contact>[],
    this.readCompleter,
  });

  @override
  Future<List<ContactBackup>> listBackups() async => <ContactBackup>[backup];

  @override
  Future<ContactBackupData> readBackup(String id) {
    readCalls++;
    final completer = readCompleter;
    if (completer != null) {
      return completer.future;
    }
    return Future<ContactBackupData>.value(
      ContactBackupData(backup: backup, contacts: contacts),
    );
  }

  @override
  Future<ContactBackup> createBackup() async => backup;

  @override
  Future<void> deleteBackup(String id) async {}
}
