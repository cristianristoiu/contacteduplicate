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
  conflictAlternative,
  unavailable,
}

enum MergeExecutionMode { copyOnly, destructive }

enum MergeSafetyCapability { writable, readOnly, mixed, unknown }

enum MergeSafetyBlockerType {
  manualReviewRequired,
  unstableSource,
  unknownCapability,
  readOnlyDeleteTarget,
  unsupportedSelectedField,
  unresolvedConflict,
  staleSnapshot,
  staleGroup,
  expiredPlan,
  missingDeleteTarget,
}

enum MergePlanValidationCode {
  valid,
  missingOperationId,
  invalidOperationId,
  missingGroupId,
  invalidGroupId,
  invalidScanRevision,
  missingGroupFingerprint,
  missingSnapshotFingerprint,
  staleSnapshotFingerprint,
  invalidBackupId,
  missingMaster,
  masterNotInSources,
  unstableMaster,
  unstableSource,
  duplicateSourceId,
  sourceSetMismatch,
  noUsefulFields,
  emptyName,
  displayNameCardinalityInvalid,
  invalidSelectedField,
  oversizedSelectedField,
  duplicateSelectedField,
  duplicateCanonicalField,
  invalidProvenance,
  duplicateProvenance,
  provenanceTooLarge,
  invalidConflict,
  conflictFieldMismatch,
  unresolvedConflict,
  staleGroupFingerprint,
  overlappingGroup,
  sourceCountInvalid,
  createdAtInFuture,
  planExpired,
  destructiveContextMissing,
  manualReviewNotAcknowledged,
  unknownCapability,
  invalidDeleteTarget,
  readOnlyDeleteTarget,
  noDeleteTargets,
  sourcePartitionInvalid,
  unsupportedSelectedField,
}

class MergeSelectedField {
  static const int maxDisplayValueLength = 1024;
  static const int maxCanonicalValueLength = 512;

  final String optionId;
  final MergeFieldKind kind;
  final String displayValue;
  final String canonicalValue;
  final List<String> sourceContactIds;
  final Map<String, String> metadata;
  final bool hadDuplicateProvenance;

  MergeSelectedField({
    required this.optionId,
    required this.kind,
    required this.displayValue,
    required this.canonicalValue,
    required Iterable<String> sourceContactIds,
    Map<String, String> metadata = const <String, String>{},
  })  : hadDuplicateProvenance = _normalizedList(sourceContactIds).length !=
            _normalizedList(sourceContactIds).toSet().length,
        sourceContactIds = List<String>.unmodifiable(
          _normalizedList(sourceContactIds).toSet().toList()..sort(),
        ),
        metadata = Map<String, String>.unmodifiable(
          Map<String, String>.fromEntries(
            metadata.entries
                .map(
                  (entry) => MapEntry<String, String>(
                    entry.key.trim(),
                    entry.value.trim(),
                  ),
                )
                .where(
                  (entry) => entry.key.isNotEmpty && entry.value.isNotEmpty,
                ),
          ),
        );

  bool get hasIdentity => optionId.trim().isNotEmpty;
  bool get hasValue => displayValue.trim().isNotEmpty;
  bool get isPayloadBounded =>
      displayValue.length <= maxDisplayValueLength &&
      canonicalValue.length <= maxCanonicalValueLength &&
      metadata.entries.every(
        (entry) => entry.key.length <= 64 && entry.value.length <= 512,
      );
  bool get hasCanonicalValue => switch (kind) {
        MergeFieldKind.note || MergeFieldKind.photo => true,
        MergeFieldKind.favorite =>
          canonicalValue == 'true' || canonicalValue == 'false',
        _ => canonicalValue.trim().isNotEmpty,
      };
  bool get hasProvenance => sourceContactIds.isNotEmpty;

  String get metadataFingerprint => stableOpaqueId(
        metadata.entries.map((entry) => '${entry.key}=${entry.value}'),
        namespace: 'merge-field-meta',
      );

  String get identityFingerprint => stableOpaqueId(
        <String>[
          kind.name,
          canonicalValue.trim(),
          metadataFingerprint,
          ...sourceContactIds,
        ],
        namespace: 'merge-field',
      );

  static List<String> _normalizedList(Iterable<String> values) => values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
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

  String get identityFingerprint => stableOpaqueId(
        <String>[
          kind.name,
          valueFingerprint,
          reason.name,
          sourceContactId ?? '',
        ],
        namespace: 'merge-skip',
      );
}

