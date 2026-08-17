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
    expect(result.duplicateGroups.single.confidenceScore, 95);
    expect(result.duplicateGroups.single.id, '["1","2"]');
  });

  test('nu combina tranzitiv contacte fara o valoare comuna directa', () async {
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
    final memberships = result.duplicateGroups.map((group) {
      final ids = group.contacts.map((contact) => contact.nativeId).toList()
        ..sort();
      return ids.join(',');
    }).toSet();

    expect(result.permissionState, ContactsPermissionState.limited);
    expect(result.duplicateGroups, hasLength(2));
    expect(memberships, equals(<String>{'1,2', '2,3'}));
    expect(
      result.duplicateGroups.every((group) => group.contacts.length == 2),
      isTrue,
    );
  });

  test('combina motivele doar pentru aceeasi pereche de contacte', () async {
    final service = NativeContactsScanService(
      requestPermission: () async => PermissionStatus.granted,
      readContacts: () async => const <Contact>[
        Contact(
          id: '1',
          displayName: 'Contact A',
          phones: <Phone>[Phone(number: '0722 111 222')],
          emails: <Email>[Email(address: 'same@example.com')],
        ),
        Contact(
          id: '2',
          displayName: 'Contact B',
          phones: <Phone>[Phone(number: '+40 722 111 222')],
          emails: <Email>[Email(address: 'SAME@example.com')],
        ),
      ],
    );

    final result = await service.scan();

    expect(result.duplicateGroups, hasLength(1));
    expect(
      result.duplicateGroups.single.reasons,
      equals(<DuplicateMatchReason>{
        DuplicateMatchReason.phone,
        DuplicateMatchReason.email,
      }),
    );
    expect(result.duplicateGroups.single.confidenceScore, 100);
  });

  test('filtreaza si deduplica metodele de contact in modelul scanat', () async {
    final service = NativeContactsScanService(
      requestPermission: () async => PermissionStatus.granted,
      readContacts: () async => const <Contact>[
        Contact(
          id: '1',
          displayName: '  Ana   Popescu  ',
          phones: <Phone>[
            Phone(number: '0712 345 678'),
            Phone(number: '+40 712 345 678'),
            Phone(number: '123'),
          ],
          emails: <Email>[
            Email(address: 'ANA@example.com'),
            Email(address: 'ana@example.com '),
            Email(address: 'invalid-email'),
          ],
        ),
        Contact(
          id: '2',
          displayName: 'Ana P.',
          phones: <Phone>[Phone(number: '+40712345678')],
          emails: <Email>[Email(address: 'ana@example.com')],
        ),
      ],
    );

    final result = await service.scan();
    final contact = result.duplicateGroups.single.contacts.firstWhere(
      (contact) => contact.nativeId == '1',
    );

    expect(contact.displayName, 'Ana Popescu');
    expect(contact.phones, <String>['+40712345678']);
    expect(contact.emails, <String>['ana@example.com']);
  });

  test('marcheaza ID-ul sintetic si numele placeholder separat', () async {
    final service = NativeContactsScanService(
      requestPermission: () async => PermissionStatus.granted,
      readContacts: () async => const <Contact>[
        Contact(
          id: '   ',
          displayName: '   ',
          phones: <Phone>[Phone(number: '0712 345 678')],
        ),
        Contact(
          id: 'stable',
          displayName: 'Ana',
          phones: <Phone>[Phone(number: '+40712345678')],
        ),
      ],
    );

    final result = await service.scan();
    final synthetic = result.duplicateGroups.single.contacts.firstWhere(
      (contact) => !contact.hasStableNativeId,
    );

    expect(synthetic.nativeId, startsWith('temporary-contact-'));
    expect(synthetic.hasOriginalDisplayName, isFalse);
    expect(synthetic.displayName, 'Contact fara nume');
  });

  test('ignora telefoanele scurte si adresele email invalide', () async {
    final service = NativeContactsScanService(
      requestPermission: () async => PermissionStatus.granted,
      readContacts: () async => const <Contact>[
        Contact(
          id: '1',
          displayName: 'Contact A',
          phones: <Phone>[Phone(number: '123')],
          emails: <Email>[Email(address: 'invalid-email')],
        ),
        Contact(
          id: '2',
          displayName: 'Contact B',
          phones: <Phone>[Phone(number: '123')],
          emails: <Email>[Email(address: 'invalid-email')],
        ),
      ],
    );

    final result = await service.scan();

    expect(result.duplicateGroups, isEmpty);
  });

  test('mapeaza orice esec al pluginului in failure', () async {
    final service = NativeContactsScanService(
      requestPermission: () async => PermissionStatus.granted,
      readContacts: () async => throw StateError('plugin failure'),
    );

    final result = await service.scan();

    expect(result.permissionState, ContactsPermissionState.failure);
    expect(result.errorCode, 'contacts_scan_failed');
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
