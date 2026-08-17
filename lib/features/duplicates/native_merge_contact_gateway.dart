import 'package:flutter_contacts/flutter_contacts.dart';

import '../../core/contacts/contact_data_normalizer.dart';
import '../../core/contacts/contact_models.dart';
import 'merge_engine_service.dart';
import 'merge_plan.dart';

class NativeMergeContactGateway implements MergeContactGateway {
  final ContactDataNormalizer _normalizer;

  NativeMergeContactGateway({ContactDataNormalizer? normalizer})
      : _normalizer = normalizer ?? ContactDataNormalizer();

  @override
  Future<bool> requestWritePermission() async {
    final status = await FlutterContacts.permissions.request(
      PermissionType.readWrite,
    );
    return status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
  }

  @override
  Future<Map<String, ContactRecord>> readContacts(Iterable<String> ids) async {
    final result = <String, ContactRecord>{};
    for (final rawId in ids) {
      final id = rawId.trim();
      if (id.isEmpty) continue;
      final contact = await FlutterContacts.get(
        id,
        properties: const <ContactProperty>{
          ContactProperty.name,
          ContactProperty.phone,
          ContactProperty.email,
          ContactProperty.address,
          ContactProperty.organization,
          ContactProperty.note,
          ContactProperty.photoThumbnail,
        },
      );
      if (contact != null) {
        result[id] = _mapContact(contact, expectedId: id);
      }
    }
    return result;
  }

  @override
  Future<MergeCreatedContact> createFromPlan(MergePlan plan) async {
    final unsupported = plan.selectedFields.where(
      (field) => !_supportedCreateKinds.contains(field.kind),
    );
    if (unsupported.isNotEmpty) {
      throw StateError('merge_native_unsupported_selected_fields');
    }

    final name = plan.selectedFields
        .where((field) => field.kind == MergeFieldKind.displayName)
        .map((field) => _normalizer.normalizeDisplayName(field.displayValue))
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    if (name == null) {
      throw StateError('merge_native_missing_display_name');
    }

    final phones = plan.selectedFields
        .where((field) => field.kind == MergeFieldKind.phone)
        .map((field) => _normalizer.normalizePhoneValue(field.displayValue))
        .where((value) => value.isMatchable)
        .map((value) => value.displayValue)
        .toSet()
        .map((value) => Phone(number: value))
        .toList(growable: false);
    final emails = plan.selectedFields
        .where((field) => field.kind == MergeFieldKind.email)
        .map((field) => _normalizer.normalizeEmailValue(field.displayValue))
        .where((value) => value.isMatchable)
        .map((value) => value.displayValue)
        .toSet()
        .map((value) => Email(address: value))
        .toList(growable: false);

    if (phones.isEmpty && emails.isEmpty) {
      throw StateError('merge_native_missing_contact_method');
    }

    final createdId = await FlutterContacts.create(
      Contact(
        name: Name(first: name),
        phones: phones,
        emails: emails,
      ),
    );
    final id = createdId.trim();
    if (id.isEmpty) throw StateError('merge_native_empty_created_id');
    final created = await FlutterContacts.get(
      id,
      properties: const <ContactProperty>{
        ContactProperty.name,
        ContactProperty.phone,
        ContactProperty.email,
      },
    );
    if (created == null) throw StateError('merge_native_created_contact_missing');
    final record = _mapContact(created, expectedId: id);
    return MergeCreatedContact(id: id, revision: record.revision);
  }

  @override
  Future<bool> verifyCreatedContact(String id, MergePlan plan) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return false;
    final contact = await FlutterContacts.get(
      normalizedId,
      properties: const <ContactProperty>{
        ContactProperty.name,
        ContactProperty.phone,
        ContactProperty.email,
      },
    );
    if (contact == null) return false;

    final expectedName = plan.selectedFields
        .where((field) => field.kind == MergeFieldKind.displayName)
        .map((field) => _normalizer.exactNameKey(field.displayValue))
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    if (expectedName == null) return false;
    final actualNames = <String>{
      _normalizer.exactNameKey(contact.displayName ?? ''),
      _normalizer.exactNameKey(contact.name?.first ?? ''),
    }..removeWhere((value) => value.isEmpty);
    if (!actualNames.contains(expectedName)) return false;

    final expectedPhones = plan.selectedFields
        .where((field) => field.kind == MergeFieldKind.phone)
        .map((field) => _normalizer.normalizePhone(field.displayValue))
        .where((value) => value.isNotEmpty)
        .toSet();
    final actualPhones = contact.phones
        .map((value) => _normalizer.normalizePhone(value.number))
        .where((value) => value.isNotEmpty)
        .toSet();
    if (!actualPhones.containsAll(expectedPhones)) return false;