class MergeSafetyBlocker {
  final MergeSafetyBlockerType type;
  final String? detailCode;

  const MergeSafetyBlocker(this.type, {this.detailCode});
}

class MergePlanCounters {
  final int sourceContacts;
  final int writableSources;
  final int readOnlySources;
  final int unknownCapabilitySources;
  final int deletionTargets;
  final int retainedSources;
  final int selectedFields;
  final int conflicts;
  final int unresolvedConflicts;
  final int skippedFields;
  final int unsupportedFields;

  const MergePlanCounters({
    required this.sourceContacts,
    required this.writableSources,
    required this.readOnlySources,
    required this.unknownCapabilitySources,
    required this.deletionTargets,
    required this.retainedSources,
    required this.selectedFields,
    required this.conflicts,
    required this.unresolvedConflicts,
    required this.skippedFields,
    required this.unsupportedFields,
  });
}

class MergePlan {
  static const int maxOperationIdLength = 96;

  final String operationId;
  final String groupId;
  final int scanRevision;
  final String groupRevisionFingerprint;
  final String backupId;
  final String masterContactId;
  final List<String> sourceContactIds;
  final List<String> deletionTargetIds;
  final List<String> retainedSourceIds;
  final List<MergeSelectedField> selectedFields;
  final List<MergeConflict> conflicts;
  final List<MergeSkippedField> skippedFields;
  final Set<MergeFieldKind> unsupportedFieldKinds;
  final String sourceSnapshotFingerprint;
  final bool overlapsAnotherGroup;
  final bool requiresManualReview;
  final bool manualReviewAcknowledged;
  final MergeExecutionMode executionMode;
  final MergeSafetyCapability safetyCapability;
  final DateTime createdAt;
  final bool hadDuplicateSourceIds;

  MergePlan({
    required this.operationId,
    required this.groupId,
    required this.scanRevision,
    required this.groupRevisionFingerprint,
    required this.backupId,
    required this.masterContactId,
    required Iterable<String> sourceContactIds,
    Iterable<String> deletionTargetIds = const <String>[],
    Iterable<String> retainedSourceIds = const <String>[],
    required Iterable<MergeSelectedField> selectedFields,
    Iterable<MergeConflict> conflicts = const <MergeConflict>[],
    Iterable<MergeSkippedField> skippedFields = const <MergeSkippedField>[],
    Iterable<MergeFieldKind> unsupportedFieldKinds = const <MergeFieldKind>[],
    required this.sourceSnapshotFingerprint,
    this.overlapsAnotherGroup = false,
    this.requiresManualReview = false,
    this.manualReviewAcknowledged = false,
    this.executionMode = MergeExecutionMode.copyOnly,
    this.safetyCapability = MergeSafetyCapability.unknown,
    required this.createdAt,
  })  : hadDuplicateSourceIds = _normalizedIds(sourceContactIds).length !=
            _normalizedIds(sourceContactIds).toSet().length,
        sourceContactIds = List<String>.unmodifiable(
          _normalizedIds(sourceContactIds).toSet().toList()..sort(),
        ),
        deletionTargetIds = List<String>.unmodifiable(
          _normalizedIds(deletionTargetIds).toSet().toList()..sort(),
        ),
        retainedSourceIds = List<String>.unmodifiable(
          _normalizedIds(retainedSourceIds).toSet().toList()..sort(),
        ),
        selectedFields = List<MergeSelectedField>.unmodifiable(
          selectedFields.toList()
            ..sort((left, right) {
              final kindCompare = left.kind.index.compareTo(right.kind.index);
              if (kindCompare != 0) return kindCompare;
              final canonicalCompare =
                  left.canonicalValue.compareTo(right.canonicalValue);
              if (canonicalCompare != 0) return canonicalCompare;
              return left.optionId.compareTo(right.optionId);
            }),
        ),
        conflicts = List<MergeConflict>.unmodifiable(
          conflicts.toList()
            ..sort((left, right) => left.conflictId.compareTo(right.conflictId)),
        ),
        skippedFields = List<MergeSkippedField>.unmodifiable(
          skippedFields.toList()
            ..sort((left, right) =>
                left.identityFingerprint.compareTo(right.identityFingerprint)),
        ),
        unsupportedFieldKinds =
            Set<MergeFieldKind>.unmodifiable(unsupportedFieldKinds.toSet());

