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

  Contact verifiedContact(String id) => Contact(
        id: id,
        displayName: 'Ana Popescu',
        name: const Name(first: 'Ana Popescu'),
        phones: const <Phone>[Phone(number: '+40712345678')],
        emails: const <Email>[Email(address: 'ana@example.com')],
      );

  test('creeaza si verifica o copie fara sa stearga sursele', () async {
    Contact? createdPayload;
    final deletedIds = <String>[];
    final service = NativeContactCopyService(
      requestPermission: () async => PermissionStatus.granted,
      createContact: (contact) async {
        createdPayload = contact;
        return ' copy-1 ';
      },
      readContact: (id) async => verifiedContact(id),
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

  test('accepta diacritice romanesti echivalente in verificarea numelui', () async {
    const accentedDraft = ContactCopyDraft(
      displayName: 'Ștefan Țară',
      phones: <String>['0712345678'],
      emails: <String>[],
      sourceContactIds: <String>['a', 'b'],
    );
    final service = NativeContactCopyService(
      requestPermission: () async => PermissionStatus.granted,
      createContact: (contact) async => 'copy-diacritics',
      readContact: (id) async => Contact(
        id: id,
        displayName: 'Stefan Tara',
        name: const Name(first: 'Stefan Tara'),
        phones: const <Phone>[Phone(number: '+40712345678')],
      ),
    );

    final result = await service.createVerifiedCopy(accentedDraft);

    expect(result.status, ContactCopyStatus.success);
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

  test('ignora metodele invalide in amprenta draftului', () {
    const equivalent = ContactCopyDraft(
      displayName: 'Ana Popescu',
      phones: <String>['0712 345 678', '123'],
      emails: <String>['ana@example.com', 'invalid-email'],
      sourceContactIds: <String>['a', 'b'],
    );
    const clean = ContactCopyDraft(
      displayName: 'Ana Popescu',
      phones: <String>['0712 345 678'],
      emails: <String>['ana@example.com'],
      sourceContactIds: <String>['a', 'b'],
    );

    expect(equivalent.fingerprint, clean.fingerprint);
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

  test('sterge copia noua si confirma absenta daca verificarea esueaza', () async {
    Contact? stored = Contact(
      id: 'copy-3',
      displayName: 'Ana Popescu',
      name: const Name(first: 'Ana Popescu'),
      phones: const <Phone>[Phone(number: '0700000000')],
      emails: const <Email>[],
    );
    final deletedIds = <String>[];
    final service = NativeContactCopyService(
      requestPermission: () async => PermissionStatus.granted,
      createContact: (contact) async => 'copy-3',
      readContact: (id) async => stored,
      deleteContact: (id) async {
        deletedIds.add(id);
        stored = null;
      },
    );

    final result = await service.createVerifiedCopy(draft);

    expect(result.status, ContactCopyStatus.verificationFailed);
    expect(result.createdContactId, isNull);
    expect(deletedIds, <String>['copy-3']);
  });

  test('raporteaza rollback esuat daca nu poate confirma absenta', () async {
    final service = NativeContactCopyService(
      requestPermission: () async => PermissionStatus.granted,
      createContact: (contact) async => 'copy-4',
      readContact: (id) async => verifiedContact(id),
      deleteContact: (id) async {},
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

  test('sterge copia numai dupa verificarea identitatii', () async {
    Contact? stored = verifiedContact('copy-remove');
    final deletedIds = <String>[];
    final service = NativeContactCopyService(
      requestPermission: () async => PermissionStatus.granted,
      readContact: (id) async => stored,
      deleteContact: (id) async {
        deletedIds.add(id);
        stored = null;
      },
    );

    final result = await service.removeVerifiedCopy(
      createdContactId: 'copy-remove',
      expectedDraft: draft,
    );

    expect(result.status, ContactCopyRemovalStatus.success);
    expect(deletedIds, <String>['copy-remove']);
  });

  test('refuza stergerea daca identitatea copiei nu mai corespunde', () async {
    final deletedIds = <String>[];
    final service = NativeContactCopyService(
      requestPermission: () async => PermissionStatus.granted,
      readContact: (id) async => Contact(
        id: id,
        displayName: 'Alta Persoana',
        name: const Name(first: 'Alta Persoana'),
        phones: const <Phone>[Phone(number: '0799999999')],
      ),
      deleteContact: (id) async => deletedIds.add(id),
    );

    final result = await service.removeVerifiedCopy(
      createdContactId: 'copy-changed',
      expectedDraft: draft,
    );

    expect(result.status, ContactCopyRemovalStatus.identityMismatch);
    expect(deletedIds, isEmpty);
  });

  test('considera reusita eliminarea unei copii deja absente', () async {
    final service = NativeContactCopyService(
      requestPermission: () async => PermissionStatus.granted,
      readContact: (id) async => null,
    );

    final result = await service.removeVerifiedCopy(
      createdContactId: 'copy-absent',
      expectedDraft: draft,
    );

    expect(result.status, ContactCopyRemovalStatus.alreadyAbsent);
    expect(result.isSuccess, isTrue);
  });

  test('detecteaza daca sistemul nu a eliminat copia', () async {
    final service = NativeContactCopyService(
      requestPermission: () async => PermissionStatus.granted,
      readContact: (id) async => verifiedContact(id),
      deleteContact: (id) async {},
    );

    final result = await service.removeVerifiedCopy(
      createdContactId: 'copy-persisted',
      expectedDraft: draft,
    );

    expect(result.status, ContactCopyRemovalStatus.verificationFailed);
  });

  test('esecul recitirii dupa delete este verificationFailed', () async {
    var reads = 0;
    final service = NativeContactCopyService(
      requestPermission: () async => PermissionStatus.granted,
      readContact: (id) async {
        reads++;
        if (reads == 1) {
          return verifiedContact(id);
        }
        throw StateError('read failed');
      },
      deleteContact: (id) async {},
    );

    final result = await service.removeVerifiedCopy(
      createdContactId: 'copy-read-failed',
      expectedDraft: draft,
    );

    expect(result.status, ContactCopyRemovalStatus.verificationFailed);
  });

  test('nu incearca eliminarea fara permisiune de scriere', () async {
    var deleteCalls = 0;
    final service = NativeContactCopyService(
      requestPermission: () async => PermissionStatus.denied,
      deleteContact: (id) async => deleteCalls++,
    );

    final result = await service.removeVerifiedCopy(
      createdContactId: 'copy-denied',
      expectedDraft: draft,
    );

    expect(result.status, ContactCopyRemovalStatus.permissionDenied);
    expect(deleteCalls, 0);
  });
}
