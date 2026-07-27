import 'package:contacte_duplicate/core/contacts/contacts_scan_service.dart';
import 'package:contacte_duplicate/features/duplicates/merge_detail_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const contactA = ScannedContact(
    nativeId: 'a',
    displayName: 'Ana',
    phones: <String>['0722 123 456'],
    emails: <String>['ANA@EXAMPLE.COM'],
  );
  const contactB = ScannedContact(
    nativeId: 'b',
    displayName: 'Ana Popescu',
    phones: <String>['+40 722 123 456', '0733 000 111'],
    emails: <String>['ana@example.com', 'work@example.com'],
  );
  const group = DuplicateContactGroup(
    id: 'a|b',
    contacts: <ScannedContact>[contactA, contactB],
    reasons: <DuplicateMatchReason>{
      DuplicateMatchReason.phone,
      DuplicateMatchReason.email,
    },
    confidenceScore: 92,
  );

  test('porneste cu sursa cea mai completa si pastreaza toate valorile', () {
    final controller = MergeDetailController(group);

    expect(controller.masterContactId, 'b');
    expect(controller.displayName, 'Ana Popescu');
    expect(controller.phoneOptions, hasLength(2));
    expect(controller.emailOptions, hasLength(2));
    expect(controller.selectedPhones, hasLength(2));
    expect(controller.selectedEmails, hasLength(2));
    expect(controller.isValid, isTrue);
  });

  test('deduplica formatele echivalente fara a pierde sursele', () {
    final controller = MergeDetailController(group);

    final sharedPhone = controller.phoneOptions.firstWhere(
      (option) => option.sourceContactIds.length == 2,
    );
    final sharedEmail = controller.emailOptions.firstWhere(
      (option) => option.sourceContactIds.length == 2,
    );

    expect(sharedPhone.sourceContactIds, containsAll(<String>['a', 'b']));
    expect(sharedEmail.sourceContactIds, containsAll(<String>['a', 'b']));
  });

  test('alegerea sursei principale selecteaza doar valorile acelei surse', () {
    final controller = MergeDetailController(group);

    controller.selectMaster('a');

    expect(controller.masterContactId, 'a');
    expect(controller.displayName, 'Ana');
    expect(controller.selectedPhones, hasLength(1));
    expect(controller.selectedEmails, hasLength(1));

    controller.keepAllValues();

    expect(controller.selectedPhones, hasLength(2));
    expect(controller.selectedEmails, hasLength(2));
  });

  test('blocheaza rezultatul fara nume si fara metoda de contact', () {
    final controller = MergeDetailController(group);

    controller.updateDisplayName('   ');
    for (final option in controller.phoneOptions) {
      controller.setPhoneSelected(option.id, false);
    }
    for (final option in controller.emailOptions) {
      controller.setEmailSelected(option.id, false);
    }

    expect(controller.isValid, isFalse);
    expect(
      controller.validationMessages,
      <String>[
        'Numele final este obligatoriu.',
        'Pastreaza cel putin un telefon sau o adresa de email.',
      ],
    );
  });

  test('resetarea revine la varianta conservatoare', () {
    final controller = MergeDetailController(group);
    controller.selectMaster('a');
    controller.updateDisplayName('Nume temporar');

    controller.resetToSafeDefault();

    expect(controller.masterContactId, 'b');
    expect(controller.displayName, 'Ana Popescu');
    expect(controller.selectedPhones, hasLength(2));
    expect(controller.selectedEmails, hasLength(2));
  });
}
