import '../../core/contacts/contact_data_normalizer.dart';
import '../../core/contacts/contact_models.dart';
import 'merge_plan.dart';

enum MergeSafetySeverity { info, warning, blocking, critical }

class StrictMergePlanValidator extends MergePlanValidator {
  static final RegExp _optionIdPattern =
      RegExp(r'^[a-z0-9][a-z0-9:_-]{0,127}$');
  static final RegExp _conflictIdPattern =
      RegExp(r'^[a-z0-9][a-z0-9:_-]{0,127}$');
  static final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final RegExp _fingerprintPattern =
      RegExp(r'^[a-z0-9][a-z0-9-]{0,63}-[a-f0-9]{32}$');

  const StrictMergePlanValidator({
    super.maxPlanAge = const Duration(minutes: 5),
    super.allowedClockSkew = const Duration(seconds: 30),
  });

  @override
  MergePlanValidation validate(
    MergePlan plan, {
    required Map<String, ContactRecord> sourceRecords,
    String? expectedGroupFingerprint,
    DateTime? now,
  }) {
    final base = super.validate(
      plan,
      sourceRecords: sourceRecords,
      expectedGroupFingerprint: expectedGroupFingerprint,
      now: now,
    );
    if (!base.isValid) return base;

    for (final validation in _strictValidations(
      plan,
      sourceRecords: sourceRecords,
      now: now,
    )) {
      if (!validation.isValid) return validation;
    }
    return const MergePlanValidation(MergePlanValidationCode.valid);
  }

  List<MergePlanValidation> validateAll(
    MergePlan plan, {
    required Map<String, ContactRecord> sourceRecords,
    String? expectedGroupFingerprint,
    DateTime? now,
  }) {
    final issues = <MergePlanValidation>[];
    final base = super.validate(
      plan,
      sourceRecords: sourceRecords,
      expectedGroupFingerprint: expectedGroupFingerprint,
      now: now,
    );
    if (!base.isValid) issues.add(base);
    issues.addAll(
      _strictValidations(
        plan,
        sourceRecords: sourceRecords,
        now: now,
      ).where((validation) => !validation.isValid),
    );
    final unique = <String, MergePlanValidation>{};
    for (final issue in issues) {
      unique.putIfAbsent(
        '${issue.code.name}:${issue.detailCode ?? ''}',
        () => issue,
      );
    }
    return List<MergePlanValidation>.unmodifiable(unique.values);
  }

