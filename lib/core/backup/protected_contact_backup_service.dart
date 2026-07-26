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

  final BackupDirectoryProvider _directoryProvider;

  NativeBackupSystemProtection({
    BackupDirectoryProvider? directoryProvider,
  }) : _directoryProvider =
            directoryProvider ?? getApplicationSupportDirectory;

  @override
  Future<void> protectBackups() async {
    if (!Platform.isIOS) {
      return;
    }

    final root = await _directoryProvider();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}$_directoryName',
    );
    if (!await directory.exists()) {
      return;
    }

    await _excludePath(directory.path);
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith(_fileExtension)) {
        await _excludePath(entity.path);
      }
    }
  }

  Future<void> _excludePath(String path) async {
    final excluded = await _channel.invokeMethod<bool>(
      'excludeFromBackup',
      <String, Object?>{'path': path},
    );
    if (excluded != true) {
      throw const ContactBackupException(
        'backup_system_protection_failed',
      );
    }
  }
}

class ProtectedContactBackupService implements ContactBackupService {
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
  Future<ContactBackup> createBackup() async {
    final backup = await _delegate.createBackup();
    try {
      await _protectOrThrow();
      return backup;
    } on Object {
      try {
        await _delegate.deleteBackup(backup.id);
      } on Object {
        // Esecul stergerii nu trebuie sa ascunda eroarea de confidentialitate.
      }
      throw const ContactBackupException(
        'backup_system_protection_failed',
      );
    }
  }

  @override
  Future<ContactBackupData> readBackup(String id) async {
    await _protectOrThrow();
    return _delegate.readBackup(id);
  }

  @override
  Future<void> deleteBackup(String id) {
    return _delegate.deleteBackup(id);
  }

  Future<void> _protectOrThrow() async {
    try {
      await _systemProtection.protectBackups();
    } on ContactBackupException {
      rethrow;
    } on Object {
      throw const ContactBackupException(
        'backup_system_protection_failed',
      );
    }
  }
}
