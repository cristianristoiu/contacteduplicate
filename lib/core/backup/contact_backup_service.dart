import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

enum BackupAccessScope { full, limited, unknown }

enum BackupPurpose { manual, mergeSafety, restoreSafety, undoSafety }

class ContactBackup {
  final String id;
  final DateTime createdAt;
  final int contactCount;
  final BackupAccessScope accessScope;
  final bool isValid;
  final BackupPurpose purpose;

  const ContactBackup({
    required this.id,
    required this.createdAt,
    required this.contactCount,
    required this.accessScope,
    required this.isValid,
    this.purpose = BackupPurpose.manual,
  });

  bool get isSafetyBackup => purpose != BackupPurpose.manual;
}

class ContactBackupData {
  final ContactBackup backup;
  final List<Contact> contacts;

  const ContactBackupData({required this.backup, required this.contacts});
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

abstract interface class PurposeAwareContactBackupService
    implements ContactBackupService {
  Future<ContactBackup> createBackupForPurpose(BackupPurpose purpose);
}

abstract interface class BackupKeyStore {
  Future<SecretKey> getOrCreateKey();
}

class SecureBackupKeyStore implements BackupKeyStore {
  static const String _storageKey = 'contact_backup_aes_key_v1';

  final FlutterSecureStorage _storage;
  final AesGcm _algorithm;
  Future<SecretKey>? _inFlightRequest;

  SecureBackupKeyStore({
    FlutterSecureStorage? storage,
    AesGcm? algorithm,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _algorithm = algorithm ?? AesGcm.with256bits();

  @override
  Future<SecretKey> getOrCreateKey() {
    final existing = _inFlightRequest;
    if (existing != null) return existing;
    late final Future<SecretKey> request;
    request = _loadOrCreateKey().whenComplete(() {
      if (identical(_inFlightRequest, request)) _inFlightRequest = null;
    });
    _inFlightRequest = request;
    return request;
  }

  Future<SecretKey> _loadOrCreateKey() async {
    final encodedKey = await _storage.read(key: _storageKey);
    if (encodedKey != null) {
      final List<int> keyBytes;
      try {
        keyBytes = base64Decode(encodedKey);
      } on FormatException {
        throw const ContactBackupException('backup_key_invalid');
      }
      if (keyBytes.length != 32) {
        throw const ContactBackupException('backup_key_invalid');
      }
      return SecretKey(keyBytes);
    }

    final key = await _algorithm.newSecretKey();
    final keyBytes = await key.extractBytes();
    if (keyBytes.length != 32) {
      throw const ContactBackupException('backup_key_generation_invalid');
    }
    await _storage.write(key: _storageKey, value: base64Encode(keyBytes));
    final persisted = await _storage.read(key: _storageKey);
    if (persisted == null || persisted != base64Encode(keyBytes)) {
      throw const ContactBackupException('backup_key_persistence_failed');
    }
    return SecretKey(keyBytes);
  }
}

typedef BackupDirectoryProvider = Future<Directory> Function();
typedef BackupPermissionRequester = Future<PermissionStatus> Function();
typedef BackupContactsReader = Future<List<Contact>> Function();
typedef BackupClock = DateTime Function();

class EncryptedContactBackupService implements PurposeAwareContactBackupService {
  static const int _currentFormatVersion = 2;
  static const int _currentSchemaVersion = 2;
  static const int _legacyFormatVersion = 1;
  static const int _legacySchemaVersion = 1;
  static const int _maximumBackupFileBytes = 128 * 1024 * 1024;
  static const int _maximumClearPayloadBytes = 64 * 1024 * 1024;
  static const int _maximumContacts = 100000;
  static const int _maximumIdAttempts = 1024;
  static const int _aesGcmNonceBytes = 12;
  static const int _aesGcmMacBytes = 16;
  static const Duration _temporaryFileMaxAge = Duration(days: 1);
  static const Duration _futureTimestampTolerance = Duration(minutes: 5);
  static const String _directoryName = 'contact_backups';
  static const String _filePrefix = 'contacte-';
  static const String _fileExtension = '.cdbk';

  final BackupKeyStore _keyStore;
  final BackupDirectoryProvider _directoryProvider;
  final BackupPermissionRequester _requestPermission;
  final BackupContactsReader _readContacts;
  final BackupClock _clock;
  final AesGcm _algorithm;
  Future<ContactBackup>? _createInFlight;

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
            (() => FlutterContacts.getAll(properties: ContactProperties.all)),
        _clock = clock ?? DateTime.now,
        _algorithm = algorithm ?? AesGcm.with256bits();

  @override
  Future<List<ContactBackup>> listBackups() async {
    try {
      final directory = await _backupDirectory();
      await _cleanupTemporaryFiles(directory);
      final backups = <ContactBackup>[];
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || !_isBackupFile(entity)) continue;
        try {
          backups.add(await _inspectFile(entity));
        } on Object {
          try {
            final stat = await entity.stat();
            backups.add(
              ContactBackup(
                id: _idFromPath(entity.path),
                createdAt: stat.modified.toUtc(),
                contactCount: 0,
                accessScope: BackupAccessScope.unknown,
                isValid: false,
              ),
            );
          } on Object {
            // Un fisier inaccesibil nu trebuie sa blocheze listarea celorlalte.
          }
        }
      }
      backups.sort((left, right) {
        final date = right.createdAt.compareTo(left.createdAt);
        return date != 0 ? date : right.id.compareTo(left.id);
      });
      return List<ContactBackup>.unmodifiable(backups);
    } on ContactBackupException {
      rethrow;
    } on Object {
      throw const ContactBackupException('backup_list_failed');
    }
  }