  Iterable<MergePlanValidation> _strictValidations(
    MergePlan plan, {
    required Map<String, ContactRecord> sourceRecords,
    DateTime? now,
  }) sync* {
    final currentTime = (now ?? DateTime.now()).toUtc();
    if (plan.hasFutureClockSkew(
      currentTime,
      tolerance: allowedClockSkew,
    )) {
      yield const MergePlanValidation(
        MergePlanValidationCode.createdAtInFuture,
        detailCode: 'strict_clock_skew',
      );
    }
    if (plan.isExpiredAt(currentTime, maxAge: maxPlanAge)) {
      yield const MergePlanValidation(
        MergePlanValidationCode.planExpired,
        detailCode: 'strict_plan_expired',
      );
    }

    if (plan.manualReviewAcknowledged && !plan.requiresManualReview) {
      yield const MergePlanValidation(
        MergePlanValidationCode.invalidSelectedField,
        detailCode: 'manual_review_ack_without_requirement',
      );
    }

    if (plan.isDestructive) {
      if (plan.deletionTargetIds.contains(plan.masterContactId)) {
        yield const MergePlanValidation(
          MergePlanValidationCode.invalidDeleteTarget,
          detailCode: 'master_cannot_be_deleted',
        );
      }
      if (!plan.retainedSourceIds.contains(plan.masterContactId)) {
        yield const MergePlanValidation(
          MergePlanValidationCode.sourcePartitionInvalid,
          detailCode: 'master_must_be_retained',
        );
      }
    } else {
      if (plan.deletionTargetIds.isNotEmpty) {
        yield const MergePlanValidation(
          MergePlanValidationCode.sourcePartitionInvalid,
          detailCode: 'copy_only_has_delete_targets',
        );
      }
      if (!setEqualsStrings(
        plan.sourceContactIds.toSet(),
        plan.retainedSourceIds.toSet(),
      )) {
        yield const MergePlanValidation(
          MergePlanValidationCode.sourcePartitionInvalid,
          detailCode: 'copy_only_must_retain_all_sources',
        );
      }
    }

    final selectedKinds = plan.selectedFields.map((field) => field.kind).toSet();
    final unsupportedSelected =
        selectedKinds.intersection(plan.unsupportedFieldKinds);
    if (unsupportedSelected.isNotEmpty) {
      yield MergePlanValidation(
        MergePlanValidationCode.unsupportedSelectedField,
        detailCode: unsupportedSelected.map((kind) => kind.name).join(','),
      );
    }

    final selectedById = <String, MergeSelectedField>{};
    for (final field in plan.selectedFields) {
      if (!_optionIdPattern.hasMatch(field.optionId.trim())) {
        yield MergePlanValidation(
          MergePlanValidationCode.invalidSelectedField,
          detailCode: 'option_id:${field.optionId}',
        );
      }
      final semanticError = _validateField(field);
      if (semanticError != null) yield semanticError;
      selectedById[field.optionId] = field;
    }

    for (final conflict in plan.conflicts) {
      if (!_conflictIdPattern.hasMatch(conflict.conflictId.trim())) {
        yield MergePlanValidation(
          MergePlanValidationCode.invalidConflict,
          detailCode: 'conflict_id:${conflict.conflictId}',
        );
      }
      if (conflict.optionIds.any((id) => !selectedById.containsKey(id))) {
        yield MergePlanValidation(
          MergePlanValidationCode.invalidConflict,
          detailCode: 'conflict_option_missing:${conflict.conflictId}',
        );
      }
      final kinds = conflict.optionIds
          .map((id) => selectedById[id]?.kind)
          .whereType<MergeFieldKind>()
          .toSet();
      if (kinds.length != 1 ||
          (kinds.isNotEmpty && !kinds.contains(conflict.field))) {
        yield MergePlanValidation(
          MergePlanValidationCode.conflictFieldMismatch,
          detailCode: conflict.conflictId,
        );
      }
    }

    for (final skipped in plan.skippedFields) {
      final fingerprint = skipped.valueFingerprint.trim();
      if (fingerprint.isEmpty ||
          fingerprint.length > 128 ||
          !_fingerprintPattern.hasMatch(fingerprint)) {
        yield MergePlanValidation(
          MergePlanValidationCode.invalidSelectedField,
          detailCode: 'skip_fingerprint:${skipped.kind.name}',
        );
      }
      final source = skipped.sourceContactId?.trim();
      if (source != null &&
          source.isNotEmpty &&
          !plan.sourceContactIds.contains(source)) {
        yield MergePlanValidation(
          MergePlanValidationCode.invalidProvenance,
          detailCode: 'skip_source:$source',
        );
      }
    }

    for (final id in plan.sourceContactIds) {
      final record = sourceRecords[id];
      if (record == null) continue;
      if (!record.effectiveStableIdentity) {
        yield MergePlanValidation(
          MergePlanValidationCode.unstableSource,
          detailCode: id,
        );
      }
      if (record.contextFingerprint.trim().isEmpty ||
          record.contentFingerprint.trim().isEmpty) {
        yield MergePlanValidation(
          MergePlanValidationCode.staleSnapshotFingerprint,
          detailCode: 'incomplete_context:$id',
        );
      }
      if (plan.isDestructive &&
          plan.deletionTargetIds.contains(id) &&
          !record.capabilities.isFullyWritable) {
        yield MergePlanValidation(
          MergePlanValidationCode.readOnlyDeleteTarget,
          detailCode: id,
        );
      }
    }
  }

