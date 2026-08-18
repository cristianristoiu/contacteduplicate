import 'package:flutter/foundation.dart';

import '../../core/contacts/contact_data_normalizer.dart';
import '../../core/contacts/contact_models.dart';
import '../../core/contacts/contacts_scan_service.dart';
import 'merge_plan.dart';

enum MergeValueType { phone, email }

@immutable
class MergeValueOption {
  final String id;
  final String value;
  final String canonicalValue;
  final String label;
  final MergeValueType type;
  final List<String> sourceContactIds;

  const MergeValueOption({
    required this.id,
    required this.value,
    required this.canonicalValue,
    required this.label,
    required this.type,
    required this.sourceContactIds,
  });
}

@immutable
class MergeDraft {
  final String displayName;
  final String masterContactId;
  final List<String> phones;
  final List<String> emails;

  const MergeDraft({
    required this.displayName,
    required this.masterContactId,
    required this.phones,
    required this.emails,
  });
}

class MergeDetailController extends ChangeNotifier {
  static final ContactDataNormalizer _normalizer = ContactDataNormalizer();

  final DuplicateContactGroup group;
  late final Map<String, ScannedContact> _contactsById;
  late final List<MergeValueOption> phoneOptions;
  late final List<MergeValueOption> emailOptions;
  late final String _recommendedMasterContactId;

  late String _masterContactId;
  late String _displayName;
  late Set<String> _selectedPhoneIds;
  late Set<String> _selectedEmailIds;
  bool _manualReviewAcknowledged = false;

  MergeDetailController(this.group) {
    if (group.contacts.length < 2) {
      throw ArgumentError.value(
        group.contacts.length,
        'group.contacts.length',
        'Previzualizarea fuziunii necesita cel putin doua contacte.',
      );
    }

    _contactsById = <String, ScannedContact>{
      for (final contact in group.contacts) contact.nativeId: contact,
    };
    if (_contactsById.length != group.contacts.length) {
      throw ArgumentError.value(
        group.id,
        'group.id',
        'Grupul contine identificatori de contact duplicati.',
      );
    }

    phoneOptions = List<MergeValueOption>.unmodifiable(_buildPhoneOptions());
    emailOptions = List<MergeValueOption>.unmodifiable(_buildEmailOptions());
    _recommendedMasterContactId = _recommendedMaster(group.contacts).nativeId;
    _resetToSafeDefault(notify: false);
  }

  List<ScannedContact> get contacts => group.contacts;
  String get masterContactId => _masterContactId;
  String get displayName => _displayName;
  bool get manualReviewAcknowledged => _manualReviewAcknowledged;

  bool get hasStableSourceIds =>
      group.contacts.every((contact) => contact.hasStableNativeId);

  bool get hasWritableDeleteTargets => group.contacts.any(
        (contact) => contact.record?.capabilities.isFullyWritable ?? false,
      );

  bool get hasUnknownCapabilities => group.contacts.any((contact) {
        final capabilities = contact.record?.capabilities;
        return capabilities == null ||
            (!capabilities.isFullyWritable && !capabilities.isKnownReadOnly);
      });

  bool get hasReadOnlySources => group.contacts.any(
        (contact) => contact.record?.capabilities.isKnownReadOnly ?? false,
      );

  Map<String, ContactRecord> get sourceRecords =>
      Map<String, ContactRecord>.unmodifiable(<String, ContactRecord>{
        for (final contact in group.contacts)
          if (contact.record != null) contact.nativeId: contact.record!,
      });

  Set<String> get selectedPhoneIds => Set<String>.unmodifiable(
        _selectedPhoneIds,
      );
  Set<String> get selectedEmailIds => Set<String>.unmodifiable(
        _selectedEmailIds,
      );

  List<MergeValueOption> get selectedPhoneOptions =>
      List<MergeValueOption>.unmodifiable(
        phoneOptions.where((option) => _selectedPhoneIds.contains(option.id)),
      );
  List<MergeValueOption> get selectedEmailOptions =>
      List<MergeValueOption>.unmodifiable(
        emailOptions.where((option) => _selectedEmailIds.contains(option.id)),
      );

  List<String> get selectedPhones => List<String>.unmodifiable(
        selectedPhoneOptions.map((option) => option.value),
      );
  List<String> get selectedEmails => List<String>.unmodifiable(
        selectedEmailOptions.map((option) => option.value),
      );

  bool get hasContactMethod =>
      _selectedPhoneIds.isNotEmpty || _selectedEmailIds.isNotEmpty;

