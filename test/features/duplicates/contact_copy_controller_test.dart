import 'dart:async';

import 'package:contacte_duplicate/core/contacts/contact_copy_service.dart';
import 'package:contacte_duplicate/features/duplicates/contact_copy_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const draft = ContactCopyDraft(
    displayName: 'Ana Popescu',
    phones: <String>['0712345678'],
    emails: <String>['ana@example.com'],
    sourceContactIds: <String>['a', 'b'],
  );

  test('expune succesul dupa crearea copiei', () async {
    final controller = ContactCopyController(
      _FakeContactCopyService(
        result: const ContactCopyResult(
          status: ContactCopyStatus.success,
          createdContactId: 'copy-1',
        ),
      ),
    );

    final result = await controller.create(draft);

    expect(result?.isSuccess, isTrue);
    expect(controller.status, ContactCopyControllerStatus.success);
    expect(controller.result?.createdContactId, 'copy-1');
    expect(controller.matchesDraft(draft), isTrue);
  });

  test('nu asociaza succesul cu un draft modificat', () async {
    final controller = ContactCopyController(
      _FakeContactCopyService(
        result: const ContactCopyResult(
          status: ContactCopyStatus.success,
          createdContactId: 'copy-1',
        ),
      ),
    );
    await controller.create(draft);

    const changed = ContactCopyDraft(
      displayName: 'Ana Maria Popescu',
      phones: <String>['0712345678'],
      emails: <String>['ana@example.com'],
      sourceContactIds: <String>['a', 'b'],
    );

    expect(controller.matchesSources(changed.sourceContactIds), isTrue);
    expect(controller.matchesDraft(changed), isFalse);
  });

  test('accepta acelasi draft cu valori ordonate diferit', () async {
    final controller = ContactCopyController(
      _FakeContactCopyService(
        result: const ContactCopyResult(
          status: ContactCopyStatus.success,
          createdContactId: 'copy-1',
        ),
      ),
    );
    const multipleValues = ContactCopyDraft(
      displayName: 'Ana Popescu',
      phones: <String>['0712345678', '0722333444'],
      emails: <String>['ana@example.com', 'office@example.com'],
      sourceContactIds: <String>['a', 'b'],
    );
    await controller.create(multipleValues);

    const reordered = ContactCopyDraft(
      displayName: 'Ana Popescu',
      phones: <String>['0722333444', '0712345678'],
      emails: <String>['office@example.com', 'ana@example.com'],
      sourceContactIds: <String>['b', 'a'],
    );

    expect(controller.matchesDraft(reordered), isTrue);
  });

  test('ignora o a doua creare cat timp prima ruleaza', () async {
    final completer = Completer<ContactCopyResult>();
    final service = _FakeContactCopyService(createCompleter: completer);
    final controller = ContactCopyController(service);

    final first = controller.create(draft);
    final second = controller.create(draft);
    completer.complete(
      const ContactCopyResult(
        status: ContactCopyStatus.success,
        createdContactId: 'copy-2',
      ),
    );

    final results = await Future.wait<ContactCopyResult?>(
      <Future<ContactCopyResult?>>[
        first,
        second,
      ],
    );

    expect(service.createCalls, 1);
    expect(results.first?.createdContactId, 'copy-2');
    expect(results.last, isNull);
  });

  test('blocheaza repetarea aceluiasi draft dupa succes', () async {
    final service = _FakeContactCopyService(
      result: const ContactCopyResult(
        status: ContactCopyStatus.success,
        createdContactId: 'copy-1',
      ),
    );
    final controller = ContactCopyController(service);

    await controller.create(draft);
    final repeated = await controller.create(draft);

    expect(repeated, isNull);
    expect(service.createCalls, 1);
  });

  test('elimina copia verificata si permite recrearea draftului', () async {
    final service = _FakeContactCopyService(
      result: const ContactCopyResult(
        status: ContactCopyStatus.success,
        createdContactId: 'copy-remove',
      ),
      removalResult: const ContactCopyRemovalResult(
        status: ContactCopyRemovalStatus.success,
      ),
    );
    final controller = ContactCopyController(service);
    await controller.create(draft);

    final removal = await controller.removeCurrentCopy(draft);

    expect(removal?.isSuccess, isTrue);
    expect(controller.status, ContactCopyControllerStatus.removed);
    expect(service.removalCalls, 1);
    expect(service.lastRemovedId, 'copy-remove');
    expect(service.lastRemovalDraft?.fingerprint, draft.fingerprint);

    final recreated = await controller.create(draft);
    expect(recreated?.isSuccess, isTrue);
    expect(service.createCalls, 2);
  });

  test('refuza eliminarea pentru un draft diferit', () async {
    final service = _FakeContactCopyService(
      result: const ContactCopyResult(
        status: ContactCopyStatus.success,
        createdContactId: 'copy-1',
      ),
    );
    final controller = ContactCopyController(service);
    await controller.create(draft);

    const changed = ContactCopyDraft(
      displayName: 'Ana Maria Popescu',
      phones: <String>['0712345678'],
      emails: <String>['ana@example.com'],
      sourceContactIds: <String>['a', 'b'],
    );
    final removal = await controller.removeCurrentCopy(changed);

    expect(removal, isNull);
    expect(service.removalCalls, 0);
    expect(controller.status, ContactCopyControllerStatus.success);
  });

  test('pastreaza starea de esec daca identitatea nu corespunde', () async {
    final service = _FakeContactCopyService(
      result: const ContactCopyResult(
        status: ContactCopyStatus.success,
        createdContactId: 'copy-changed',
      ),
      removalResult: const ContactCopyRemovalResult(
        status: ContactCopyRemovalStatus.identityMismatch,
        errorCode: 'contact_copy_identity_mismatch',
      ),
    );
    final controller = ContactCopyController(service);
    await controller.create(draft);

    await controller.removeCurrentCopy(draft);

    expect(controller.status, ContactCopyControllerStatus.removalFailed);
    expect(
      controller.removalResult?.status,
      ContactCopyRemovalStatus.identityMismatch,
    );
    expect(await controller.create(draft), isNull);
  });

  test('pastreaza starea distincta cand rollbackul esueaza', () async {
    final controller = ContactCopyController(
      _FakeContactCopyService(
        result: const ContactCopyResult(
          status: ContactCopyStatus.rollbackFailed,
          createdContactId: 'copy-orphan',
          errorCode: 'contact_copy_rollback_failed',
        ),
      ),
    );

    await controller.create(draft);

    expect(controller.status, ContactCopyControllerStatus.rollbackFailed);
    expect(controller.result?.createdContactId, 'copy-orphan');
    expect(await controller.create(draft), isNull);
  });

  test('reseteaza rezultatul numai cand nu exista operatie activa', () async {
    final completer = Completer<ContactCopyResult>();
    final controller = ContactCopyController(
      _FakeContactCopyService(createCompleter: completer),
    );

    final pending = controller.create(draft);
    controller.reset();

    expect(controller.status, ContactCopyControllerStatus.creating);

    completer.complete(
      const ContactCopyResult(status: ContactCopyStatus.permissionDenied),
    );
    await pending;
    controller.reset();

    expect(controller.status, ContactCopyControllerStatus.idle);
    expect(controller.result, isNull);
    expect(controller.removalResult, isNull);
    expect(controller.matchesDraft(draft), isFalse);
  });
}