  MergePlanValidation? _validateField(MergeSelectedField field) {
    final metadataError = _validateMetadata(field);
    if (metadataError != null) return metadataError;

    final canonical = field.canonicalValue.trim();
    switch (field.kind) {
      case MergeFieldKind.phone:
        final normalized = ContactDataNormalizer().normalizePhone(
          field.displayValue,
        );
        if (normalized.isEmpty || normalized != canonical) {
          return MergePlanValidation(
            MergePlanValidationCode.invalidSelectedField,
            detailCode: 'phone_canonical:${field.optionId}',
          );
        }
      case MergeFieldKind.email:
        final normalized = ContactDataNormalizer().normalizeEmail(
          field.displayValue,
        );
        if (normalized.isEmpty || normalized != canonical) {
          return MergePlanValidation(
            MergePlanValidationCode.invalidSelectedField,
            detailCode: 'email_canonical:${field.optionId}',
          );
        }
      case MergeFieldKind.birthday:
        if (!_validDateOnly(canonical)) {
          return MergePlanValidation(
            MergePlanValidationCode.invalidSelectedField,
            detailCode: 'birthday_canonical:${field.optionId}',
          );
        }
      case MergeFieldKind.favorite:
        if (canonical != 'true' && canonical != 'false') {
          return MergePlanValidation(
            MergePlanValidationCode.invalidSelectedField,
            detailCode: 'favorite_canonical:${field.optionId}',
          );
        }
      case MergeFieldKind.address:
        if (canonical.isEmpty ||
            !_hasAnyMetadata(
              field.metadata,
              const <String>{
                'street',
                'city',
                'region',
                'postalCode',
                'country',
              },
            )) {
          return MergePlanValidation(
            MergePlanValidationCode.invalidSelectedField,
            detailCode: 'address_structure:${field.optionId}',
          );
        }
      case MergeFieldKind.company:
      case MergeFieldKind.department:
      case MergeFieldKind.jobTitle:
        if (canonical.isEmpty) {
          return MergePlanValidation(
            MergePlanValidationCode.invalidSelectedField,
            detailCode: 'organization_structure:${field.optionId}',
          );
        }
      case MergeFieldKind.note:
      case MergeFieldKind.photo:
        if (!_isOpaqueAvailabilityMarker(field.displayValue) ||
            field.metadata.values.any(_looksLikeRawSensitivePayload)) {
          return MergePlanValidation(
            MergePlanValidationCode.invalidSelectedField,
            detailCode: 'sensitive_raw_value:${field.optionId}',
          );
        }
      case MergeFieldKind.displayName:
      case MergeFieldKind.givenName:
      case MergeFieldKind.middleName:
      case MergeFieldKind.familyName:
      case MergeFieldKind.prefix:
      case MergeFieldKind.suffix:
        if (field.displayValue.trim().isEmpty || canonical.isEmpty) {
          return MergePlanValidation(
            MergePlanValidationCode.emptyName,
            detailCode: field.optionId,
          );
        }
    }
    return null;
  }

  MergePlanValidation? _validateMetadata(MergeSelectedField field) {
    final allowed = switch (field.kind) {
      MergeFieldKind.phone => const <String>{'label', 'extension'},
      MergeFieldKind.email => const <String>{'label'},
      MergeFieldKind.address => const <String>{
          'label',
          'street',
          'city',
          'region',
          'postalCode',
          'country',
        },
      MergeFieldKind.company ||
      MergeFieldKind.department ||
      MergeFieldKind.jobTitle => const <String>{
          'company',
          'department',
          'jobTitle',
        },
      MergeFieldKind.birthday => const <String>{'year', 'month', 'day'},
      MergeFieldKind.note || MergeFieldKind.photo => const <String>{
          'available',
        },
      _ => const <String>{},
    };
    final unknown = field.metadata.keys.where((key) => !allowed.contains(key));
    if (unknown.isNotEmpty) {
      return MergePlanValidation(
        MergePlanValidationCode.invalidSelectedField,
        detailCode: 'metadata_key:${field.optionId}:${unknown.first}',
      );
    }
    final extension = field.metadata['extension'];
    if (extension != null &&
        !RegExp(r'^[0-9]{1,8}$').hasMatch(extension)) {
      return MergePlanValidation(
        MergePlanValidationCode.invalidSelectedField,
        detailCode: 'phone_extension:${field.optionId}',
      );
    }
    if (field.kind == MergeFieldKind.birthday && field.metadata.isNotEmpty) {
      final year = int.tryParse(field.metadata['year'] ?? '');
      final month = int.tryParse(field.metadata['month'] ?? '');
      final day = int.tryParse(field.metadata['day'] ?? '');
      if (year == null || month == null || day == null) {
        return MergePlanValidation(
          MergePlanValidationCode.invalidSelectedField,
          detailCode: 'birthday_metadata:${field.optionId}',
        );
      }
      final date = DateTime(year, month, day);
      if (date.year != year || date.month != month || date.day != day) {
        return MergePlanValidation(
          MergePlanValidationCode.invalidSelectedField,
          detailCode: 'birthday_metadata_date:${field.optionId}',
        );
      }
    }
    return null;
  }

