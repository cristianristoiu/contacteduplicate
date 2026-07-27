import 'dart:async';

import 'package:contacte_duplicate/core/backup/contact_backup_service.dart';
import 'package:contacte_duplicate/features/backup/backup_controller.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invalideaza sursele validate cand backupul expira', () async {
    var now = DateTime.utc(2026, 7, 27, 12);
    final timers = <_ManualTimer>[];
    final backup = ContactBackup(
      id: '100',
      createdAt: now.subtract(const Duration(minutes: 4)),
      contactCount: 2,
      accessScope: BackupAccessScope.full,
      isValid: true,
    );
    final controller = BackupController(
      _ExpiryBackupService(backup),
      clock: () => now,
      timerFactory: (duration, callback) {
        final timer = _ManualTimer(duration, callback);
        timers.add(timer);
        return timer;
      },
    );
    void listener() {}
    controller.addListener(listener);
    await controller.load();

    final validation = await controller.validateMergeSources(
      const <String>['a', 'b'],
    );

    expect(validation.isValid, isTrue);
    expect(controller.mergeValidation?.isValid, isTrue);
    expect(timers, hasLength(1));

    now = now.add(const Duration(minutes: 1, milliseconds: 1));
    timers.single.fire();

    expect(controller.latestMergeEligibleBackup, isNull);
    expect(controller.mergeValidation, isNull);
    controller.removeListener(listener);
    controller.dispose();
  });
}

class _ExpiryBackupService implements ContactBackupService {
  final ContactBackup backup;

  _ExpiryBackupService(this.backup);

  @override
  Future<List<ContactBackup>> listBackups() async => <ContactBackup>[backup];

  @override
  Future<ContactBackupData> readBackup(String id) async {
    return ContactBackupData(
      backup: backup,
      contacts: const <Contact>[
        Contact(id: 'a'),
        Contact(id: 'b'),
      ],
    );
  }

  @override
  Future<ContactBackup> createBackup() async => backup;

  @override
  Future<void> deleteBackup(String id) async {}
}

class _ManualTimer implements Timer {
  final Duration duration;
  final void Function() _callback;

  bool _isActive = true;
  int _tick = 0;

  _ManualTimer(this.duration, this._callback);

  @override
  bool get isActive => _isActive;

  @override
  int get tick => _tick;

  @override
  void cancel() {
    _isActive = false;
  }

  void fire() {
    if (!_isActive) {
      return;
    }
    _isActive = false;
    _tick++;
    _callback();
  }
}