class _FakeContactCopyService implements ContactCopyService {
  final ContactCopyResult? result;
  final Completer<ContactCopyResult>? createCompleter;
  final ContactCopyRemovalResult? removalResult;
  final Completer<ContactCopyRemovalResult>? removalCompleter;

  int createCalls = 0;
  int removalCalls = 0;
  String? lastRemovedId;
  ContactCopyDraft? lastRemovalDraft;

  _FakeContactCopyService({
    this.result,
    this.createCompleter,
    this.removalResult,
    this.removalCompleter,
  });

  @override
  Future<ContactCopyResult> createVerifiedCopy(ContactCopyDraft draft) {
    createCalls++;
    final pending = createCompleter;
    if (pending != null) {
      return pending.future;
    }
    return Future<ContactCopyResult>.value(
      result ??
          const ContactCopyResult(
            status: ContactCopyStatus.createFailed,
          ),
    );
  }

  @override
  Future<ContactCopyRemovalResult> removeVerifiedCopy({
    required String createdContactId,
    required ContactCopyDraft expectedDraft,
  }) {
    removalCalls++;
    lastRemovedId = createdContactId;
    lastRemovalDraft = expectedDraft;
    final pending = removalCompleter;
    if (pending != null) {
      return pending.future;
    }
    return Future<ContactCopyRemovalResult>.value(
      removalResult ??
          const ContactCopyRemovalResult(
            status: ContactCopyRemovalStatus.deleteFailed,
          ),
    );
  }
}
