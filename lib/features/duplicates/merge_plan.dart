import '../../core/contacts/contact_models.dart';
import '../../core/contacts/contacts_scan_service.dart';

enum MergeFieldKind {
  displayName,
  givenName,
  middleName,
  familyName,
  prefix,
  suffix,
  phone,
  email,
  address,
  company,
  department,
  jobTitle,
  birthday,
  note,
  photo,
  favorite,
}

enum MergeConflictType {
  scalarMismatch,
  multipleBirthdays,
  multiplePhotos,
  readOnlySource,
  unstableSource,
  unsupportedField,
}

enum MergeSkipReason {
  unselected,
  duplicateValue,
  invalidValue,
  readOnly,
  unsupported,
  conflict,
  unavailable,
}

enum MergePlanValidationCode {
  valid,
  missingOperationId,
  missingGroupId,
  invalidScanRevision,
  missingGroupFingerprint,
  missingSnapshotFingerprint,
  invalidBackupId,
  missingMaster,
  masterNotInSources,
  unstableSource,
  sourceSetMismatch,
  noUsefulFields,
  emptyName,
  invalidSelectedField,
  duplicateSelectedField,
  invalidProvenance,
  invalidConflict,
  unresolvedConflict,
  staleGroupFingerprint,
  overlappingGroup,
  sourceCountInvalid,
}

class MergeSelectedField {
  final String optionId;
  final MergeFieldKind kind;
  final String displayValue;
  final String canonicalValue;
  final List<String> sourceContactIds;

  MergeSelectedField({
    required this.optionId,
    required this.kind,
    required this.displayValue,
    required this.canonicalValue,
    required Iterable<String> sourceContactIds,
  }) : sourceContactIds = List<String>.unmodifiable(
          sourceContactIds
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort(),
        );

  bool get hasIdentity => optionId.trim().isNotEmpty;
  bool get hasValue => displayValue.trim().isNotEmpty;
  bool get hasCanonicalValue =>
      kind == MergeFieldKind.note ||
      kind == MergeFieldKind.photo ||
      canonicalValue.trim().isNotEmpty;
  bool get hasProvenance => sourceContactIds.isNotEmpty;

  String get identityFingerprint => stableOpaqueId(
        <String>[
          kind.name,
          canonicalValue.trim(),
          ...sourceContactIds,
        ],
        namespace: 'merge-field',
      );
}

class MergeConflict {
  final String conflictId;
  final MergeFieldKind field;
  final MergeConflictType type;
  final List<String> optionIds;
  final bool required;
  final String? selectedOptionId;

  MergeConflict({
    required this.conflictId,
    required this.field,
    required this.type,
    required Iterable<String> optionIds,
    required this.required,
    this.selectedOptionId,
  }) : optionIds = List<String>.unmodifiable(
          optionIds
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort(),
        );

  bool get resolved =>
      !required ||
      (selectedOptionId != null && optionIds.contains(selectedOptionId));

  bool get structurallyValid =>
      conflictId.trim().isNotEmpty &&
      optionIds.length >= 2 &&
      (selectedOptionId == null || optionIds.contains(selectedOptionId));

  MergeConflict select(String optionId) {
    final normalized = optionId.trim();
    if (!optionIds.contains(normalized)) return this;
    return MergeConflict(
      conflictId: conflictId,
      field: field,
      type: type,
      optionIds: optionIds,
      required: required,
      selectedOptionId: normalized,
    );
  }
}

class MergeSkippedField {
  final MergeFieldKind kind;
  final String valueFingerprint;
  final MergeSkipReason reason;
  final String? sourceContactId;

  const MergeSkippedField({
    required this.kind,
    required this.valueFingerprint,
    required this.reason,
    this.sourceContactId,
  });
}

class MergePlanCounters {
  final int sourceContacts;
  final int writableSources;
  final int readOnlySources;
  final int unknownCapabilitySources;
  final int selectedFields;
  final int conflicts;
  final int unresolvedConflicts;
  final int skippedFields;

