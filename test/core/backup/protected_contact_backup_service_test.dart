import 'package:contacte_duplicate/core/backup/contact_backup_service.dart';
import 'package:contacte_duplicate/core/backup/protected_contact_backup_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sterge backupul nou daca protectia sistemului esueaza', () async {
    final backup = ContactBackup(
      id: '100',
      createdAt: DateTime.utc(2026, 7, 27),
      contactCount: 2,
      accessScope: BackupAccessScope.full,
      isValid: true,
    );
    final delegate = _FakeBackupService(createdBackup: backup);
    final service = ProtectedContactBackupService(
      delegate: delegate,
      systemProtection: _FakeSystemProtection(shouldFail: true),
    );

    await expectLater(
      service.createBackup(),
      throwsA(
        isA<ContactBackupException>().having(
          (error) => error.code,
          'code',
          'backup_system_protection_failed',
        ),
      ),
    );

    expect(delegate.deletedIds, <String>['100']);
  });

  test('pastreaza backupul cand protectia sistemului reuseste', () async {
    final backup = ContactBackup(
      id: '101',
      createdAt: DateTime.utc(2026, 7, 27, 1),
      contactCount: 4,
      accessScope: BackupAccessScope.full,
      isValid: true,
    );
    final protection = _FakeSystemProtection();
    final delegate = _FakeBackupService(createdBackup: backup);
    final service = ProtectedContactBackupService(
      delegate: delegate,
      systemProtection: protection,
    );

    final created = await service.createBackup();

    expect(created.id, '101');
    expect(protection.calls, 1);
    expect(delegate.deletedIds, isEmpty);
  });

  test('protejeaza fisierele existente dupa listare', () async {
    final protection = _FakeSystemProtection();
    final delegate = _FakeBackupService(
      listedBackups: <ContactBackup>[
        ContactBackup(
          id: '102',
          createdAt: DateTime.utc(2026, 7, 27, 2),
          contactCount: 1,
          accessScope: BackupAccessScope.limited,
          isValid: true,
        ),
      ],
    );
    final service = ProtectedContactBackupService(
      delegate: delegate,
      systemProtection: protection,
    );

    final backups = await service.listBackups();

    expect(backups.single.id, '102');
    expect(protection.calls, 1);
  });
}

class _FakeSystemProtection implements BackupSystemProtection {
  final bool shouldFail;
  int calls = 0;

  _FakeSystemProtection({this.shouldFail = false});

  @override
  Future<void> protectBackups() async {
    calls++;
    if (shouldFail) {
      throw const ContactBackupException(
        'backup_system_protection_failed',
      );
    }
  }
}

class _FakeBackupService implements ContactBackupService {
  final ContactBackup? createdBackup;
  final List<ContactBackup> listedBackups;
  final List<String> deletedIds = <String>[];

  _FakeBackupService({
    this.createdBackup,
    this.listedBackups = const <ContactBackup>[],
  });

  @override
  Future<ContactBackup> createBackup() async {
    final backup = createdBackup;
    if (backup == null) {
      throw const ContactBackupException('backup_create_failed');
    }
    return backup;
  }

  @override
  Future<void> deleteBackup(String id) async {
    deletedIds.add(id);
  }

  @override
  Future<List<ContactBackup>> listBackups() async => listedBackups;

  @override
  Future<ContactBackupData> readBackup(String id) async {
    return ContactBackupData(
      backup: listedBackups.firstWhere((backup) => backup.id == id),
      contacts: const <Contact>[],
    );
  }
}