  bool get hasUnresolvedConflicts =>
      conflicts.any((conflict) => !conflict.resolved);
  bool get hasUsefulFields =>
      selectedFields.any((field) => _isUsefulField(field.kind));
  int get displayNameFieldCount => selectedFields
      .where(
        (field) =>
            field.kind == MergeFieldKind.displayName &&
            field.displayValue.trim().isNotEmpty,
      )
      .length;
  bool get hasName => displayNameFieldCount == 1;
  bool get isDestructive => executionMode == MergeExecutionMode.destructive;
  bool get hasStableOperationIdentity =>
      _isValidOperationId(operationId) &&
      _isValidGroupId(groupId) &&
      groupRevisionFingerprint.trim().isNotEmpty &&
      sourceSnapshotFingerprint.trim().isNotEmpty &&
      _isValidBackupId(backupId);

  List<MergeSafetyBlocker> get safetyBlockers {
    final blockers = <MergeSafetyBlocker>[
      if (requiresManualReview && !manualReviewAcknowledged)
        const MergeSafetyBlocker(
          MergeSafetyBlockerType.manualReviewRequired,
        ),
      if (hasUnresolvedConflicts)
        const MergeSafetyBlocker(MergeSafetyBlockerType.unresolvedConflict),
      if (unsupportedFieldKinds.isNotEmpty)
        MergeSafetyBlocker(
          MergeSafetyBlockerType.unsupportedSelectedField,
          detailCode: unsupportedFieldKinds.map((kind) => kind.name).join(','),
        ),
      if (isDestructive && safetyCapability == MergeSafetyCapability.unknown)
        const MergeSafetyBlocker(MergeSafetyBlockerType.unknownCapability),
      if (isDestructive && deletionTargetIds.isEmpty)
        const MergeSafetyBlocker(MergeSafetyBlockerType.missingDeleteTarget),
    ];
    return List<MergeSafetyBlocker>.unmodifiable(blockers);
  }

  String get fingerprint => stableOpaqueId(
        <String>[
          operationId,
          groupId,
          '$scanRevision',
          groupRevisionFingerprint,
          backupId,
          masterContactId,
          sourceSnapshotFingerprint,
          executionMode.name,
          safetyCapability.name,
          requiresManualReview ? 'manual' : 'normal',
          manualReviewAcknowledged ? 'ack' : 'pending',
          ...sourceContactIds,
          ...deletionTargetIds.map((id) => 'delete:$id'),
          ...retainedSourceIds.map((id) => 'retain:$id'),
          ...selectedFields.map((field) => field.identityFingerprint),
          ...conflicts.map(
            (conflict) =>
                '${conflict.conflictId}:${conflict.selectedOptionId ?? ''}',
          ),
          ...skippedFields.map((field) => field.identityFingerprint),
          ...unsupportedFieldKinds.map((kind) => 'unsupported:${kind.name}'),
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
      deletionTargets: deletionTargetIds.length,
      retainedSources: retainedSourceIds.length,
      selectedFields: selectedFields.length,
      conflicts: conflicts.length,
      unresolvedConflicts:
          conflicts.where((conflict) => !conflict.resolved).length,
      skippedFields: skippedFields.length,
      unsupportedFields: unsupportedFieldKinds.length,
    );
  }