  @override
  Future<ContactBackup> createBackup() =>
      createBackupForPurpose(BackupPurpose.manual);

  @override
  Future<ContactBackup> createBackupForPurpose(BackupPurpose purpose) {
    final current = _createInFlight;
    if (current != null) return current;
    late final Future<ContactBackup> request;
    request = _createBackup(purpose).whenComplete(() {
      if (identical(_createInFlight, request)) _createInFlight = null;
    });
    _createInFlight = request;
    return request;
  }

  Future<ContactBackup> _createBackup(BackupPurpose purpose) async {
    File? temporaryFile;
    File? finalFile;
    try {
      final permission = await _requestPermission();
      final accessScope = switch (permission) {
        PermissionStatus.granted => BackupAccessScope.full,
        PermissionStatus.limited => BackupAccessScope.limited,
        _ => throw const ContactBackupException('contacts_permission_denied'),
      };
      if (purpose != BackupPurpose.manual &&
          accessScope != BackupAccessScope.full) {
        throw const ContactBackupException('backup_safety_requires_full_access');
      }

      final contacts = await _readContacts();
      if (contacts.length > _maximumContacts) {
        throw const ContactBackupException('backup_contact_limit_exceeded');
      }
      final directory = await _backupDirectory();
      await _cleanupTemporaryFiles(directory);
      final createdAt = _validatedNow();
      final id = await _uniqueBackupId(directory, createdAt);
      final payload = <String, Object?>{
        'schemaVersion': _currentSchemaVersion,
        'backupId': id,
        'createdAt': createdAt.toIso8601String(),
        'accessScope': accessScope.name,
        'purpose': purpose.name,
        'contacts': contacts.map((contact) => contact.toJson()).toList(),
      };
      final clearText = jsonEncode(payload);
      final clearBytes = utf8.encode(clearText);
      if (clearBytes.length > _maximumClearPayloadBytes) {
        throw const ContactBackupException('backup_payload_too_large');
      }

      final secretKey = await _keyStore.getOrCreateKey();
      final nonce = _algorithm.newNonce();
      if (nonce.length != _aesGcmNonceBytes) {
        throw const ContactBackupException('backup_nonce_invalid');
      }
      final secretBox = await _algorithm.encrypt(
        clearBytes,
        secretKey: secretKey,
        nonce: nonce,
      );
      if (secretBox.mac.bytes.length != _aesGcmMacBytes ||
          secretBox.cipherText.isEmpty) {
        throw const ContactBackupException('backup_encryption_invalid');
      }
      final envelope = <String, Object?>{
        'formatVersion': _currentFormatVersion,
        'backupId': id,
        'createdAt': createdAt.toIso8601String(),
        'contactCount': contacts.length,
        'accessScope': accessScope.name,
        'purpose': purpose.name,
        'nonce': base64Encode(secretBox.nonce),
        'cipherText': base64Encode(secretBox.cipherText),
        'mac': base64Encode(secretBox.mac.bytes),
      };
      final encodedEnvelope = jsonEncode(envelope);
      if (utf8.encode(encodedEnvelope).length > _maximumBackupFileBytes) {
        throw const ContactBackupException('backup_file_too_large');
      }

      finalFile = File(_filePath(directory, id));
      if (await finalFile.exists()) {
        throw const ContactBackupException('backup_id_collision');
      }
      temporaryFile = File('${finalFile.path}.tmp');
      if (await temporaryFile.exists()) await temporaryFile.delete();
      await temporaryFile.writeAsString(encodedEnvelope, flush: true);
      if (await finalFile.exists()) {
        throw const ContactBackupException('backup_id_collision');
      }
      await temporaryFile.rename(finalFile.path);
      temporaryFile = null;

      final validated = await _readFile(finalFile);
      if (!validated.backup.isValid ||
          validated.backup.contactCount != contacts.length ||
          validated.backup.id != id ||
          validated.backup.purpose != purpose) {
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
    final normalizedId = _validatedId(id);
    try {
      final directory = await _backupDirectory();
      final file = File(_filePath(directory, normalizedId));
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
    final normalizedId = _validatedId(id);
    try {
      final directory = await _backupDirectory();
      final file = File(_filePath(directory, normalizedId));
      if (await file.exists()) await file.delete();
      if (await file.exists()) {
        throw const ContactBackupException('backup_delete_verification_failed');
      }
    } on ContactBackupException {
      rethrow;
    } on Object {
      throw const ContactBackupException('backup_delete_failed');
    }
  }

  Future<ContactBackupData> _readFile(File file) async {
    try {
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file ||
          stat.size <= 0 ||
          stat.size > _maximumBackupFileBytes) {
        throw const ContactBackupException('backup_file_size_invalid');
      }
      final rawEnvelope = jsonDecode(await file.readAsString());
      if (rawEnvelope is! Map<String, dynamic>) {
        throw const ContactBackupException('backup_format_invalid');
      }
      final formatVersion = rawEnvelope['formatVersion'];
      if (formatVersion != _currentFormatVersion &&
          formatVersion != _legacyFormatVersion) {
        throw const ContactBackupException('backup_format_version_unsupported');
      }
      final id = rawEnvelope['backupId'];
      final createdAtValue = rawEnvelope['createdAt'];
      final contactCount = rawEnvelope['contactCount'];
      final accessScopeValue = rawEnvelope['accessScope'];
      final purposeValue = formatVersion == _legacyFormatVersion
          ? BackupPurpose.manual.name
          : rawEnvelope['purpose'];
      final nonceValue = rawEnvelope['nonce'];
      final cipherTextValue = rawEnvelope['cipherText'];
      final macValue = rawEnvelope['mac'];
      if (id is! String ||
          !_isValidId(id) ||
          createdAtValue is! String ||
          contactCount is! int ||
          contactCount < 0 ||
          contactCount > _maximumContacts ||
          accessScopeValue is! String ||
          purposeValue is! String ||
          nonceValue is! String ||
          nonceValue.trim().isEmpty ||
          cipherTextValue is! String ||
          cipherTextValue.trim().isEmpty ||
          macValue is! String ||
          macValue.trim().isEmpty) {
        throw const ContactBackupException('backup_format_invalid');
      }
      if (_idFromPath(file.path) != id) {
        throw const ContactBackupException('backup_filename_identity_mismatch');
      }

      final createdAt = DateTime.tryParse(createdAtValue)?.toUtc();
      final accessScope = _enumByName(BackupAccessScope.values, accessScopeValue);
      final purpose = _enumByName(BackupPurpose.values, purposeValue);
      if (createdAt == null ||
          createdAt.isAfter(_validatedNow().add(_futureTimestampTolerance)) ||
          accessScope == null ||
          accessScope == BackupAccessScope.unknown ||
          purpose == null) {
        throw const ContactBackupException('backup_format_invalid');
      }
      if (purpose != BackupPurpose.manual &&
          accessScope != BackupAccessScope.full) {
        throw const ContactBackupException('backup_safety_scope_invalid');
      }

      final List<int> nonceBytes;
      final List<int> cipherTextBytes;
      final List<int> macBytes;
      try {
        nonceBytes = base64Decode(nonceValue);
        cipherTextBytes = base64Decode(cipherTextValue);
        macBytes = base64Decode(macValue);
      } on FormatException {
        throw const ContactBackupException('backup_format_invalid');
      }
      if (nonceBytes.length != _aesGcmNonceBytes ||
          cipherTextBytes.isEmpty ||
          macBytes.length != _aesGcmMacBytes ||
          cipherTextBytes.length > _maximumClearPayloadBytes + 1024) {
        throw const ContactBackupException('backup_crypto_fields_invalid');
      }

      final clearBytes = await _algorithm.decrypt(
        SecretBox(cipherTextBytes, nonce: nonceBytes, mac: Mac(macBytes)),
        secretKey: await _keyStore.getOrCreateKey(),
      );
      if (clearBytes.length > _maximumClearPayloadBytes) {
        throw const ContactBackupException('backup_payload_too_large');
      }
      final rawPayload = jsonDecode(utf8.decode(clearBytes));
      if (rawPayload is! Map<String, dynamic>) {
        throw const ContactBackupException('backup_payload_invalid');
      }
      final expectedSchema = formatVersion == _legacyFormatVersion
          ? _legacySchemaVersion
          : _currentSchemaVersion;
      if (rawPayload['schemaVersion'] != expectedSchema ||
          rawPayload['backupId'] != id ||
          rawPayload['createdAt'] != createdAtValue ||
          rawPayload['accessScope'] != accessScopeValue ||
          (formatVersion == _currentFormatVersion &&
              rawPayload['purpose'] != purposeValue) ||
          rawPayload['contacts'] is! List) {
        throw const ContactBackupException('backup_payload_invalid');
      }

      final rawContacts = rawPayload['contacts'] as List;
      if (rawContacts.length != contactCount ||
          rawContacts.length > _maximumContacts) {
        throw const ContactBackupException('backup_contact_count_invalid');
      }
      final contacts = <Contact>[];
      for (final rawContact in rawContacts) {
        if (rawContact is! Map || rawContact.keys.any((key) => key is! String)) {
          throw const ContactBackupException('backup_contact_invalid');
        }
        final contact = Contact.fromJson(Map<String, dynamic>.from(rawContact));
        contacts.add(contact);
      }

      return ContactBackupData(
        backup: ContactBackup(
          id: id,
          createdAt: createdAt,
          contactCount: contactCount,
          accessScope: accessScope,
          isValid: true,
          purpose: purpose,
        ),
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
    if (!await directory.exists()) await directory.create(recursive: true);
    final resolvedRoot = root.absolute.path;
    final resolvedDirectory = directory.absolute.path;
    if (!resolvedDirectory.startsWith(
      '$resolvedRoot${Platform.pathSeparator}',
    )) {
      throw const ContactBackupException('backup_directory_invalid');
    }
    return directory;
  }

  Future<void> _cleanupTemporaryFiles(Directory directory) async {
    final now = _validatedNow();
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final fileName = entity.path.split(Platform.pathSeparator).last;
      if (!RegExp(r'^contacte-[1-9][0-9]*\.cdbk\.tmp$').hasMatch(fileName)) {
        continue;
      }
      try {
        final stat = await entity.stat();
        if (now.difference(stat.modified.toUtc()) > _temporaryFileMaxAge) {
          await entity.delete();
        }
      } on Object {
        // Cleanup best-effort; fisierul final valid nu este atins.
      }
    }
  }

  Future<String> _uniqueBackupId(
    Directory directory,
    DateTime createdAt,
  ) async {
    var value = createdAt.microsecondsSinceEpoch;
    if (value <= 0) value = 1;
    for (var attempt = 0; attempt < _maximumIdAttempts; attempt++, value++) {
      final id = '$value';
      if (!await File(_filePath(directory, id)).exists() &&
          !await File('${_filePath(directory, id)}.tmp').exists()) {
        return id;
      }
    }
    throw const ContactBackupException('backup_id_exhausted');
  }

  String _filePath(Directory directory, String id) =>
      '${directory.path}${Platform.pathSeparator}$_filePrefix$id$_fileExtension';

  String _idFromPath(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final match = RegExp(r'^contacte-([1-9][0-9]*)\.cdbk$').firstMatch(fileName);
    return match?.group(1) ?? 'invalid';
  }

  bool _isBackupFile(File file) => _idFromPath(file.path) != 'invalid';

  String _validatedId(String id) {
    final normalized = id.trim();
    if (!_isValidId(normalized)) {
      throw const ContactBackupException('backup_id_invalid');
    }
    return normalized;
  }

  bool _isValidId(String id) =>
      id.length <= 32 && RegExp(r'^[1-9][0-9]*$').hasMatch(id);

  DateTime _validatedNow() {
    final now = _clock().toUtc();
    if (now.year < 2000 || now.year > 9999) {
      throw const ContactBackupException('backup_clock_invalid');
    }
    return now;
  }

  T? _enumByName<T extends Enum>(Iterable<T> values, String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  Future<void> _deleteQuietly(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } on Object {
      // Curatarea best-effort nu ascunde eroarea principala.
    }
  }
}

extension _FirstOrNullBackup<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