  bool _validDateOnly(String value) {
    if (!_datePattern.hasMatch(value)) return false;
    final parts = value.split('-').map(int.tryParse).toList(growable: false);
    if (parts.any((value) => value == null)) return false;
    final date = DateTime(parts[0]!, parts[1]!, parts[2]!);
    return date.year == parts[0] &&
        date.month == parts[1] &&
        date.day == parts[2];
  }

  bool _hasAnyMetadata(Map<String, String> metadata, Set<String> keys) =>
      keys.any((key) => (metadata[key] ?? '').trim().isNotEmpty);

  bool _isOpaqueAvailabilityMarker(String value) {
    final marker = value.trim().toLowerCase();
    return marker == 'available' ||
        marker == 'selected' ||
        marker == 'present' ||
        marker == 'true';
  }

  bool _looksLikeRawSensitivePayload(String value) {
    final text = value.trim();
    if (text.length > 32) return true;
    return text.contains('\n') || text.contains('\r');
  }
}

extension StrictMergePlanSafety on MergePlan {
  bool isExpiredAt(DateTime now, {required Duration maxAge}) {
    final age = now.toUtc().difference(createdAt.toUtc());
    return age > maxAge;
  }

  bool hasFutureClockSkew(
    DateTime now, {
    required Duration tolerance,
  }) =>
      createdAt.toUtc().isAfter(now.toUtc().add(tolerance));

  String get semanticFingerprint => stableOpaqueId(
        <String>[
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
        namespace: 'merge-semantic',
      );

  String sourceContextFingerprint(Map<String, ContactRecord> records) {
    final values = <String>[];
    for (final id in sourceContactIds) {
      final record = records[id];
      if (record == null) {
        values.add('$id:missing');
      } else {
        values.add('$id:${record.contextFingerprint}');
      }
    }
    return stableOpaqueId(values, namespace: 'merge-live-context');
  }

  bool canPromoteToDestructive(Map<String, ContactRecord> records) {
    if (overlapsAnotherGroup ||
        requiresManualReview && !manualReviewAcknowledged ||
        hasUnresolvedConflicts ||
        unsupportedFieldKinds.isNotEmpty ||
        sourceContactIds.length < 2) {
      return false;
    }
    return sourceContactIds.every((id) {
      final record = records[id];
      return record != null &&
          record.effectiveStableIdentity &&
          record.capabilities.isFullyWritable;
    });
  }

  MergeSafetySeverity get safetySeverity {
    if (safetyBlockers.any(
      (blocker) =>
          blocker.type == MergeSafetyBlockerType.unstableSource ||
          blocker.type == MergeSafetyBlockerType.staleSnapshot ||
          blocker.type == MergeSafetyBlockerType.staleGroup ||
          blocker.type == MergeSafetyBlockerType.expiredPlan,
    )) {
      return MergeSafetySeverity.critical;
    }
    if (safetyBlockers.isNotEmpty) return MergeSafetySeverity.blocking;
    if (requiresManualReview) return MergeSafetySeverity.warning;
    return MergeSafetySeverity.info;
  }
}
