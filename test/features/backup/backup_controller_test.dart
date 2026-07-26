import 'dart:async';

import 'package:contacte_duplicate/core/backup/contact_backup_service.dart';
import 'package:contacte_duplicate/features/backup/backup_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('incarca backupurile si expune ultima copie valida', () async {
    final older = ContactBackup(
      id: '1',
      createdAt: DateTime.utc(2026, 7, 26),
      contactCount: 3,
      accessScope: BackupAccessScope.full,
      isValid: true,
    );
    final newerInvalid = ContactBackup(
      id: '2',
      createdAt: DateTime.utc(2026, 7, 27),
      contactCount: 0,
      accessScope: BackupAccessScope.unknown,
      isValid: false,
    );
    final service = _FakeBackupService(
      listResult: <ContactBackup>[newerInvalid, older],
    );
    final controller = BackupController(service);

    await controller.load();

    expect(controller.status, BackupStatus.ready);
    expect(controller.backups, hasLength(2));
    expect(controller.hasValidatedBackup, isTrue);
    expect(controller.latestValidatedBackup?.id, '1');
  });

  test('accepta pentru fuziune doar backupul valid din ultimele 5 minute', () async {
    final now = DateTime.utc(2026, 7, 27, 12);
    final recent = ContactBackup(
      id: 'recent',
      createdAt: now.subtract(const Duration(minutes: 4)),
      contactCount: 5,
      accessScope: BackupAccessScope.full,
      isValid: true,
    );
    final expired = ContactBackup(
      id: 'expired',
      createdAt: now.subtract(const Duration(minutes: 6)),
      contactCount: 5,
      accessScope: BackupAccessScope.full,
      isValid: true,
    );
    final future = ContactBackup(
      id: 'future',
      createdAt: now.add(const Duration(seconds: 1)),
      contactCount: 5,
      accessScope: BackupAccessScope.full,
      isValid: true,
    );
    final controller = BackupController(
      _FakeBackupService(
        listResult: <ContactBackup>[future, recent, expired],
      ),
      clock: () => now,
    );

    await controller.load();

    expect(controller.isMergeEligible(recent), isTrue);
    expect(controller.isMergeEligible(expired), isFalse);
    expect(controller.isMergeEligible(future), isFalse);
    expect(controller.latestMergeEligibleBackup?.id, 'recent');
  });

  test('mapeaza refuzul permisiunii in starea dedicata', () async {
    final service = _FakeBackupService(
      createError: const ContactBackupException(
        'contacts_permission_denied',
      ),
    );
    final controller = BackupController(service);

    final result = await controller.create();

    expect(result, isNull);
    expect(controller.status, BackupStatus.permissionDenied);
    expect(controller.errorCode, 'contacts_permission_denied');
  });

  test('ignora a doua creare cat timp prima operatie ruleaza', () async {
    final completer = Completer<ContactBackup>();
    final service = _FakeBackupService(createCompleter: completer);
    final controller = BackupController(service);

    final first = controller.create();
    final second = controller.create();
    completer.complete(
      ContactBackup(
        id: '3',
        createdAt: DateTime.utc(2026, 7, 27, 12),
        contactCount: 5,
        accessScope: BackupAccessScope.full,
        isValid: true,
      ),
    );

    final results = await Future.wait<ContactBackup?>(<Future<ContactBackup?>>[
      first,
      second,
    ]);

    expect(service.createCalls, 1);
    expect(results.first?.id, '3');
    expect(results.last, isNull);
    expect(controller.status, BackupStatus.ready);
  });

  test('sterge copia selectata fara a afecta restul listei', () async {
    final backupA = ContactBackup(
      id: '10',
      createdAt: DateTime.utc(2026, 7, 27, 10),
      contactCount: 2,
      accessScope: BackupAccessScope.full,
      isValid: true,
    );
    final backupB = ContactBackup(
      id: '11',
      createdAt: DateTime.utc(2026, 7, 27, 11),
      contactCount: 4,
      accessScope: BackupAccessScope.full,
      isValid: true,
    );
    final service = _FakeBackupService(
      listResult: <ContactBackup>[backupB, backupA],
    );
    final controller = BackupController(service);
    await controller.load();

    final deleted = await controller.delete('11');

    expect(deleted, isTrue);
    expect(service.deletedIds, <String>['11']);
    expect(controller.backups.map((backup) => backup.id), <String>['10']);
  });
}

class _FakeBackupService implements ContactBackupService {
  final List<ContactBackup> listResult;
  final ContactBackupException? createError;
  final Completer<ContactBackup>? createCompleter;

  int createCalls = 0;
  final List<String> deletedIds = <String>[];

  _FakeBackupService({
    this.listResult = const <ContactBackup>[],
    this.createError,
    this.createCompleter,
  });

  @override
  Future<List<ContactBackup>> listBackups() async => listResult;

  @override
  Future<ContactBackup> createBackup() {
    createCalls++;
    final error = createError;
    if (error != null) {
      return Future<ContactBackup>.error(error);
    }
    final completer = createCompleter;
    if (completer != null) {
      return completer.future;
    }
    return Future<ContactBackup>.error(
      const ContactBackupException('backup_create_failed'),
    );
  }

  @override
  Future<void> deleteBackup(String id) async {
    deletedIds.add(id);
  }

  @override
  Future<ContactBackupData> readBackup(String id) async {
    throw const ContactBackupException('backup_not_found');
  }
}
