import 'package:contacte_duplicate/core/contacts/contact_data_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final normalizer = ContactDataNormalizer();

  test('normalizeaza formatele telefonice romanesti echivalente', () {
    expect(normalizer.normalizePhone('0722 123 456'), '+40722123456');
    expect(normalizer.normalizePhone('0040 722 123 456'), '+40722123456');
    expect(normalizer.normalizePhone('+40 (0) 722 123 456'), '+40722123456');
  });

  test('respinge numerele invalide structural', () {
    expect(normalizer.normalizePhone('0000000'), isEmpty);
    expect(normalizer.normalizePhone('12+3456789'), isEmpty);
    expect(normalizer.normalizePhone('123'), isEmpty);
    expect(normalizer.normalizePhone('+1234567890123456'), isEmpty);
  });

  test('valideaza codul de tara', () {
    expect(ContactDataNormalizer.sanitizeCountryCallingCode('+40'), '40');
    expect(ContactDataNormalizer.sanitizeCountryCallingCode('0040'), isNull);
    expect(ContactDataNormalizer.sanitizeCountryCallingCode('000'), isNull);
    expect(ContactDataNormalizer.sanitizeCountryCallingCode('1234'), isNull);
  });

  test('normalizeaza si valideaza emailurile', () {
    expect(normalizer.normalizeEmail(' ANA@Example.com '), 'ana@example.com');
    expect(normalizer.normalizeEmail('.ana@example.com'), isEmpty);
    expect(normalizer.normalizeEmail('ana..x@example.com'), isEmpty);
    expect(normalizer.normalizeEmail('ana@-example.com'), isEmpty);
    expect(normalizer.normalizeEmail('ana@@example.com'), isEmpty);
  });

  test('normalizeaza numele si elimina caractere invizibile', () {
    expect(normalizer.normalizeDisplayName('  Ana\u200B   Popescu  '), 'Ana Popescu');
    expect(normalizer.canonicalName('Ștefan ȚÂRĂ'), 'stefan tara');
  });
}
