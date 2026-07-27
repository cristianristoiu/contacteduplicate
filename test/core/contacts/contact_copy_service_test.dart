import 'package:contacte_duplicate/core/contacts/contact_copy_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const draft = ContactCopyDraft(
    displayName: 'Ana Popescu',
    phones: <String>['0712 345 678', '+40 712 345 678'],
    emails: <String>['ANA@example.com', 'ana@example.com'],
    sourceContactIds: <String>['a', 'b'],
  );

  test('creeaza si verifica o copie fara sa stearga sursele', () async {
    Contact? createdPayload;
    final deletedIds = <String>[];
    final service = NativeContactCopyService(
      requestPermission: () async => PermissionStatus.granted,
      createContact: (contact) async {
        createdPayload = contact;
        return 'copy-1';
      },
      readContact: (id) async => Contact(
        id: id,
        displayName: 'Ana Popescu',
        name: const Name(first: 'Ana Popescu'),
        phones: const <Phone>[Phone(number: '+40712345678')],
        emails: const <Email>[Email(address: 'ana@example.com')],
      ),
      deleteContact: (id) async => deletedIds.add(id),
    );

    final result = await service.createVerifiedCopy(draft);

    expect(result.status, ContactCopyStatus.success);
    expect(result.createdContactId, 'copy-1');
    expect(createdPayload?.phones, hasLength(1));
    expect(createdPayload?.emails, hasLength(1));
    expect(deletedIds, isEmpty);
  });

  test('accepta numele nativ chiar daca displayName este reformatat', () async {
    final service = NativeContactCopyService(
      requestPermission: () async => PermissionStatus.granted,
      createContact: (contact) async => 'copy-name',
      readContact: (id) async => Contact(
        id: id,
        displayName: 'Popescu, Ana',
        name: const Name(first: '  ANA   POPESCU  '),
        phones: const <Phone>[Phone(number: '+40712345678')],
        emails: const <Email>[Email(address: 'ana@example.com')],
      ),
    );

    final result = await service.createVerifiedCopy(draft);

    expect(result.status, ContactCopyStatus.success);
    expect(result.createdContactId, 'copy-name');
  });

  test('genereaza aceeasi amprenta pentru ordini si formate echivalente', () {
    const equivalent = ContactCopyDraft(
      displayName: 'Ana  Popescu',
      phones: <String>['0040712345678', '0712-345-678'],
      emails: <String>['ana@example.com'],
      sourceContactIds: <String>['b', 'a'],
    );

    expect(equivalent.fingerprint, draft.fingerprint);
  });

  test('schimbarea unei valori modifica amprenta draftului', () {
    const changed = ContactCopyDraft(
      displayName: 'Ana Popescu',
      phones: <String>['0799999999'],
      emails: <String>['ana@example.com'],
      sourceContactIds: <String>['a', 'b'],
    );

    expect(changed.fingerprint, isNot(draft.fingerprint));
  });

  test('nu incearca scrierea cand permisiunea este refuzata', () async {
    var createCalls = 0;
    final service = NativeContactCopyService(
      requestPermission: () async => PermissionStatus.denied,
      createContact: (contact) async {
        createCalls++;
        return 'copy-2';
      },
    );

    final result = await service.createVerifiedCopy(draft);

    expect(result.status, ContactCopyStatus.permissionDenied);
    expect(createCalls, 0);
  });

  test('sterge copia noua daca verificarea datelor esueaza', () async {
    final deletedIds = <String>[];
    final service = NativeContactCopyService(
      requestPermission: () async => PermissionStatus.granted,
      createContact: (contact) async => 'copy-3',
      readContact: (id) async => Contact(
        id: id,
        displayName: 'Ana Popescu',
        name: const Name(first: 'Ana Popescu'),
        phones: const <Phone>[Phone(number: '0700000000')],
        emails: const <Email>[],
      ),
      deleteContact: (id) async => deletedIds.add(id),
    );

    final result = await service.createVerifiedCopy(draft);

    expect(result.status, ContactCopyStatus.verificationFailed);
    expect(result.createdContactId, isNull);
    expect(deletedIds, <String>['copy-3']);
  });

  test('raporteaza copia ramasa daca rollbackul esueaza', () async {
    final service = NativeContactCopyService(
      requestPermission: () async => PermissionStatus.granted,
      createContact: (contact) async => 'copy-4',
      readContact: (id) async => null,
      deleteContact: (id) async => throw Exception('delete failed'),
    );

    final result = await service.createVerifiedCopy(draft);

    expect(result.status, ContactCopyStatus.rollbackFailed);
    expect(result.createdContactId, 'copy-4');
    expect(result.errorCode, 'contact_copy_rollback_failed');
  });

  test('respinge draftul incomplet inainte de permisiuni', () async {
    var permissionCalls = 0;
    final service = NativeContactCopyService(
      requestPermission: () async {
        permissionCalls++;
        return PermissionStatus.granted;
      },
    );

    final result = await service.createVerifiedCopy(
      const ContactCopyDraft(
        displayName: ' ',
        phones: <String>[],
        emails: <String>[],
        sourceContactIds: <String>['a'],
      ),
    );

    expect(result.status, ContactCopyStatus.invalidDraft);
    expect(permissionCalls, 0);
  });
}
