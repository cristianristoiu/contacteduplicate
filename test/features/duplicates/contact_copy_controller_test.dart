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
  });

  test('ignora o a doua creare cat timp prima ruleaza', () async {
    final completer = Completer<ContactCopyResult>();
    final service = _FakeContactCopyService(completer: completer);
    final controller = ContactCopyController(service);

    final first = controller.create(draft);
    final second = controller.create(draft);
    completer.complete(
      const ContactCopyResult(
        status: ContactCopyStatus.success,
        createdContactId: 'copy-2',
      ),
    );

    final results = await Future.wait<ContactCopyResult?>(<Future<ContactCopyResult?>>[
      first,
      second,
    ]);

    expect(service.calls, 1);
    expect(results.first?.createdContactId, 'copy-2');
    expect(results.last, isNull);
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
  });

  test('reseteaza rezultatul numai cand nu exista operatie activa', () async {
    final completer = Completer<ContactCopyResult>();
    final controller = ContactCopyController(
      _FakeContactCopyService(completer: completer),
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
  });
}

class _FakeContactCopyService implements ContactCopyService {
  final ContactCopyResult? result;
  final Completer<ContactCopyResult>? completer;
  int calls = 0;

  _FakeContactCopyService({this.result, this.completer});

  @override
  Future<ContactCopyResult> createVerifiedCopy(ContactCopyDraft draft) {
    calls++;
    final pending = completer;
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
}
