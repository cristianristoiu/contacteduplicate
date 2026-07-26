import 'dart:convert';
import 'dart:io';

import 'package:contacte_duplicate/core/backup/contact_backup_service.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late EncryptedContactBackupService service;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'contacte-duplicate-backup-test-',
    );
    service = EncryptedContactBackupService(
      keyStore: _MemoryBackupKeyStore(
        SecretKey(List<int>.generate(32, (index) => index)),
      ),
      directoryProvider: () async => temporaryDirectory,
      requestPermission: () async => PermissionStatus.granted,
      readContacts: () async => const <Contact>[
        Contact(
          id: 'contact-1',
          displayName: 'Ion Popescu',
          phones: <Phone>[Phone(number: '0722 123 456')],
          emails: <Email>[Email(address: 'ion@example.com')],
          notes: <Note>[Note(note: 'Nota privata')],
        ),
      ],
      clock: () => DateTime.utc(2026, 7, 27, 10, 30),
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('scrie datele criptat si le poate valida integral', () async {
    final backup = await service.createBackup();
    final files = await temporaryDirectory
        .list(recursive: true)
        .where((entity) => entity is File && entity.path.endsWith('.cdbk'))
        .cast<File>()
        .toList();

    expect(files, hasLength(1));
    final rawFile = await files.single.readAsString();
    expect(rawFile, isNot(contains('Ion Popescu')));
    expect(rawFile, isNot(contains('0722 123 456')));
    expect(rawFile, isNot(contains('ion@example.com')));
    expect(rawFile, isNot(contains('Nota privata')));

    final restored = await service.readBackup(backup.id);
    expect(restored.backup.isValid, isTrue);
    expect(restored.backup.contactCount, 1);
    expect(restored.contacts, hasLength(1));
    expect(restored.contacts.single.displayName, 'Ion Popescu');
    expect(restored.contacts.single.phones.single.number, '0722 123 456');
    expect(restored.contacts.single.emails.single.address, 'ion@example.com');
    expect(restored.contacts.single.notes.single.note, 'Nota privata');
  });

  test('detecteaza modificarea continutului criptat', () async {
    final backup = await service.createBackup();
    final file = await temporaryDirectory
        .list(recursive: true)
        .where((entity) => entity is File && entity.path.endsWith('.cdbk'))
        .cast<File>()
        .single;
    final envelope = jsonDecode(await file.readAsString())
        as Map<String, dynamic>;
    final cipherText = base64Decode(envelope['cipherText'] as String);
    cipherText[0] = cipherText[0] ^ 1;
    envelope['cipherText'] = base64Encode(cipherText);
    await file.writeAsString(jsonEncode(envelope), flush: true);

    final backups = await service.listBackups();
    expect(backups, hasLength(1));
    expect(backups.single.isValid, isFalse);
    expect(
      service.readBackup(backup.id),
      throwsA(
        isA<ContactBackupException>().having(
          (error) => error.code,
          'code',
          'backup_integrity_invalid',
        ),
      ),
    );
  });

  test('marcheaza backupul partial pentru acces limitat', () async {
    final limitedService = EncryptedContactBackupService(
      keyStore: _MemoryBackupKeyStore(
        SecretKey(List<int>.filled(32, 7)),
      ),
      directoryProvider: () async => temporaryDirectory,
      requestPermission: () async => PermissionStatus.limited,
      readContacts: () async => const <Contact>[],
      clock: () => DateTime.utc(2026, 7, 27, 11),
    );

    final backup = await limitedService.createBackup();

    expect(backup.accessScope, BackupAccessScope.limited);
    expect(backup.contactCount, 0);
    expect(backup.isValid, isTrue);
  });
}

class _MemoryBackupKeyStore implements BackupKeyStore {
  final SecretKey key;

  const _MemoryBackupKeyStore(this.key);

  @override
  Future<SecretKey> getOrCreateKey() async => key;
}