    final expectedEmails = plan.selectedFields
        .where((field) => field.kind == MergeFieldKind.email)
        .map((field) => _normalizer.normalizeEmail(field.displayValue))
        .where((value) => value.isNotEmpty)
        .toSet();
    final actualEmails = contact.emails
        .map((value) => _normalizer.normalizeEmail(value.address))
        .where((value) => value.isNotEmpty)
        .toSet();
    return actualEmails.containsAll(expectedEmails);
  }

  @override
  Future<void> deleteContact(String id) => FlutterContacts.delete(id.trim());

  @override
  Future<bool> contactExists(String id) async {
    final normalized = id.trim();
    if (normalized.isEmpty) return false;
    return await FlutterContacts.get(
          normalized,
          properties: const <ContactProperty>{ContactProperty.name},
        ) !=
        null;
  }

  @override
  Future<bool> restoreContact(ContactRecord record) async {
    // Rollbackul distructiv ramane blocat pentru inregistrari care contin
    // proprietati pe care gatewayul curent nu le poate reconstrui integral.
    if (record.notesAvailable ||
        record.photoAvailable ||
        record.addresses.isNotEmpty ||
        record.organizations.isNotEmpty ||
        record.birthday != null ||
        record.isFavorite) {
      return false;
    }
    final id = await FlutterContacts.create(
      Contact(
        name: Name(first: record.name.displayName),
        phones: record.phones
            .map((value) => Phone(number: value.displayValue))
            .toList(growable: false),
        emails: record.emails
            .map((value) => Email(address: value.displayValue))
            .toList(growable: false),
      ),
    );
    return id.trim().isNotEmpty;
  }

  @override
  Future<bool> verifyRestoredContact(ContactRecord record) async {
    // Contactele recreate primesc alt ID nativ; fara ID-ul nou gatewayul nu poate
    // demonstra identitatea exacta, deci nu declara rollbackul verificat.
    return false;
  }

  ContactRecord _mapContact(Contact contact, {required String expectedId}) {
    final rawId = contact.id?.trim() ?? '';
    final nativeId = rawId.isNotEmpty ? rawId : expectedId;
    final displayName = _normalizer.normalizeDisplayName(contact.displayName ?? '');
    final normalizedName = displayName.isEmpty ? 'Contact fara nume' : displayName;
    final name = contact.name;
    final nameParts = ContactNameParts(
      displayName: normalizedName,
      givenName: _normalizer.sanitizeText(name?.first ?? ''),
      middleName: _normalizer.sanitizeText(name?.middle ?? ''),
      familyName: _normalizer.sanitizeText(name?.last ?? ''),
      prefix: _normalizer.sanitizeText(name?.prefix ?? ''),
      suffix: _normalizer.sanitizeText(name?.suffix ?? ''),
      hasOriginalDisplayName: displayName.isNotEmpty,
    );

    final phoneByKey = <String, ContactPhoneValue>{};
    for (final phone in contact.phones) {
      final value = _normalizer.normalizePhoneValue(phone.number);
      if (value.displayValue.isEmpty) continue;
      final key = value.isMatchable
          ? value.canonicalKey
          : 'raw:${value.displayValue.toLowerCase()}';
      phoneByKey.putIfAbsent(
        key,
        () => ContactPhoneValue(
          displayValue: value.displayValue,
          canonicalKey: value.canonicalKey,
          extension: value.extension,
          isMatchable: value.isMatchable,
        ),
      );
    }
    final emailByKey = <String, ContactEmailValue>{};
    for (final email in contact.emails) {
      final value = _normalizer.normalizeEmailValue(email.address);
      if (value.displayValue.isEmpty) continue;
      final key = value.isMatchable
          ? value.canonicalKey
          : 'raw:${value.displayValue.toLowerCase()}';
      emailByKey.putIfAbsent(
        key,
        () => ContactEmailValue(
          displayValue: value.displayValue,
          canonicalKey: value.canonicalKey,
          isMatchable: value.isMatchable,
        ),
      );
    }
    final phones = phoneByKey.values.toList()
      ..sort((a, b) => a.identityKey.compareTo(b.identityKey));
    final emails = emailByKey.values.toList()
      ..sort((a, b) => a.identityKey.compareTo(b.identityKey));

    final organizations = contact.organizations.map((organization) {
      final company = _normalizer.sanitizeText(organization.organizationName);
      return ContactOrganizationValue(
        company: company,
        department: _normalizer.sanitizeText(organization.departmentName),
        jobTitle: _normalizer.sanitizeText(organization.jobTitle),
        companyKey: _normalizer.companyKey(company),
      );
    }).where((value) => !value.isEmpty).toList(growable: false);
    final addresses = contact.addresses.map((address) {
      final components = <String>[
        address.street,
        address.city,
        address.state,
        address.postalCode,
        address.country,
      ];
      return ContactAddressValue(
        street: _normalizer.sanitizeText(address.street),
        city: _normalizer.sanitizeText(address.city),
        region: _normalizer.sanitizeText(address.state),
        postalCode: _normalizer.sanitizeText(address.postalCode),
        country: _normalizer.sanitizeText(address.country),
        canonicalKey: _normalizer.addressKey(components),
      );
    }).where((value) => !value.isEmpty).toList(growable: false);

    final revision = ContactRevisionInfo(
      fingerprint: ContactFingerprintBuilder(_normalizer).build(
        nativeId: nativeId,
        name: nameParts,
        phones: phones,
        emails: emails,
        addresses: addresses,
        organizations: organizations,
      ),
    );
    return ContactRecord(
      nativeId: nativeId,
      hasStableNativeId: rawId.isNotEmpty,
      name: nameParts,
      phones: phones,
      emails: emails,
      addresses: addresses,
      organizations: organizations,
      notesAvailable: contact.notes.isNotEmpty,
      photoAvailable: contact.photo?.thumbnail != null,
      capabilities: const ContactCapabilities(),
      revision: revision,
    );
  }

  static const Set<MergeFieldKind> _supportedCreateKinds = <MergeFieldKind>{
    MergeFieldKind.displayName,
    MergeFieldKind.phone,
    MergeFieldKind.email,
  };
}

extension _FirstOrNullNativeMerge<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