  bool matchesContext({
    required int currentScanRevision,
    required String currentGroupFingerprint,
    required Map<String, ContactRecord> currentSourceRecords,
  }) {
    if (scanRevision != currentScanRevision) return false;
    if (groupRevisionFingerprint != currentGroupFingerprint) return false;
    if (!setEqualsStrings(
      sourceContactIds.toSet(),
      currentSourceRecords.keys.map((id) => id.trim()).toSet(),
    )) {
      return false;
    }
    return sourceSnapshotFingerprint ==
        MergePlanFactory.sourceSnapshotFingerprint(currentSourceRecords);
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

  MergePlan acknowledgeManualReview() {
    if (!requiresManualReview || manualReviewAcknowledged) return this;
    return copyWith(manualReviewAcknowledged: true);
  }

  MergePlan copyWith({
    String? masterContactId,
    Iterable<String>? deletionTargetIds,
    Iterable<String>? retainedSourceIds,
    Iterable<MergeSelectedField>? selectedFields,
    Iterable<MergeConflict>? conflicts,
    Iterable<MergeSkippedField>? skippedFields,
    Iterable<MergeFieldKind>? unsupportedFieldKinds,
    MergeExecutionMode? executionMode,
    MergeSafetyCapability? safetyCapability,
    bool? manualReviewAcknowledged,
  }) {
    return MergePlan(
      operationId: operationId,
      groupId: groupId,
      scanRevision: scanRevision,
      groupRevisionFingerprint: groupRevisionFingerprint,
      backupId: backupId,
      masterContactId: masterContactId ?? this.masterContactId,
      sourceContactIds: sourceContactIds,
      deletionTargetIds: deletionTargetIds ?? this.deletionTargetIds,
      retainedSourceIds: retainedSourceIds ?? this.retainedSourceIds,
      selectedFields: selectedFields ?? this.selectedFields,
      conflicts: conflicts ?? this.conflicts,
      skippedFields: skippedFields ?? this.skippedFields,
      unsupportedFieldKinds:
          unsupportedFieldKinds ?? this.unsupportedFieldKinds,
      sourceSnapshotFingerprint: sourceSnapshotFingerprint,
      overlapsAnotherGroup: overlapsAnotherGroup,
      requiresManualReview: requiresManualReview,
      manualReviewAcknowledged:
          manualReviewAcknowledged ?? this.manualReviewAcknowledged,
      executionMode: executionMode ?? this.executionMode,
      safetyCapability: safetyCapability ?? this.safetyCapability,
      createdAt: createdAt,
    );
  }

  static List<String> _normalizedIds(Iterable<String> values) => values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

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

  static bool _isValidOperationId(String value) {
    final trimmed = value.trim();
    return trimmed.length >= 8 &&
        trimmed.length <= maxOperationIdLength &&
        RegExp(r'^[a-z][a-z0-9_-]+$').hasMatch(trimmed);
  }

  static bool _isValidGroupId(String value) =>
      RegExp(r'^group-[a-f0-9]{16,64}$').hasMatch(value.trim());

  static bool _isValidBackupId(String value) {
    final parsed = int.tryParse(value.trim());
    return parsed != null && parsed > 0;
  }
}

class MergePlanValidation {
  final MergePlanValidationCode code;
  final String? detailCode;

  const MergePlanValidation(this.code, {this.detailCode});

  bool get isValid => code == MergePlanValidationCode.valid;
}

class MergePlanValidator {
  final Duration maxPlanAge;
  final Duration allowedClockSkew;

  const MergePlanValidator({
    this.maxPlanAge = const Duration(minutes: 5),
    this.allowedClockSkew = const Duration(seconds: 30),
  });

