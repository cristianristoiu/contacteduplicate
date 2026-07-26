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
      emails: <String>[],
    );
    const group = DuplicateContactGroup(
      id: '1|2',
      contacts: <ScannedContact>[contactA, contactB],
      reasons: <DuplicateMatchReason>{DuplicateMatchReason.phone},
      confidenceScore: 75,
    );
    const result = ContactsScanResult(
      permissionState: ContactsPermissionState.granted,
      totalContacts: 10,
      duplicateGroups: <DuplicateContactGroup>[group],
    );
    final controller = ScanController(_FakeScanService(result));

    await controller.scan();

    expect(controller.status, ScanStatus.completed);
    expect(controller.totalContacts, 10);
    expect(controller.duplicateGroupCount, 1);
    expect(controller.duplicateContactCount, 2);
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