  bool get isValid =>
      hasStableSourceIds && _displayName.trim().isNotEmpty && hasContactMethod;

  Set<MergeFieldKind> get unsupportedFieldKinds {
    final unsupported = <MergeFieldKind>{};
    for (final record in sourceRecords.values) {
      if (record.addresses.isNotEmpty) unsupported.add(MergeFieldKind.address);
      for (final organization in record.organizations) {
        if (organization.company.trim().isNotEmpty) {
          unsupported.add(MergeFieldKind.company);
        }
        if (organization.department.trim().isNotEmpty) {
          unsupported.add(MergeFieldKind.department);
        }
        if (organization.jobTitle.trim().isNotEmpty) {
          unsupported.add(MergeFieldKind.jobTitle);
        }
      }
      if (record.birthday != null) unsupported.add(MergeFieldKind.birthday);
      if (record.notesAvailable) unsupported.add(MergeFieldKind.note);
      if (record.photoAvailable) unsupported.add(MergeFieldKind.photo);
      if (record.isFavorite) unsupported.add(MergeFieldKind.favorite);
    }
    return Set<MergeFieldKind>.unmodifiable(unsupported);
  }

  bool get canAttemptDestructiveMerge =>
      isValid &&
      group.canBeMerged &&
      !group.overlapsAnotherGroup &&
      hasWritableDeleteTargets &&
      !hasUnknownCapabilities &&
      unsupportedFieldKinds.isEmpty &&
      (!group.requiresManualReview || _manualReviewAcknowledged);

  List<String> get validationMessages => <String>[
        if (!hasStableSourceIds)
          'Cel putin un contact sursa nu are un ID nativ stabil si nu poate fi folosit pentru o operatie de scriere verificabila.',
        if (_displayName.trim().isEmpty) 'Numele final este obligatoriu.',
        if (!hasContactMethod)
          'Pastreaza cel putin un telefon sau o adresa de email.',
        if (hasUnknownCapabilities)
          'Capabilitatea de modificare a cel putin unei surse nu este demonstrata.',
        if (unsupportedFieldKinds.isNotEmpty)
          'Exista campuri bogate care nu pot fi conservate inca de motorul curent; fuziunea distructiva ramane blocata.',
        if (group.requiresManualReview && !_manualReviewAcknowledged)
          'Grupul necesita confirmarea explicita a verificarii manuale.',
      ];

  MergeDraft get draft => MergeDraft(
        displayName: _normalizer.normalizeDisplayName(_displayName),
        masterContactId: _masterContactId,
        phones: selectedPhones,
        emails: selectedEmails,
      );

  List<MergeSelectedField> get selectedFieldsForPlan {
    final selected = <MergeSelectedField>[];
    final master = _contactsById[_masterContactId]?.record;
    final displayName = _normalizer.normalizeDisplayName(_displayName);
    if (displayName.isNotEmpty) {
      selected.add(
        MergeSelectedField(
          optionId: stableOpaqueId(
            <String>['displayName', _masterContactId, displayName],
            namespace: 'merge-option',
          ),
          kind: MergeFieldKind.displayName,
          displayValue: displayName,
          canonicalValue: _normalizer.exactNameKey(displayName),
          sourceContactIds: <String>[_masterContactId],
        ),
      );
    }
    if (master != null) {
      _addNameField(
        selected,
        MergeFieldKind.givenName,
        master.name.givenName,
      );
      _addNameField(
        selected,
        MergeFieldKind.middleName,
        master.name.middleName,
      );
      _addNameField(
        selected,
        MergeFieldKind.familyName,
        master.name.familyName,
      );
      _addNameField(selected, MergeFieldKind.prefix, master.name.prefix);
      _addNameField(selected, MergeFieldKind.suffix, master.name.suffix);
    }
    for (final option in selectedPhoneOptions) {
      selected.add(
        MergeSelectedField(
          optionId: option.id,
          kind: MergeFieldKind.phone,
          displayValue: option.value,
          canonicalValue: option.canonicalValue,
          sourceContactIds: option.sourceContactIds,
          metadata: <String, String>{
            if (option.label.isNotEmpty) 'label': option.label,
          },
        ),
      );
    }
    for (final option in selectedEmailOptions) {
      selected.add(
        MergeSelectedField(
          optionId: option.id,
          kind: MergeFieldKind.email,
          displayValue: option.value,
          canonicalValue: option.canonicalValue,
          sourceContactIds: option.sourceContactIds,
          metadata: <String, String>{
            if (option.label.isNotEmpty) 'label': option.label,
          },
        ),
      );
    }
    return List<MergeSelectedField>.unmodifiable(selected);
  }

