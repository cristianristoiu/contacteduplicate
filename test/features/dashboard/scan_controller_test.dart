import 'dart:async';

import 'package:contacte_duplicate/core/contacts/contacts_scan_service.dart';
import 'package:contacte_duplicate/features/dashboard/scan_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('expune rezultatul si statisticile dupa scanare', () async {
    const contactA = ScannedContact(
      nativeId: '1',
      displayName: 'Contact A',
      phones: <String>['0711000000'],
      emails: <String>[],
    );
    const contactB = ScannedContact(
      nativeId: '2',
      displayName: 'Contact B',
      phones: <String>['+40711000000'],
      emails: <String>['b@example.com'],
    );
    const contactC = ScannedContact(
      nativeId: '3',
      displayName: 'Contact C',
      phones: <String>[],
      emails: <String>['b@example.com'],
    );
    const phoneGroup = DuplicateContactGroup(
      id: '1|2',
      contacts: <ScannedContact>[contactA, contactB],
      reasons: <DuplicateMatchReason>{DuplicateMatchReason.phone},
      confidenceScore: 75,
    );
    const emailGroup = DuplicateContactGroup(
      id: '2|3',
      contacts: <ScannedContact>[contactB, contactC],
      reasons: <DuplicateMatchReason>{DuplicateMatchReason.email},
      confidenceScore: 70,
    );
    const result = ContactsScanResult(
      permissionState: ContactsPermissionState.granted,
      totalContacts: 10,
      duplicateGroups: <DuplicateContactGroup>[phoneGroup, emailGroup],
    );
    final controller = ScanController(_FakeScanService(result));

    await controller.scan();

    expect(controller.status, ScanStatus.completed);
    expect(controller.totalContacts, 10);
    expect(controller.duplicateGroupCount, 2);
    expect(controller.duplicateContactCount, 3);
    expect(controller.scanRevision, 1);
    expect(controller.resultsStale, isFalse);
  });

  test('marcheaza rezultatul invechit si il improspateaza prin rescannare', () async {
    const result = ContactsScanResult(
      permissionState: ContactsPermissionState.granted,
      totalContacts: 2,
      duplicateGroups: <DuplicateContactGroup>[],
    );
    final service = _FakeScanService(result);
    final controller = ScanController(service);

    await controller.scan();
    controller.markResultsStale();

    expect(controller.resultsStale, isTrue);
    expect(controller.scanRevision, 1);

    await controller.scan();

    expect(controller.resultsStale, isFalse);
    expect(controller.scanRevision, 2);
    expect(service.scanCalls, 2);
  });

  test('mapeaza refuzul permisiunii in starea dedicata', () async {
    const result = ContactsScanResult.permissionDenied(
      ContactsPermissionState.permanentlyDenied,
    );
    final controller = ScanController(_FakeScanService(result));

    await controller.scan();

    expect(controller.status, ScanStatus.permissionDenied);
    expect(
      controller.result?.permissionState,
      ContactsPermissionState.permanentlyDenied,
    );
    expect(controller.scanRevision, 1);
  });

  test('ignora o a doua cerere cat timp scanarea ruleaza', () async {
    const result = ContactsScanResult(
      permissionState: ContactsPermissionState.granted,
      totalContacts: 0,
      duplicateGroups: <DuplicateContactGroup>[],
    );
    final completer = Completer<ContactsScanResult>();
    final service = _FakeScanService(result, completer: completer);
    final controller = ScanController(service);

    final firstScan = controller.scan();
    final secondScan = controller.scan();
    completer.complete(result);
    await Future.wait(<Future<void>>[firstScan, secondScan]);

    expect(service.scanCalls, 1);
    expect(controller.status, ScanStatus.completed);
    expect(controller.scanRevision, 1);
  });

  test('semnalizeaza esecul deschiderii setarilor sistemului', () async {
    const result = ContactsScanResult.permissionDenied(
      ContactsPermissionState.permanentlyDenied,
    );
    final controller = ScanController(
      _FakeScanService(result, failOpenSettings: true),
    );

    await controller.scan();
    await controller.openAppSettings();

    expect(controller.status, ScanStatus.permissionDenied);
    expect(controller.settingsOpenFailed, isTrue);
  });
}

class _FakeScanService implements ContactsScanService {
  final ContactsScanResult result;
  final Completer<ContactsScanResult>? completer;
  final bool failOpenSettings;
  int scanCalls = 0;

  _FakeScanService(
    this.result, {
    this.completer,
    this.failOpenSettings = false,
  });

  @override
  Future<ContactsScanResult> scan() {
    scanCalls++;
    return completer?.future ?? Future<ContactsScanResult>.value(result);
  }

  @override
  Future<void> openAppSettings() async {
    if (failOpenSettings) {
      throw StateError('settings_unavailable');
    }
  }
}
