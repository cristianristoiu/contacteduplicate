import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

enum BackupAccessScope {
  full,
  limited,
  unknown,
}

class ContactBackup {
  final String id;
  final DateTime createdAt;
  final int contactCount;
  final BackupAccessScope accessScope;
  final bool isValid;

  const ContactBackup({
    required this.id,
    required this.createdAt,
    required this.contactCount,
    required this.accessScope,
    required this.isValid,
  });
}

class ContactBackupData {
  final ContactBackup backup;
  final List<Contact> contacts;

  const ContactBackupData({
    required this.backup,
    required this.contacts,
  });
}

class ContactBackupException implements Exception {
  final String code;

  const ContactBackupException(this.code);

  @override
  String toString() => 'ContactBackupException($code)';
}

abstract interface class ContactBackupService {
  Future<List<ContactBackup>> listBackups();

  Future<ContactBackup> createBackup();

  Future<ContactBackupData> readBackup(String id);

  Future<void> deleteBackup(String id);
}

abstract interface class BackupKeyStore {
  Future<SecretKey> getOrCreateKey();
}

class SecureBackupKeyStore implements BackupKeyStore {
  static const String _storageKey = 'contact_backup_aes_key_v1';

  final FlutterSecureStorage _storage;
  final AesGcm _algorithm;

  SecureBackupKeyStore({
    FlutterSecureStorage? storage,
    AesGcm? algorithm,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _algorithm = algorithm ?? AesGcm.with256bits();

  @override
  Future<SecretKey> getOrCreateKey() async {
    final encodedKey = await _storage.read(key: _storageKey);
    if (encodedKey != null) {
      final keyBytes = base64Decode(encodedKey);
      if (keyBytes.length != 32) {
        throw const ContactBackupException('backup_key_invalid');
      }
      return SecretKey(keyBytes);
    }

    final key = await _algorithm.newSecretKey();
    final keyBytes = await key.extractBytes();
    await _storage.write(
      key: _storageKey,
      value: base64Encode(keyBytes),
    );
    return SecretKey(keyBytes);
  }
}

typedef BackupDirectoryProvider = Future<Directory> Function();
typedef BackupPermissionRequester = Future<PermissionStatus> Function();
typedef BackupContactsReader = Future<List<Contact>> Function();
typedef BackupClock = DateTime Function();

class EncryptedContactBackupService implements ContactBackupService {
  static const int _formatVersion = 1;
  static const int _schemaVersion = 1;
  static const String _directoryName = 'contact_backups';
  static const String _filePrefix = 'contacte-';
  static const String _fileExtension = '.cdbk';

  final BackupKeyStore _keyStore;
  final BackupDirectoryProvider _directoryProvider;
  final BackupPermissionRequester _requestPermission;
  final BackupContactsReader _readContacts;
  final BackupClock _clock;
  final AesGcm _algorithm;

  EncryptedContactBackupService({
    BackupKeyStore? keyStore,
    BackupDirectoryProvider? directoryProvider,
    BackupPermissionRequester? requestPermission,
    BackupContactsReader? readContacts,
    BackupClock? clock,
    AesGcm? algorithm,
  })  : _keyStore = keyStore ?? SecureBackupKeyStore(),
        _directoryProvider = directoryProvider ?? getApplicationSupportDirectory,
        _requestPermission = requestPermission ??
            (() => FlutterContacts.permissions.request(PermissionType.read)),
        _readContacts = readContacts ??
            (() => FlutterContacts.getAll(
                  properties: ContactProperties.all,
                )),
        _clock = clock ?? DateTime.now,
        _algorithm = algorithm ?? AesGcm.with256bits();

  @override
  Future<List<ContactBackup>> listBackups() async {
    try {
      final directory = await _backupDirectory();
      final backups = <ContactBackup>[];

      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith(_fileExtension)) {
          continue;
        }
        backups.add(await _inspectFile(entity));
      }

      backups.sort((left, right) => right.createdAt.compareTo(left.createdAt));
      return List<ContactBackup>.unmodifiable(backups);
    } on ContactBackupException {
      rethrow;
    } on Object {
      throw const ContactBackupException('backup_list_failed');
    }
  }