  MergePlan buildPlan({
    required String backupId,
    required int scanRevision,
    required String operationId,
  }) {
    return const MergePlanFactory().fromGroup(
      group: group,
      scanRevision: scanRevision,
      backupId: backupId,
      operationId: operationId,
      masterContactId: _masterContactId,
      selectedFields: selectedFieldsForPlan,
      unsupportedFieldKinds: unsupportedFieldKinds,
      manualReviewAcknowledged: _manualReviewAcknowledged,
    );
  }

  void acknowledgeManualReview(bool value) {
    if (!group.requiresManualReview || _manualReviewAcknowledged == value) {
      return;
    }
    _manualReviewAcknowledged = value;
    notifyListeners();
  }

  void selectMaster(String nativeId) {
    final contact = _contactsById[nativeId];
    if (contact == null || nativeId == _masterContactId) return;

    _masterContactId = nativeId;
    _displayName = contact.hasOriginalDisplayName
        ? _normalizer.normalizeDisplayName(contact.displayName)
        : '';
    _selectedPhoneIds = _optionIdsForSource(phoneOptions, nativeId);
    _selectedEmailIds = _optionIdsForSource(emailOptions, nativeId);
    _manualReviewAcknowledged = false;
    notifyListeners();
  }

  void updateDisplayName(String value) {
    if (value == _displayName) return;
    _displayName = value;
    notifyListeners();
  }

  void setPhoneSelected(String optionId, bool selected) {
    if (!phoneOptions.any((option) => option.id == optionId)) return;
    if (_setSelection(_selectedPhoneIds, optionId, selected)) notifyListeners();
  }

  void setEmailSelected(String optionId, bool selected) {
    if (!emailOptions.any((option) => option.id == optionId)) return;
    if (_setSelection(_selectedEmailIds, optionId, selected)) notifyListeners();
  }

  void keepAllValues() {
    final allPhones = phoneOptions.map((option) => option.id).toSet();
    final allEmails = emailOptions.map((option) => option.id).toSet();
    if (setEquals(allPhones, _selectedPhoneIds) &&
        setEquals(allEmails, _selectedEmailIds)) return;
    _selectedPhoneIds = allPhones;
    _selectedEmailIds = allEmails;
    notifyListeners();
  }

  void resetToSafeDefault() => _resetToSafeDefault(notify: true);

  void _resetToSafeDefault({required bool notify}) {
    _masterContactId = _recommendedMasterContactId;
    final selectedContact = _contactsById[_recommendedMasterContactId]!;
    _displayName = selectedContact.hasOriginalDisplayName
        ? _normalizer.normalizeDisplayName(selectedContact.displayName)
        : '';
    _selectedPhoneIds = phoneOptions.map((option) => option.id).toSet();
    _selectedEmailIds = emailOptions.map((option) => option.id).toSet();
    _manualReviewAcknowledged = false;
    if (notify) notifyListeners();
  }

  List<MergeValueOption> _buildPhoneOptions() {
    final byKey = <String, _MutableMergeOption>{};
    for (final contact in group.contacts) {
      final recordPhones = contact.record?.phones ?? const <ContactPhoneValue>[];
      if (recordPhones.isNotEmpty) {
        for (final phone in recordPhones) {
          if (!phone.isMatchable || phone.canonicalKey.isEmpty) continue;
          _mergeOption(
            byKey,
            canonicalKey: phone.canonicalKey,
            displayValue: phone.displayValue,
            label: phone.label,
            sourceId: contact.nativeId,
          );
        }
      } else {
        for (final raw in contact.phones) {
          final normalized = _normalizer.normalizePhoneValue(raw);
          if (!normalized.isMatchable || normalized.canonicalKey.isEmpty) continue;
          _mergeOption(
            byKey,
            canonicalKey: normalized.canonicalKey,
            displayValue: normalized.displayValue,
            label: '',
            sourceId: contact.nativeId,
          );
        }
      }
    }
    return _finishOptions(byKey, MergeValueType.phone);
  }

