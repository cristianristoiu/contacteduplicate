import 'package:contacte_duplicate/core/contacts/contacts_scan_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('grupeaza numerele romanesti in formate echivalente', () async {
    final service = NativeContactsScanService(
      requestPermission: () async => PermissionStatus.granted,
      readContacts: () async => const <Contact>[
        Contact(
          id: '1',
          displayName: 'Ion Popescu',
          phones: <Phone>[Phone(number: '0722 123 456')],
        ),
        Contact(
          id: '2',
          displayName: 'Ion P.',
          phones: <Phone>[Phone(number: '+40 722-123-456')],
        ),
      ],
    );

    final result = await service.scan();

    expect(result.permissionState, ContactsPermissionState.granted);
    expect(result.totalContacts, 2);
    expect(result.duplicateGroups, hasLength(1));
    expect(
      result.duplicateGroups.single.reasons,
      contains(DuplicateMatchReason.phone),
    );
    expect(result.duplicateGroups.single.confidenceScore, 98);
  });

  test('inchide tranzitiv grupurile dupa telefon si email', () async {
    final service = NativeContactsScanService(
      requestPermission: () async => PermissionStatus.limited,
      readContacts: () async => const <Contact>[
        Contact(
          id: '1',
          displayName: 'Contact A',
          phones: <Phone>[Phone(number: '0711 000 000')],
        ),
        Contact(
          id: '2',
          displayName: 'Contact B',
          phones: <Phone>[Phone(number: '+40 711 000 000')],
          emails: <Email>[Email(address: 'test@example.com')],
        ),
        Contact(
          id: '3',
          displayName: 'Contact C',
          emails: <Email>[Email(address: 'TEST@example.com ')],
        ),
      ],
    );

    final result = await service.scan();

    expect(result.permissionState, ContactsPermissionState.limited);
    expect(result.duplicateGroups, hasLength(1));
    expect(result.duplicateGroups.single.contacts, hasLength(3));
    expect(result.duplicateGroups.single.confidenceScore, 100);
  });

  test('nu citeste contactele cand permisiunea este refuzata', () async {
    var readWasCalled = false;
    final service = NativeContactsScanService(
      requestPermission: () async => PermissionStatus.permanentlyDenied,
      readContacts: () async {
        readWasCalled = true;
        return const <Contact>[];
      },
    );

    final result = await service.scan();

    expect(
      result.permissionState,
      ContactsPermissionState.permanentlyDenied,
    );
    expect(readWasCalled, isFalse);
    expect(result.duplicateGroups, isEmpty);
  });
}