  MergePlanValidation validate(
    MergePlan plan, {
    required Map<String, ContactRecord> sourceRecords,
    String? expectedGroupFingerprint,
    DateTime? now,
  }) {
    final currentTime = (now ?? DateTime.now()).toUtc();
    if (plan.operationId.trim().isEmpty) {
      return const MergePlanValidation(
        MergePlanValidationCode.missingOperationId,
      );
    }
    if (!MergePlan._isValidOperationId(plan.operationId)) {
      return const MergePlanValidation(
        MergePlanValidationCode.invalidOperationId,
      );
    }
    if (plan.groupId.trim().isEmpty) {
      return const MergePlanValidation(MergePlanValidationCode.missingGroupId);
    }
    if (!MergePlan._isValidGroupId(plan.groupId)) {
      return const MergePlanValidation(MergePlanValidationCode.invalidGroupId);
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
    if (!MergePlan._isValidBackupId(plan.backupId)) {
      return const MergePlanValidation(MergePlanValidationCode.invalidBackupId);
    }
    if (plan.hadDuplicateSourceIds) {
      return const MergePlanValidation(
        MergePlanValidationCode.duplicateSourceId,
      );
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
    if (expectedGroupFingerprint == null && plan.isDestructive) {
      return const MergePlanValidation(
        MergePlanValidationCode.destructiveContextMissing,
      );
    }
    if (expectedGroupFingerprint != null &&
        expectedGroupFingerprint != plan.groupRevisionFingerprint) {
      return const MergePlanValidation(
        MergePlanValidationCode.staleGroupFingerprint,
      );
    }

    final createdAt = plan.createdAt.toUtc();
    if (createdAt.isAfter(currentTime.add(allowedClockSkew))) {
      return const MergePlanValidation(
        MergePlanValidationCode.createdAtInFuture,
      );
    }
    if (currentTime.difference(createdAt) > maxPlanAge) {
      return const MergePlanValidation(MergePlanValidationCode.planExpired);
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

    final liveSnapshot = MergePlanFactory.sourceSnapshotFingerprint(sourceRecords);
    if (liveSnapshot != plan.sourceSnapshotFingerprint) {
      return const MergePlanValidation(
        MergePlanValidationCode.staleSnapshotFingerprint,
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
    final master = sourceRecords[plan.masterContactId];
    if (master == null || !master.hasStableNativeId) {
      return const MergePlanValidation(
        MergePlanValidationCode.unstableMaster,
      );
    }

    if (plan.displayNameFieldCount != 1) {
      return const MergePlanValidation(
        MergePlanValidationCode.displayNameCardinalityInvalid,
      );
    }
    if (!plan.hasUsefulFields) {
      return const MergePlanValidation(MergePlanValidationCode.noUsefulFields);
    }

    final optionIds = <String>{};
    final canonicalKeys = <String>{};
    final fieldsByOptionId = <String, MergeSelectedField>{};
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
      if (!field.isPayloadBounded) {
        return MergePlanValidation(
          MergePlanValidationCode.oversizedSelectedField,
          detailCode: field.optionId,
        );
      }
      if (field.hadDuplicateProvenance) {
        return MergePlanValidation(
          MergePlanValidationCode.duplicateProvenance,
          detailCode: field.optionId,
        );
      }
      if (field.sourceContactIds.length > plan.sourceContactIds.length) {
        return MergePlanValidation(
          MergePlanValidationCode.provenanceTooLarge,
          detailCode: field.optionId,
        );
      }
      if (!optionIds.add(field.optionId)) {
        return MergePlanValidation(
          MergePlanValidationCode.duplicateSelectedField,
          detailCode: field.optionId,
        );
      }
      final canonicalIdentity = '${field.kind.name}:${field.canonicalValue}';
      if (!canonicalKeys.add(canonicalIdentity)) {
        return MergePlanValidation(
          MergePlanValidationCode.duplicateCanonicalField,
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
      fieldsByOptionId[field.optionId] = field;
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
      if (conflict.optionIds.any(
        (id) => fieldsByOptionId[id]?.kind != conflict.field,
      )) {
        return MergePlanValidation(
          MergePlanValidationCode.conflictFieldMismatch,
          detailCode: conflict.conflictId,
        );
      }
    }
    if (plan.hasUnresolvedConflicts) {
      return const MergePlanValidation(
        MergePlanValidationCode.unresolvedConflict,
      );
    }

    if (plan.requiresManualReview && !plan.manualReviewAcknowledged) {
      return const MergePlanValidation(
        MergePlanValidationCode.manualReviewNotAcknowledged,
      );
    }

    final deleteSet = plan.deletionTargetIds.toSet();
    final retainedSet = plan.retainedSourceIds.toSet();
    if (!plan.sourceContactIds.toSet().containsAll(deleteSet) ||
        !plan.sourceContactIds.toSet().containsAll(retainedSet) ||
        deleteSet.intersection(retainedSet).isNotEmpty ||
        !setEqualsStrings(
          plan.sourceContactIds.toSet(),
          <String>{...deleteSet, ...retainedSet},
        )) {
      return const MergePlanValidation(
        MergePlanValidationCode.sourcePartitionInvalid,
      );
    }

    if (plan.isDestructive) {
      if (plan.deletionTargetIds.isEmpty) {
        return const MergePlanValidation(
          MergePlanValidationCode.noDeleteTargets,
        );
      }
      if (plan.safetyCapability == MergeSafetyCapability.unknown ||
          plan.safetyCapability == MergeSafetyCapability.mixed) {
        return const MergePlanValidation(
          MergePlanValidationCode.unknownCapability,
        );
      }
      for (final id in plan.deletionTargetIds) {
        final record = sourceRecords[id];
        if (record == null) {
          return MergePlanValidation(
            MergePlanValidationCode.invalidDeleteTarget,
            detailCode: id,
          );
        }
        if (!record.capabilities.isFullyWritable) {
          return MergePlanValidation(
            MergePlanValidationCode.readOnlyDeleteTarget,
            detailCode: id,
          );
        }
      }
      if (plan.unsupportedFieldKinds.isNotEmpty) {
        return const MergePlanValidation(
          MergePlanValidationCode.unsupportedSelectedField,
        );
      }
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
    Iterable<MergeFieldKind> unsupportedFieldKinds = const <MergeFieldKind>[],
    bool manualReviewAcknowledged = false,
    DateTime? createdAt,
  }) {
    final sourceRecords = <String, ContactRecord>{
      for (final contact in group.contacts)
        if (contact.record != null) contact.nativeId: contact.record!,
    };
    final sourceIds = group.contacts.map((contact) => contact.nativeId).toList()
      ..sort();
    final deletionTargets = <String>[];
    final retained = <String>[];
    for (final contact in group.contacts) {
      final record = contact.record;
      if (record != null && record.capabilities.isFullyWritable) {
        deletionTargets.add(contact.nativeId);
      } else {
        retained.add(contact.nativeId);
      }
    }
    deletionTargets.sort();
    retained.sort();

    final capability = _aggregateCapability(group.contacts);
    final destructiveAllowed =
        group.canBeMerged &&
        !group.overlapsAnotherGroup &&
        deletionTargets.isNotEmpty &&
        capability == MergeSafetyCapability.writable;

    return MergePlan(
      operationId: operationId.trim(),
      groupId: group.id.trim(),
      scanRevision: scanRevision,
      groupRevisionFingerprint: group.revisionFingerprint,
      backupId: backupId.trim(),
      masterContactId: masterContactId.trim(),
      sourceContactIds: sourceIds,
      deletionTargetIds: destructiveAllowed ? deletionTargets : const <String>[],
      retainedSourceIds:
          destructiveAllowed ? retained : sourceIds,
      selectedFields: selectedFields,
      conflicts: conflicts,
      skippedFields: skippedFields,
      unsupportedFieldKinds: unsupportedFieldKinds,
      sourceSnapshotFingerprint: sourceSnapshotFingerprint(sourceRecords),
      overlapsAnotherGroup: group.overlapsAnotherGroup,
      requiresManualReview: group.requiresManualReview,
      manualReviewAcknowledged: manualReviewAcknowledged,
      executionMode: destructiveAllowed
          ? MergeExecutionMode.destructive
          : MergeExecutionMode.copyOnly,
      safetyCapability: capability,
      createdAt: (createdAt ?? DateTime.now()).toUtc(),
    );
  }

  static String sourceSnapshotFingerprint(
    Map<String, ContactRecord> records,
  ) {
    final parts = <String>[];
    final ids = records.keys.toList()..sort();
    for (final id in ids) {
      final record = records[id]!;
      parts.add(
        stableOpaqueId(
          <String>[
            id,
            record.revision.fingerprint,
            record.capabilities.update.name,
            record.capabilities.delete.name,
            record.hasStableNativeId ? 'stable' : 'unstable',
          ],
          namespace: 'merge-source',
        ),
      );
    }
    return stableOpaqueId(parts, namespace: 'merge-snapshot');
  }

  static String groupContextFingerprint(
    Iterable<String> sourceIds,
    String groupRevisionFingerprint,
  ) => stableOpaqueId(
        <String>[
          groupRevisionFingerprint,
          ...sourceIds.map((id) => id.trim()),
        ],
        namespace: 'merge-group-context',
      );

  static String generateOperationId({
    required String groupId,
    DateTime? clock,
  }) {
    final now = (clock ?? DateTime.now()).toUtc();
    final opaque = stableOpaqueId(
      <String>[
        groupId,
        '${now.microsecondsSinceEpoch}',
        '${now.hashCode}',
      ],
      namespace: 'merge-op',
    ).replaceFirst('merge-op-', '');
    return 'merge-${opaque.substring(0, opaque.length > 48 ? 48 : opaque.length)}';
  }

  static MergeSafetyCapability _aggregateCapability(
    Iterable<ScannedContact> contacts,
  ) {
    var writable = 0;
    var readOnly = 0;
    var unknown = 0;
    for (final contact in contacts) {
      final capabilities = contact.record?.capabilities;
      if (capabilities == null) {
        unknown++;
      } else if (capabilities.isFullyWritable) {
        writable++;
      } else if (capabilities.isKnownReadOnly) {
        readOnly++;
      } else {
        unknown++;
      }
    }
    if (unknown > 0) return MergeSafetyCapability.unknown;
    if (writable > 0 && readOnly > 0) return MergeSafetyCapability.mixed;
    if (writable > 0) return MergeSafetyCapability.writable;
    if (readOnly > 0) return MergeSafetyCapability.readOnly;
    return MergeSafetyCapability.unknown;
  }
}

bool setEqualsStrings(Set<String> left, Set<String> right) {
  if (left.length != right.length) return false;
  return left.containsAll(right);
}