  const MergePlanCounters({
    required this.sourceContacts,
    required this.writableSources,
    required this.readOnlySources,
    required this.unknownCapabilitySources,
    required this.selectedFields,
    required this.conflicts,
    required this.unresolvedConflicts,
    required this.skippedFields,
  });
}

class MergePlan {
  final String operationId;
  final String groupId;
  final int scanRevision;
  final String groupRevisionFingerprint;
  final String backupId;
  final String masterContactId;
  final List<String> sourceContactIds;
  final List<MergeSelectedField> selectedFields;
  final List<MergeConflict> conflicts;
  final List<MergeSkippedField> skippedFields;
  final String sourceSnapshotFingerprint;
  final bool overlapsAnotherGroup;
  final DateTime createdAt;

  MergePlan({
    required this.operationId,
    required this.groupId,
    required this.scanRevision,
    required this.groupRevisionFingerprint,
    required this.backupId,
    required this.masterContactId,
    required Iterable<String> sourceContactIds,
    required Iterable<MergeSelectedField> selectedFields,
    Iterable<MergeConflict> conflicts = const <MergeConflict>[],
    Iterable<MergeSkippedField> skippedFields = const <MergeSkippedField>[],
    required this.sourceSnapshotFingerprint,
    this.overlapsAnotherGroup = false,
    required this.createdAt,
  })  : sourceContactIds = List<String>.unmodifiable(
          sourceContactIds
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort(),
        ),
        selectedFields = List<MergeSelectedField>.unmodifiable(selectedFields),
        conflicts = List<MergeConflict>.unmodifiable(conflicts),
        skippedFields = List<MergeSkippedField>.unmodifiable(skippedFields);

  bool get hasUnresolvedConflicts =>
      conflicts.any((conflict) => !conflict.resolved);
  bool get hasUsefulFields =>
      selectedFields.any((field) => _isUsefulField(field.kind));
  bool get hasName => selectedFields.any(
        (field) =>
            field.kind == MergeFieldKind.displayName &&
            field.displayValue.trim().isNotEmpty,
      );
  bool get hasStableOperationIdentity =>
      operationId.trim().isNotEmpty &&
      groupId.trim().isNotEmpty &&
      groupRevisionFingerprint.trim().isNotEmpty &&
      sourceSnapshotFingerprint.trim().isNotEmpty &&
      backupId.trim().isNotEmpty;

  String get fingerprint => stableOpaqueId(
        <String>[
          operationId,
          groupId,
          '$scanRevision',
          groupRevisionFingerprint,
          backupId,
          masterContactId,
          sourceSnapshotFingerprint,
          ...sourceContactIds,
          ...selectedFields.map((field) => field.identityFingerprint),
          ...conflicts.map(
            (conflict) =>
                '${conflict.conflictId}:${conflict.selectedOptionId ?? ''}',
          ),
        ],
        namespace: 'merge-plan',
      );

  MergePlanCounters counters(Map<String, ContactRecord> sourceRecords) {
    var writable = 0;
    var readOnly = 0;
    var unknown = 0;
    for (final id in sourceContactIds) {
      final record = sourceRecords[id];
      if (record == null) {
        unknown++;
      } else if (record.capabilities.isFullyWritable) {
        writable++;
      } else if (record.capabilities.isKnownReadOnly) {
        readOnly++;
      } else {
        unknown++;
      }
    }
    return MergePlanCounters(
      sourceContacts: sourceContactIds.length,
      writableSources: writable,
      readOnlySources: readOnly,
      unknownCapabilitySources: unknown,
      selectedFields: selectedFields.length,
      conflicts: conflicts.length,
      unresolvedConflicts:
          conflicts.where((conflict) => !conflict.resolved).length,
      skippedFields: skippedFields.length,
    );
  }