  @override
  Future<ContactBackup> createBackup() async {
    File? temporaryFile;
    File? finalFile;

    try {
      final permission = await _requestPermission();
      final accessScope = switch (permission) {
        PermissionStatus.granted => BackupAccessScope.full,
        PermissionStatus.limited => BackupAccessScope.limited,
        _ => throw const ContactBackupException(
            'contacts_permission_denied',
          ),
      };

      final contacts = await _readContacts();
      final directory = await _backupDirectory();
      final createdAt = _clock().toUtc();
      final id = await _uniqueBackupId(directory, createdAt);
      final payload = <String, Object?>{
        'schemaVersion': _schemaVersion,
        'backupId': id,
        'createdAt': createdAt.toIso8601String(),
        'accessScope': accessScope.name,
        'contacts': contacts.map((contact) => contact.toJson()).toList(),
      };

      final secretKey = await _keyStore.getOrCreateKey();
      final nonce = _algorithm.newNonce();
      final secretBox = await _algorithm.encrypt(
        utf8.encode(jsonEncode(payload)),
        secretKey: secretKey,
        nonce: nonce,
      );
      final envelope = <String, Object?>{
        'formatVersion': _formatVersion,
        'backupId': id,
        'createdAt': createdAt.toIso8601String(),
        'contactCount': contacts.length,
        'accessScope': accessScope.name,
        'nonce': base64Encode(secretBox.nonce),
        'cipherText': base64Encode(secretBox.cipherText),
        'mac': base64Encode(secretBox.mac.bytes),
      };

      finalFile = File(_filePath(directory, id));
      temporaryFile = File('${finalFile.path}.tmp');
      await temporaryFile.writeAsString(
        jsonEncode(envelope),
        flush: true,
      );
      await temporaryFile.rename(finalFile.path);
      temporaryFile = null;

      final validated = await _readFile(finalFile);
      if (!validated.backup.isValid ||
          validated.backup.contactCount != contacts.length ||
          validated.backup.id != id) {
        throw const ContactBackupException('backup_validation_failed');
      }

      return validated.backup;
    } on ContactBackupException {
      await _deleteQuietly(temporaryFile);
      await _deleteQuietly(finalFile);
      rethrow;
    } on Object {
      await _deleteQuietly(temporaryFile);
      await _deleteQuietly(finalFile);
      throw const ContactBackupException('backup_create_failed');
    }
  }

  @override
  Future<ContactBackupData> readBackup(String id) async {
    if (!_isValidId(id)) {
      throw const ContactBackupException('backup_id_invalid');
    }

    try {
      final directory = await _backupDirectory();
      final file = File(_filePath(directory, id));
      if (!await file.exists()) {
        throw const ContactBackupException('backup_not_found');
      }
      return await _readFile(file);
    } on ContactBackupException {
      rethrow;
    } on Object {
      throw const ContactBackupException('backup_read_failed');
    }
  }

  @override
  Future<void> deleteBackup(String id) async {
    if (!_isValidId(id)) {
      throw const ContactBackupException('backup_id_invalid');
    }

    try {
      final directory = await _backupDirectory();
      final file = File(_filePath(directory, id));
      if (await file.exists()) {
        await file.delete();
      }
    } on Object {
      throw const ContactBackupException('backup_delete_failed');
    }
  }

