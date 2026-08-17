import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'contact_backup_service.dart';

abstract interface class BackupSystemProtection {
  Future<void> protectBackups();
}

class NativeBackupSystemProtection implements BackupSystemProtection {
  static const MethodChannel _channel = MethodChannel(
    'ro.contacteduplicate.app/storage',
  );
  static const String _directoryName = 'contact_backups';
  static const String _fileExtension = '.cdbk';
  static const int _maximumProtectedFiles = 2048;

  final BackupDirectoryProvider _directoryProvider;

  NativeBackupSystemProtection({
    BackupDirectoryProvider? directoryProvider,
  }) : _directoryProvider =
            directoryProvider ?? getApplicationSupportDirectory;

  @override
  Future<void> protectBackups() async {
    if (!Platform.isIOS) return;
    final root = await _directoryProvider();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}$_directoryName',
    );
    if (!await directory.exists()) return;
    final rootPath = root.absolute.path;
    final directoryPath = directory.absolute.path;
    if (!directoryPath.startsWith('$rootPath${Platform.pathSeparator}')) {
      throw const ContactBackupException('backup_system_path_invalid');
    }

    await _excludePath(directoryPath);
    var protectedFiles = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith(_fileExtension)) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (!RegExp(r'^contacte-[1-9][0-9]*\.cdbk$').hasMatch(name)) continue;
      if (++protectedFiles > _maximumProtectedFiles) {
        throw const ContactBackupException('backup_system_file_limit_exceeded');
      }
      await _excludePath(entity.absolute.path);
    }
  }

  Future<void> _excludePath(String path) async {
    if (path.trim().isEmpty || path.length > 4096) {
      throw const ContactBackupException('backup_system_path_invalid');
    }
    final excluded = await _channel.invokeMethod<bool>(
      'excludeFromBackup',
      <String, Object?>{'path': path},
    );
    if (excluded != true) {
      throw const ContactBackupException('backup_system_protection_failed');
    }
  }
}

class ProtectedContactBackupService implements PurposeAwareContactBackupService {
  final ContactBackupService _delegate;
  final BackupSystemProtection _systemProtection;

  ProtectedContactBackupService({
    required ContactBackupService delegate,
    BackupSystemProtection? systemProtection,
  })  : _delegate = delegate,
        _systemProtection =
            systemProtection ?? NativeBackupSystemProtection();

  @override
  Future<List<ContactBackup>> listBackups() async {
    final backups = await _delegate.listBackups();
    await _protectOrThrow();
    return backups;
  }

  @override
  Future<ContactBackup> createBackup() =>
      createBackupForPurpose(BackupPurpose.manual);

  @override
  Future<ContactBackup> createBackupForPurpose(BackupPurpose purpose) async {
    final delegate = _delegate;
    final ContactBackup backup;
    if (delegate is PurposeAwareContactBackupService) {
      backup = await delegate.createBackupForPurpose(purpose);
    } else {
      if (purpose != BackupPurpose.manual) {
        throw const ContactBackupException('backup_purpose_not_supported');
      }
      backup = await delegate.createBackup();
    }
    try {
      await _protectOrThrow();
      return backup;
    } on Object {
      try {
        await _delegate.deleteBackup(backup.id);
      } on Object {
        throw const ContactBackupException(
          'backup_system_protection_cleanup_failed',
        );
      }
      throw const ContactBackupException('backup_system_protection_failed');
    }
  }

  @override
  Future<ContactBackupData> readBackup(String id) async {
    await _protectOrThrow();
    final data = await _delegate.readBackup(id);
    if (!data.backup.isValid) {
      throw const ContactBackupException('backup_integrity_invalid');
    }
    return data;
  }

  @override
  Future<void> deleteBackup(String id) async {
    await _delegate.deleteBackup(id);
    final remaining = await _delegate.listBackups();
    if (remaining.any((backup) => backup.id == id && backup.isValid)) {
      throw const ContactBackupException('backup_delete_verification_failed');
    }
  }

  Future<void> _protectOrThrow() async {
    try {
      await _systemProtection.protectBackups();
    } on ContactBackupException {
      rethrow;
    } on Object {
      throw const ContactBackupException('backup_system_protection_failed');
    }
  }
}