  MergePlan resolveConflict(String conflictId, String optionId) {
    final normalizedConflictId = conflictId.trim();
    final updated = conflicts.map(
      (conflict) => conflict.conflictId == normalizedConflictId
          ? conflict.select(optionId)
          : conflict,
    );
    return copyWith(conflicts: updated);
  }

  MergePlan copyWith({
    String? masterContactId,
    Iterable<MergeSelectedField>? selectedFields,
    Iterable<MergeConflict>? conflicts,
    Iterable<MergeSkippedField>? skippedFields,
  }) {
    return MergePlan(
      operationId: operationId,
      groupId: groupId,
      scanRevision: scanRevision,
      groupRevisionFingerprint: groupRevisionFingerprint,
      backupId: backupId,
      masterContactId: masterContactId ?? this.masterContactId,
      sourceContactIds: sourceContactIds,
      selectedFields: selectedFields ?? this.selectedFields,
      conflicts: conflicts ?? this.conflicts,
      skippedFields: skippedFields ?? this.skippedFields,
      sourceSnapshotFingerprint: sourceSnapshotFingerprint,
      overlapsAnotherGroup: overlapsAnotherGroup,
      createdAt: createdAt,
    );
  }

  static bool _isUsefulField(MergeFieldKind kind) {
    return switch (kind) {
      MergeFieldKind.phone ||
      MergeFieldKind.email ||
      MergeFieldKind.address ||
      MergeFieldKind.company ||
      MergeFieldKind.department ||
      MergeFieldKind.jobTitle ||
      MergeFieldKind.birthday ||
      MergeFieldKind.note ||
      MergeFieldKind.photo ||
      MergeFieldKind.favorite => true,
      _ => false,
    };
  }
}

class MergePlanValidation {
  final MergePlanValidationCode code;
  final String? detailCode;

  const MergePlanValidation(this.code, {this.detailCode});

  bool get isValid => code == MergePlanValidationCode.valid;
}

class MergePlanValidator {
  const MergePlanValidator();