  Future<ContactBackupData> _readFile(File file) async {
    try {
      final rawEnvelope = jsonDecode(await file.readAsString());
      if (rawEnvelope is! Map<String, dynamic>) {
        throw const ContactBackupException('backup_format_invalid');
      }

      final formatVersion = rawEnvelope['formatVersion'];
      final id = rawEnvelope['backupId'];
      final createdAtValue = rawEnvelope['createdAt'];
      final contactCount = rawEnvelope['contactCount'];
      final accessScopeValue = rawEnvelope['accessScope'];
      final nonceValue = rawEnvelope['nonce'];
      final cipherTextValue = rawEnvelope['cipherText'];
      final macValue = rawEnvelope['mac'];

      if (formatVersion != _formatVersion ||
          id is! String ||
          !_isValidId(id) ||
          createdAtValue is! String ||
          contactCount is! int ||
          contactCount < 0 ||
          accessScopeValue is! String ||
          nonceValue is! String ||
          cipherTextValue is! String ||
          macValue is! String) {
        throw const ContactBackupException('backup_format_invalid');
      }

      final createdAt = DateTime.tryParse(createdAtValue)?.toUtc();
      final accessScope = BackupAccessScope.values
          .where((scope) => scope.name == accessScopeValue)
          .firstOrNull;
      if (createdAt == null ||
          accessScope == null ||
          accessScope == BackupAccessScope.unknown) {
        throw const ContactBackupException('backup_format_invalid');
      }

      final secretBox = SecretBox(
        base64Decode(cipherTextValue),
        nonce: base64Decode(nonceValue),
        mac: Mac(base64Decode(macValue)),
      );
      final secretKey = await _keyStore.getOrCreateKey();
      final clearBytes = await _algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      final rawPayload = jsonDecode(utf8.decode(clearBytes));
      if (rawPayload is! Map<String, dynamic> ||
          rawPayload['schemaVersion'] != _schemaVersion ||
          rawPayload['backupId'] != id ||
          rawPayload['createdAt'] != createdAtValue ||
          rawPayload['accessScope'] != accessScopeValue ||
          rawPayload['contacts'] is! List) {
        throw const ContactBackupException('backup_payload_invalid');
      }

      final rawContacts = rawPayload['contacts'] as List;
      if (rawContacts.length != contactCount) {
        throw const ContactBackupException('backup_contact_count_invalid');
      }

      final contacts = rawContacts.map((rawContact) {
        if (rawContact is! Map) {
          throw const ContactBackupException('backup_contact_invalid');
        }
        return Contact.fromJson(rawContact);
      }).toList(growable: false);

      final backup = ContactBackup(
        id: id,
        createdAt: createdAt,
        contactCount: contactCount,
        accessScope: accessScope,
        isValid: true,
      );
      return ContactBackupData(
        backup: backup,
        contacts: List<Contact>.unmodifiable(contacts),
      );
    } on ContactBackupException {
      rethrow;
    } on Object {
      throw const ContactBackupException('backup_integrity_invalid');
    }
  }

  Future<ContactBackup> _inspectFile(File file) async {
    try {
      return (await _readFile(file)).backup;
    } on Object {
      final stat = await file.stat();
      return ContactBackup(
        id: _idFromPath(file.path),
        createdAt: stat.modified.toUtc(),
        contactCount: 0,
        accessScope: BackupAccessScope.unknown,
        isValid: false,
      );
    }
  }

  Future<Directory> _backupDirectory() async {
    final root = await _directoryProvider();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}$_directoryName',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<String> _uniqueBackupId(
    Directory directory,
    DateTime createdAt,
  ) async {
    var value = createdAt.microsecondsSinceEpoch;
    while (await File(_filePath(directory, '$value')).exists()) {
      value++;
    }
    return '$value';
  }

  String _filePath(Directory directory, String id) {
    return '${directory.path}${Platform.pathSeparator}'
        '$_filePrefix$id$_fileExtension';
  }

  String _idFromPath(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    if (fileName.startsWith(_filePrefix) &&
        fileName.endsWith(_fileExtension)) {
      return fileName.substring(
        _filePrefix.length,
        fileName.length - _fileExtension.length,
      );
    }
    return 'invalid';
  }

  bool _isValidId(String id) => RegExp(r'^\d+$').hasMatch(id);

  Future<void> _deleteQuietly(File? file) async {
    if (file == null) {
      return;
    }

    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on Object {
      // Curatarea best-effort nu trebuie sa ascunda eroarea principala.
    }
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
