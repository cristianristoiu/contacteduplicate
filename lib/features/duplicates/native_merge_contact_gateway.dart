import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../core/contacts/contact_data_normalizer.dart';
import '../../core/contacts/contact_models.dart';
import 'merge_engine_service.dart';
import 'merge_plan.dart';

class NativeMergeContactGateway implements MergeContactGateway {
  static const MethodChannel _contactsChannel = MethodChannel(
    'ro.contacteduplicate.app/contacts',
  );
  static const int _maxContactBatch = 100;

  final ContactDataNormalizer _normalizer;
  final Map<String, String> _restoredContactIds = <String, String>{};

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
    final normalizedIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    if (normalizedIds.isEmpty || normalizedIds.length > _maxContactBatch) {
      return const <String, ContactRecord>{};
    }

    final nativeMetadata = await _readNativeMetadataBatch(normalizedIds);
    final result = <String, ContactRecord>{};
    for (final id in normalizedIds) {
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
      if (contact == null) continue;
      result[id] = _mapContact(
        contact,
        expectedId: id,
        nativeMetadata: nativeMetadata[id] ?? const _NativeContactMetadata(),
      );
    }
    return Map<String, ContactRecord>.unmodifiable(result);
  }

  @override
  Future<MergeCreatedContact> createFromPlan(MergePlan plan) async {
    final unsupported = plan.selectedFields.where(
      (field) => !_supportedCreateKinds.contains(field.kind),
    );
    if (unsupported.isNotEmpty || plan.unsupportedFieldKinds.isNotEmpty) {
      throw StateError('merge_native_unsupported_selected_fields');
    }

    final fields = <MergeFieldKind, MergeSelectedField>{
      for (final field in plan.selectedFields) field.kind: field,
    };
    final displayName = _normalizer.normalizeDisplayName(
      fields[MergeFieldKind.displayName]?.displayValue ?? '',
    );
    if (displayName.isEmpty) {
      throw StateError('merge_native_missing_display_name');
    }

    final givenName = _cleanNameComponent(fields[MergeFieldKind.givenName]);
    final middleName = _cleanNameComponent(fields[MergeFieldKind.middleName]);
    final familyName = _cleanNameComponent(fields[MergeFieldKind.familyName]);
    final prefix = _cleanNameComponent(fields[MergeFieldKind.prefix]);
    final suffix = _cleanNameComponent(fields[MergeFieldKind.suffix]);
    final name = Name(
      first: givenName.isEmpty && familyName.isEmpty ? displayName : givenName,
      middle: middleName,
      last: familyName,
      prefix: prefix,
      suffix: suffix,
    );

    final phoneKeys = <String>{};
    final phones = <Phone>[];
    for (final field in plan.selectedFields.where(
      (field) => field.kind == MergeFieldKind.phone,
    )) {
      final value = _normalizer.normalizePhoneValue(field.displayValue);
      if (!value.isMatchable || !phoneKeys.add(value.canonicalKey)) continue;
      phones.add(Phone(number: value.displayValue));
    }

    final emailKeys = <String>{};
    final emails = <Email>[];
    for (final field in plan.selectedFields.where(
      (field) => field.kind == MergeFieldKind.email,
    )) {
      final value = _normalizer.normalizeEmailValue(field.displayValue);
      if (!value.isMatchable || !emailKeys.add(value.canonicalKey)) continue;
      emails.add(Email(address: value.displayValue));
    }

    if (phones.isEmpty && emails.isEmpty) {
      throw StateError('merge_native_missing_contact_method');
    }

    final createdId = await FlutterContacts.create(
      Contact(name: name, phones: phones, emails: emails),
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

    final expectedDisplayName = plan.selectedFields
        .where((field) => field.kind == MergeFieldKind.displayName)
        .map((field) => _normalizer.exactNameKey(field.displayValue))
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    if (expectedDisplayName == null) return false;

    final actualNames = <String>{
      _normalizer.exactNameKey(contact.displayName ?? ''),
      _normalizer.exactNameKey(contact.name?.first ?? ''),
      _normalizer.exactNameKey(
        <String>[
          contact.name?.prefix ?? '',
          contact.name?.first ?? '',
          contact.name?.middle ?? '',
          contact.name?.last ?? '',
          contact.name?.suffix ?? '',
        ].where((value) => value.trim().isNotEmpty).join(' '),
      ),
    }..removeWhere((value) => value.isEmpty);
    if (!actualNames.contains(expectedDisplayName) &&
        !_structuredNameMatches(contact.name, plan)) {
      return false;
    }

    final expectedPhones = plan.selectedFields
        .where((field) => field.kind == MergeFieldKind.phone)
        .map((field) => _normalizer.normalizePhone(field.displayValue))
        .where((value) => value.isNotEmpty)
        .toSet();
    final actualPhones = contact.phones
        .map((value) => _normalizer.normalizePhone(value.number))
        .where((value) => value.isNotEmpty)
        .toSet();
    if (!setEqualsStrings(expectedPhones, actualPhones)) return false;

    final expectedEmails = plan.selectedFields
        .where((field) => field.kind == MergeFieldKind.email)
        .map((field) => _normalizer.normalizeEmail(field.displayValue))
        .where((value) => value.isNotEmpty)
        .toSet();
    final actualEmails = contact.emails
        .map((value) => _normalizer.normalizeEmail(value.address))
        .where((value) => value.isNotEmpty)
        .toSet();
    return setEqualsStrings(expectedEmails, actualEmails);
  }

  @override
  Future<void> deleteContact(String id) async {
    final normalized = id.trim();
    if (normalized.isEmpty) throw StateError('merge_native_invalid_delete_id');
    await FlutterContacts.delete(normalized);
  }

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
    if (!_isBasicRecordRestorable(record)) return false;
    final createdId = await FlutterContacts.create(
      Contact(
        name: Name(
          first: record.name.givenName.isNotEmpty
              ? record.name.givenName
              : record.name.displayName,
          middle: record.name.middleName,
          last: record.name.familyName,
          prefix: record.name.prefix,
          suffix: record.name.suffix,
        ),
        phones: record.phones
            .map((value) => Phone(number: value.displayValue))
            .toList(growable: false),
        emails: record.emails
            .map((value) => Email(address: value.displayValue))
            .toList(growable: false),
      ),
    );
    final id = createdId.trim();
    if (id.isEmpty) return false;
    _restoredContactIds[record.nativeId] = id;
    return true;
  }

  @override
  Future<bool> verifyRestoredContact(ContactRecord record) async {
    final restoredId = _restoredContactIds[record.nativeId];
    if (restoredId == null || restoredId.isEmpty) return false;
    final contact = await FlutterContacts.get(
      restoredId,
      properties: const <ContactProperty>{
        ContactProperty.name,
        ContactProperty.phone,
        ContactProperty.email,
      },
    );
    if (contact == null) return false;
    final restored = _mapContact(contact, expectedId: restoredId);
    final namesMatch =
        _normalizer.exactNameKey(restored.name.displayName) ==
            _normalizer.exactNameKey(record.name.displayName) ||
        _normalizer.exactNameKey(restored.name.givenName) ==
            _normalizer.exactNameKey(record.name.givenName);
    if (!namesMatch) return false;
    final expectedPhones = record.phones
        .map((value) => value.canonicalKey)
        .where((value) => value.isNotEmpty)
        .toSet();
    final restoredPhones = restored.phones
        .map((value) => value.canonicalKey)
        .where((value) => value.isNotEmpty)
        .toSet();
    if (!setEqualsStrings(expectedPhones, restoredPhones)) return false;
    final expectedEmails = record.emails
        .map((value) => value.canonicalKey)
        .where((value) => value.isNotEmpty)
        .toSet();
    final restoredEmails = restored.emails
        .map((value) => value.canonicalKey)
        .where((value) => value.isNotEmpty)
        .toSet();
    final verified = setEqualsStrings(expectedEmails, restoredEmails);
    if (verified) _restoredContactIds.remove(record.nativeId);
    return verified;
  }

  Future<Map<String, _NativeContactMetadata>> _readNativeMetadataBatch(
    List<String> contactIds,
  ) async {
    if (!Platform.isAndroid) return const <String, _NativeContactMetadata>{};
    final operationToken = MergePlanFactory.generateOperationId(
      groupId: 'group-${contactIds.join('-')}',
    );
    try {
      final raw = await _contactsChannel.invokeMapMethod<String, Object?>(
        'preflightContacts',
        <String, Object?>{
          'contactIds': contactIds,
          'operationToken': operationToken,
          'requiresWrite': false,
        },
      );
      final contacts = raw?['contacts'];
      if (contacts is! List || contacts.length != contactIds.length) {
        return const <String, _NativeContactMetadata>{};
      }
      final result = <String, _NativeContactMetadata>{};
      for (var index = 0; index < contactIds.length; index++) {
        final item = contacts[index];
        if (item is! Map || item['found'] != true) continue;
        result[contactIds[index]] = _metadataFromMap(item);
      }
      return Map<String, _NativeContactMetadata>.unmodifiable(result);
    } on PlatformException {
      return const <String, _NativeContactMetadata>{};
    } on Object {
      return const <String, _NativeContactMetadata>{};
    }
  }

  _NativeContactMetadata _metadataFromMap(Map<dynamic, dynamic> raw) {
    final update = _capabilityFromName(raw['update']);
    final delete = _capabilityFromName(raw['delete']);
    final profile = raw['isProfile'] == true;
    final mixed = raw['hasMixedCapabilities'] == true;
    final fingerprint = raw['metadataFingerprint'];
    return _NativeContactMetadata(
      capabilities: ContactCapabilities(
        update: profile ? ContactAccessCapability.readOnly : update,
        delete: profile ? ContactAccessCapability.readOnly : delete,
        limitationCode: profile
            ? 'profile_contact'
            : mixed
                ? 'mixed_raw_contact_capabilities'
                : fingerprint is String && fingerprint.isNotEmpty
                    ? 'native_metadata_verified'
                    : 'native_metadata_unverified',
      ),
    );
  }

  ContactAccessCapability _capabilityFromName(Object? value) {
    return switch (value) {
      'writable' => ContactAccessCapability.writable,
      'readOnly' => ContactAccessCapability.readOnly,
      _ => ContactAccessCapability.unknown,
    };
  }

  bool _isBasicRecordRestorable(ContactRecord record) {
    return !record.notesAvailable &&
        !record.photoAvailable &&
        record.addresses.isEmpty &&
        record.organizations.isEmpty &&
        record.birthday == null &&
        !record.isFavorite;
  }

  String _cleanNameComponent(MergeSelectedField? field) {
    return _normalizer.sanitizeText(field?.displayValue ?? '');
  }

  bool _structuredNameMatches(Name? actual, MergePlan plan) {
    if (actual == null) return false;
    final expected = <MergeFieldKind, String>{};
    for (final field in plan.selectedFields) {
      if (_structuredNameKinds.contains(field.kind)) {
        expected[field.kind] = _normalizer.exactNameKey(field.displayValue);
      }
    }
    if (expected.isEmpty) return false;
    final actualByKind = <MergeFieldKind, String>{
      MergeFieldKind.givenName: _normalizer.exactNameKey(actual.first ?? ''),
      MergeFieldKind.middleName: _normalizer.exactNameKey(actual.middle ?? ''),
      MergeFieldKind.familyName: _normalizer.exactNameKey(actual.last ?? ''),
      MergeFieldKind.prefix: _normalizer.exactNameKey(actual.prefix ?? ''),
      MergeFieldKind.suffix: _normalizer.exactNameKey(actual.suffix ?? ''),
    };
    return expected.entries.every(
      (entry) => actualByKind[entry.key] == entry.value,
    );
  }

  ContactRecord _mapContact(
    Contact contact, {
    required String expectedId,
    _NativeContactMetadata nativeMetadata = const _NativeContactMetadata(),
  }) {
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
      source: nativeMetadata.source,
      capabilities: nativeMetadata.capabilities,
      revision: revision,
    );
  }

  static const Set<MergeFieldKind> _structuredNameKinds = <MergeFieldKind>{
    MergeFieldKind.givenName,
    MergeFieldKind.middleName,
    MergeFieldKind.familyName,
    MergeFieldKind.prefix,
    MergeFieldKind.suffix,
  };

  static const Set<MergeFieldKind> _supportedCreateKinds = <MergeFieldKind>{
    MergeFieldKind.displayName,
    ..._structuredNameKinds,
    MergeFieldKind.phone,
    MergeFieldKind.email,
  };
}

class _NativeContactMetadata {
  final ContactCapabilities capabilities;
  final ContactSourceInfo source;

  const _NativeContactMetadata({
    this.capabilities = const ContactCapabilities(),
    this.source = const ContactSourceInfo(),
  });
}

extension _FirstOrNullNativeMerge<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