  MergePlanValidation validate(
    MergePlan plan, {
    required Map<String, ContactRecord> sourceRecords,
    String? expectedGroupFingerprint,
  }) {
    if (plan.operationId.trim().isEmpty) {
      return const MergePlanValidation(
        MergePlanValidationCode.missingOperationId,
      );
    }
    if (plan.groupId.trim().isEmpty) {
      return const MergePlanValidation(MergePlanValidationCode.missingGroupId);
    }
    if (plan.scanRevision < 0) {
      return const MergePlanValidation(
        MergePlanValidationCode.invalidScanRevision,
      );
    }
    if (plan.groupRevisionFingerprint.trim().isEmpty) {
      return const MergePlanValidation(
        MergePlanValidationCode.missingGroupFingerprint,
      );
    }
    if (plan.sourceSnapshotFingerprint.trim().isEmpty) {
      return const MergePlanValidation(
        MergePlanValidationCode.missingSnapshotFingerprint,
      );
    }
    if (!RegExp(r'^\d+$').hasMatch(plan.backupId.trim())) {
      return const MergePlanValidation(MergePlanValidationCode.invalidBackupId);
    }
    if (plan.sourceContactIds.length < 2) {
      return const MergePlanValidation(
        MergePlanValidationCode.sourceCountInvalid,
      );
    }
    if (plan.masterContactId.trim().isEmpty) {
      return const MergePlanValidation(MergePlanValidationCode.missingMaster);
    }
    if (!plan.sourceContactIds.contains(plan.masterContactId)) {
      return const MergePlanValidation(
        MergePlanValidationCode.masterNotInSources,
      );
    }
    if (plan.overlapsAnotherGroup) {
      return const MergePlanValidation(
        MergePlanValidationCode.overlappingGroup,
      );
    }
    if (expectedGroupFingerprint != null &&
        expectedGroupFingerprint != plan.groupRevisionFingerprint) {
      return const MergePlanValidation(
        MergePlanValidationCode.staleGroupFingerprint,
      );
    }

    final expectedSourceIds = sourceRecords.keys
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (!setEqualsStrings(expectedSourceIds, plan.sourceContactIds.toSet())) {
      return const MergePlanValidation(
        MergePlanValidationCode.sourceSetMismatch,
      );
    }

    for (final id in plan.sourceContactIds) {
      final record = sourceRecords[id];
      if (record == null || !record.hasStableNativeId) {
        return MergePlanValidation(
          MergePlanValidationCode.unstableSource,
          detailCode: id,
        );
      }
    }

    if (!plan.hasName) {
      return const MergePlanValidation(MergePlanValidationCode.emptyName);
    }
    if (!plan.hasUsefulFields) {
      return const MergePlanValidation(MergePlanValidationCode.noUsefulFields);
    }

    final optionIds = <String>{};
    for (final field in plan.selectedFields) {
      if (!field.hasIdentity ||
          !field.hasValue ||
          !field.hasCanonicalValue ||
          !field.hasProvenance) {
        return MergePlanValidation(
          MergePlanValidationCode.invalidSelectedField,
          detailCode: field.optionId,
        );
      }
      if (!optionIds.add(field.optionId)) {
        return MergePlanValidation(
          MergePlanValidationCode.duplicateSelectedField,
          detailCode: field.optionId,
        );
      }
      if (field.sourceContactIds.any(
        (id) => !plan.sourceContactIds.contains(id),
      )) {
        return MergePlanValidation(
          MergePlanValidationCode.invalidProvenance,
          detailCode: field.optionId,
        );
      }
    }

    final conflictIds = <String>{};
    for (final conflict in plan.conflicts) {
      if (!conflict.structurallyValid ||
          !conflictIds.add(conflict.conflictId) ||
          conflict.optionIds.any((id) => !optionIds.contains(id))) {
        return MergePlanValidation(
          MergePlanValidationCode.invalidConflict,
          detailCode: conflict.conflictId,
        );
      }
    }
    if (plan.hasUnresolvedConflicts) {
      return const MergePlanValidation(
        MergePlanValidationCode.unresolvedConflict,
      );
    }

    return const MergePlanValidation(MergePlanValidationCode.valid);
  }
}

class MergePlanFactory {
  const MergePlanFactory();

  MergePlan fromGroup({
    required DuplicateContactGroup group,
    required int scanRevision,
    required String backupId,
    required String operationId,
    required String masterContactId,
    required Iterable<MergeSelectedField> selectedFields,
    Iterable<MergeConflict> conflicts = const <MergeConflict>[],
    Iterable<MergeSkippedField> skippedFields = const <MergeSkippedField>[],
    required DateTime createdAt,
  }) {
    final sourceIds = group.contacts.map((contact) => contact.nativeId).toList()
      ..sort();
    final snapshotParts = group.contacts.map(
      (contact) => contact.record?.revision.fingerprint ?? contact.nativeId,
    );
    return MergePlan(
      operationId: operationId.trim(),
      groupId: group.id.trim(),
      scanRevision: scanRevision,
      groupRevisionFingerprint: group.revisionFingerprint,
      backupId: backupId.trim(),
      masterContactId: masterContactId.trim(),
      sourceContactIds: sourceIds,
      selectedFields: selectedFields,
      conflicts: conflicts,
      skippedFields: skippedFields,
      sourceSnapshotFingerprint: stableOpaqueId(
        snapshotParts,
        namespace: 'merge-snapshot',
      ),
      overlapsAnotherGroup: group.overlapsAnotherGroup,
      createdAt: createdAt.toUtc(),
    );
  }
}

bool setEqualsStrings(Set<String> left, Set<String> right) {
  if (left.length != right.length) return false;
  return left.containsAll(right);
}
