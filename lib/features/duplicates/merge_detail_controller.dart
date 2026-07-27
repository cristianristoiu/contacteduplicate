import 'package:flutter/foundation.dart';

import '../../core/contacts/contacts_scan_service.dart';

enum MergeValueType {
  phone,
  email,
}

@immutable
class MergeValueOption {
  final String id;
  final String value;
  final MergeValueType type;
  final List<String> sourceContactIds;

  const MergeValueOption({
    required this.id,
    required this.value,
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
  final DuplicateContactGroup group;
  late final Map<String, ScannedContact> _contactsById;
  late final List<MergeValueOption> phoneOptions;
  late final List<MergeValueOption> emailOptions;
  late final String _recommendedMasterContactId;

  late String _masterContactId;
  late String _displayName;
  late Set<String> _selectedPhoneIds;
  late Set<String> _selectedEmailIds;

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

    phoneOptions = List<MergeValueOption>.unmodifiable(
      _buildOptions(
        group.contacts,
        MergeValueType.phone,
        (contact) => contact.phones,
      ),
    );
    emailOptions = List<MergeValueOption>.unmodifiable(
      _buildOptions(
        group.contacts,
        MergeValueType.email,
        (contact) => contact.emails,
      ),
    );
    _recommendedMasterContactId = _recommendedMaster(group.contacts).nativeId;
    _resetToSafeDefault(notify: false);
  }

  List<ScannedContact> get contacts => group.contacts;

  String get masterContactId => _masterContactId;

  String get displayName => _displayName;

  Set<String> get selectedPhoneIds => Set<String>.unmodifiable(
        _selectedPhoneIds,
      );

  Set<String> get selectedEmailIds => Set<String>.unmodifiable(
        _selectedEmailIds,
      );

  List<String> get selectedPhones => List<String>.unmodifiable(
        phoneOptions
            .where((option) => _selectedPhoneIds.contains(option.id))
            .map((option) => option.value),
      );

  List<String> get selectedEmails => List<String>.unmodifiable(
        emailOptions
            .where((option) => _selectedEmailIds.contains(option.id))
            .map((option) => option.value),
      );

  bool get hasContactMethod =>
      _selectedPhoneIds.isNotEmpty || _selectedEmailIds.isNotEmpty;

  bool get isValid => _displayName.trim().isNotEmpty && hasContactMethod;

  List<String> get validationMessages {
    return <String>[
      if (_displayName.trim().isEmpty) 'Numele final este obligatoriu.',
      if (!hasContactMethod)
        'Pastreaza cel putin un telefon sau o adresa de email.',
    ];
  }

  MergeDraft get draft => MergeDraft(
        displayName: _displayName.trim(),
        masterContactId: _masterContactId,
        phones: selectedPhones,
        emails: selectedEmails,
      );

  void selectMaster(String nativeId) {
    final contact = _contactsById[nativeId];
    if (contact == null || nativeId == _masterContactId) {
      return;
    }

    _masterContactId = nativeId;
    _displayName = contact.displayName.trim();
    _selectedPhoneIds = _optionIdsForSource(phoneOptions, nativeId);
    _selectedEmailIds = _optionIdsForSource(emailOptions, nativeId);
    notifyListeners();
  }

  void updateDisplayName(String value) {
    if (value == _displayName) {
      return;
    }
    _displayName = value;
    notifyListeners();
  }

  void setPhoneSelected(String optionId, bool selected) {
    if (!phoneOptions.any((option) => option.id == optionId)) {
      return;
    }
    if (_setSelection(_selectedPhoneIds, optionId, selected)) {
      notifyListeners();
    }
  }

  void setEmailSelected(String optionId, bool selected) {
    if (!emailOptions.any((option) => option.id == optionId)) {
      return;
    }
    if (_setSelection(_selectedEmailIds, optionId, selected)) {
      notifyListeners();
    }
  }

  void keepAllValues() {
    final allPhones = phoneOptions.map((option) => option.id).toSet();
    final allEmails = emailOptions.map((option) => option.id).toSet();
    if (setEquals(allPhones, _selectedPhoneIds) &&
        setEquals(allEmails, _selectedEmailIds)) {
      return;
    }
    _selectedPhoneIds = allPhones;
    _selectedEmailIds = allEmails;
    notifyListeners();
  }

  void resetToSafeDefault() {
    _resetToSafeDefault(notify: true);
  }

  void _resetToSafeDefault({required bool notify}) {
    _masterContactId = _recommendedMasterContactId;
    _displayName = _contactsById[_recommendedMasterContactId]!
        .displayName
        .trim();
    _selectedPhoneIds = phoneOptions.map((option) => option.id).toSet();
    _selectedEmailIds = emailOptions.map((option) => option.id).toSet();
    if (notify) {
      notifyListeners();
    }
  }

  static bool _setSelection(Set<String> target, String id, bool selected) {
    return selected ? target.add(id) : target.remove(id);
  }

  static Set<String> _optionIdsForSource(
    List<MergeValueOption> options,
    String nativeId,
  ) {
    return options
        .where((option) => option.sourceContactIds.contains(nativeId))
        .map((option) => option.id)
        .toSet();
  }

  static ScannedContact _recommendedMaster(List<ScannedContact> contacts) {
    var selected = contacts.first;
    var selectedScore = _completenessScore(selected);

    for (final contact in contacts.skip(1)) {
      final score = _completenessScore(contact);
      if (score > selectedScore) {
        selected = contact;
        selectedScore = score;
      }
    }
    return selected;
  }

  static int _completenessScore(ScannedContact contact) {
    return (contact.displayName.trim().isEmpty ? 0 : 4) +
        contact.phones.length * 2 +
        contact.emails.length * 2;
  }

  static List<MergeValueOption> _buildOptions(
    List<ScannedContact> contacts,
    MergeValueType type,
    List<String> Function(ScannedContact contact) valuesFor,
  ) {
    final options = <String, _MutableMergeOption>{};

    for (final contact in contacts) {
      for (final rawValue in valuesFor(contact)) {
        final value = rawValue.trim();
        if (value.isEmpty) {
          continue;
        }
        final key = _canonicalKey(type, value);
        final existing = options[key];
        if (existing == null) {
          options[key] = _MutableMergeOption(
            value: value,
            sourceContactIds: <String>[contact.nativeId],
          );
        } else {
          if (!existing.sourceContactIds.contains(contact.nativeId)) {
            existing.sourceContactIds.add(contact.nativeId);
          }
          if (value.length > existing.value.length) {
            existing.value = value;
          }
        }
      }
    }

    return options.entries.map((entry) {
      return MergeValueOption(
        id: '${type.name}:${entry.key}',
        value: entry.value.value,
        type: type,
        sourceContactIds: List<String>.unmodifiable(
          entry.value.sourceContactIds,
        ),
      );
    }).toList(growable: false);
  }

  static String _canonicalKey(MergeValueType type, String value) {
    if (type == MergeValueType.email) {
      return value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    }

    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }
    if (digits.length == 10 && digits.startsWith('0')) {
      digits = '40${digits.substring(1)}';
    }
    return digits.isEmpty ? value.toLowerCase() : digits;
  }
}

class _MutableMergeOption {
  String value;
  final List<String> sourceContactIds;

  _MutableMergeOption({
    required this.value,
    required this.sourceContactIds,
  });
}
