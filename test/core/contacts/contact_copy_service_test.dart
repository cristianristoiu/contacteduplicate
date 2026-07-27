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
        phones: <Phone>[Phone('+40712345678')],
        emails: <Email>[Email('ana@example.com')],
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
        phones: <Phone>[Phone('0700000000')],
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