  List<MergeValueOption> _buildEmailOptions() {
    final byKey = <String, _MutableMergeOption>{};
    for (final contact in group.contacts) {
      final recordEmails = contact.record?.emails ?? const <ContactEmailValue>[];
      if (recordEmails.isNotEmpty) {
        for (final email in recordEmails) {
          if (!email.isMatchable || email.canonicalKey.isEmpty) continue;
          _mergeOption(
            byKey,
            canonicalKey: email.canonicalKey,
            displayValue: email.displayValue,
            label: email.label,
            sourceId: contact.nativeId,
          );
        }
      } else {
        for (final raw in contact.emails) {
          final normalized = _normalizer.normalizeEmailValue(raw);
          if (!normalized.isMatchable || normalized.canonicalKey.isEmpty) continue;
          _mergeOption(
            byKey,
            canonicalKey: normalized.canonicalKey,
            displayValue: normalized.displayValue,
            label: '',
            sourceId: contact.nativeId,
          );
        }
      }
    }
    return _finishOptions(byKey, MergeValueType.email);
  }

  void _mergeOption(
    Map<String, _MutableMergeOption> target, {
    required String canonicalKey,
    required String displayValue,
    required String label,
    required String sourceId,
  }) {
    final existing = target[canonicalKey];
    if (existing == null) {
      target[canonicalKey] = _MutableMergeOption(
        canonicalValue: canonicalKey,
        value: displayValue,
        label: label,
        sourceContactIds: <String>[sourceId],
      );
      return;
    }
    if (!existing.sourceContactIds.contains(sourceId)) {
      existing.sourceContactIds.add(sourceId);
    }
    if (existing.label.isEmpty && label.isNotEmpty) existing.label = label;
  }

  List<MergeValueOption> _finishOptions(
    Map<String, _MutableMergeOption> source,
    MergeValueType type,
  ) {
    final entries = source.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return entries.map((entry) {
      final sourceIds = entry.value.sourceContactIds.toList()..sort();
      return MergeValueOption(
        id: stableOpaqueId(
          <String>[type.name, entry.key, ...sourceIds],
          namespace: 'merge-option',
        ),
        value: entry.value.value,
        canonicalValue: entry.value.canonicalValue,
        label: entry.value.label,
        type: type,
        sourceContactIds: List<String>.unmodifiable(sourceIds),
      );
    }).toList(growable: false);
  }

  void _addNameField(
    List<MergeSelectedField> selected,
    MergeFieldKind kind,
    String rawValue,
  ) {
    final display = _normalizer.sanitizeText(rawValue);
    if (display.isEmpty) return;
    selected.add(
      MergeSelectedField(
        optionId: stableOpaqueId(
          <String>[kind.name, _masterContactId, display],
          namespace: 'merge-option',
        ),
        kind: kind,
        displayValue: display,
        canonicalValue: _normalizer.exactNameKey(display),
        sourceContactIds: <String>[_masterContactId],
      ),
    );
  }

  static bool _setSelection(Set<String> target, String id, bool selected) =>
      selected ? target.add(id) : target.remove(id);

  static Set<String> _optionIdsForSource(
    List<MergeValueOption> options,
    String nativeId,
  ) =>
      options
          .where((option) => option.sourceContactIds.contains(nativeId))
          .map((option) => option.id)
          .toSet();

  static ScannedContact _recommendedMaster(List<ScannedContact> contacts) {
    var selected = contacts.first;
    var selectedScore = _completenessScore(selected);
    for (final contact in contacts.skip(1)) {
      final score = _completenessScore(contact);
      if (score > selectedScore ||
          (score == selectedScore &&
              contact.nativeId.compareTo(selected.nativeId) < 0)) {
        selected = contact;
        selectedScore = score;
      }
    }
    return selected;
  }

  static int _completenessScore(ScannedContact contact) {
    final record = contact.record;
    final writableBonus = record?.capabilities.isFullyWritable == true ? 8 : 0;
    final richData = record == null
        ? 0
        : record.addresses.length +
            record.organizations.length +
            (record.birthday == null ? 0 : 1) +
            (record.isFavorite ? 1 : 0);
    return writableBonus +
        (contact.hasOriginalDisplayName ? 4 : 0) +
        contact.phones.length * 2 +
        contact.emails.length * 2 +
        richData +
        (contact.hasStableNativeId ? 2 : 0);
  }
}

class _MutableMergeOption {
  final String canonicalValue;
  final String value;
  String label;
  final List<String> sourceContactIds;

  _MutableMergeOption({
    required this.canonicalValue,
    required this.value,
    required this.label,
    required this.sourceContactIds,
  });
}
