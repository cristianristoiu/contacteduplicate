import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/contacts/contacts_scan_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_primary_button.dart';
import '../../shared/widgets/app_secondary_button.dart';
import '../backup/backup_controller.dart';
import '../dashboard/scan_controller.dart';
import 'merge_detail_controller.dart';
import 'merge_engine_service.dart';
import 'merge_operation_controller.dart';
import 'merge_plan.dart';

class MergeOperationPanel extends StatelessWidget {
  final DuplicateContactGroup group;

  const MergeOperationPanel({required this.group, super.key});

  @override
  Widget build(BuildContext context) {
    final merge = context.watch<MergeDetailController>();
    final operation = context.watch<MergeOperationController>();
    final backup = context.watch<BackupController>();
    final scan = context.watch<ScanController>();
    final sourceIds = group.contacts.map((contact) => contact.nativeId).toList();
    final validation = backup.mergeValidation;
    final eligibleBackup = backup.latestMergeEligibleBackup;
    final backupReady = eligibleBackup != null &&
        validation != null &&
        validation.isValid &&
        validation.sourceContentValidated &&
        validation.backupId == eligibleBackup.id &&
        validation.matchesSources(sourceIds);

    if (!group.canBeMerged || group.overlapsAnotherGroup) {
      return const _MergeNotice(
        icon: Icons.lock_outline_rounded,
        text:
            'Fuziunea distructiva este blocata pentru acest grup. Poti folosi doar copia consolidata non-distructiva.',
        isWarning: true,
      );
    }

    final status = operation.status;
    final isResultState = status == MergeOperationControllerStatus.success ||
        status == MergeOperationControllerStatus.partial ||
        status == MergeOperationControllerStatus.failed ||
        status == MergeOperationControllerStatus.cancelled ||
        status == MergeOperationControllerStatus.blocked ||
        status == MergeOperationControllerStatus.reconcileRequired;

    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 16),
          Text(
            'Fuziune verificata',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Aceasta operatie poate elimina numai sursele demonstrate ca modificabile. Backupul, revizia scanarii si continutul surselor sunt reverificate inainte de scriere.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _PlanSafetySummary(merge: merge),
          if (group.requiresManualReview) ...<Widget>[
            const SizedBox(height: 12),
            AppCard(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: merge.manualReviewAcknowledged,
                onChanged: operation.editorLocked
                    ? null
                    : (value) => merge.acknowledgeManualReview(value == true),
                title: const Text('Am verificat manual acest grup'),
                subtitle: const Text(
                  'Confirm ca valorile apartin aceleiasi persoane si ca rezultatul ales este cel dorit.',
                ),
              ),
            ),
          ],
          if (!backupReady) ...<Widget>[
            const SizedBox(height: 12),
            const _MergeNotice(
              icon: Icons.enhanced_encryption_outlined,
              text:
                  'Fuziunea ramane blocata pana cand sursele sunt validate integral intr-un backup recent si eligibil.',
              isWarning: true,
            ),
          ],
          if (merge.unsupportedFieldKinds.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _MergeNotice(
              icon: Icons.inventory_2_outlined,
              text:
                  'Fuziunea distructiva este blocata pentru a evita pierderea campurilor: ${_fieldLabels(merge.unsupportedFieldKinds)}.',
              isWarning: true,
            ),
          ],
          if (merge.hasReadOnlySources) ...<Widget>[
            const SizedBox(height: 12),
            const _MergeNotice(
              icon: Icons.lock_person_outlined,
              text:
                  'Cel putin o sursa este read-only. Motorul nu va forta stergerea ei; pentru acest grup ramane disponibil fallback-ul non-distructiv.',
              isWarning: true,
            ),
          ],
          if (operation.isRunning) ...<Widget>[
            const SizedBox(height: 12),
            _MergeProgressView(operation: operation),
          ],
          if (isResultState) ...<Widget>[
            const SizedBox(height: 12),
            _MergeResultView(operation: operation),
          ],
          if (operation.historyWriteFailed) ...<Widget>[
            const SizedBox(height: 12),
            const _MergeNotice(
              icon: Icons.history_toggle_off_rounded,
              text:
                  'Agenda a fost deja procesata, dar istoricul local nu a putut fi salvat. Nu repeta fuziunea doar din acest motiv.',
              isWarning: true,
            ),
            const SizedBox(height: 10),
            AppSecondaryButton(
              label: 'Reincearca salvarea istoricului',
              icon: Icons.refresh_rounded,
              onPressed: operation.isRunning
                  ? null
                  : () => unawaited(operation.retryHistoryWrite()),
            ),
          ],
          const SizedBox(height: 12),
          if (operation.canCancel)
            AppSecondaryButton(
              label: 'Opreste in punct sigur',
              icon: Icons.stop_circle_outlined,
              onPressed: operation.requestCancel,
            )
          else if (operation.isRunning)
            const _MergeNotice(
              icon: Icons.shield_outlined,
              text:
                  'Faza curenta modifica agenda. Anularea si navigarea sunt blocate pana la urmatorul punct sigur.',
            )
          else if (scan.resultsStale && operation.report?.changedAgenda == true)
            AppPrimaryButton(
              label: scan.isScanning ? 'Se rescaneaza agenda' : 'Rescaneaza agenda',
              icon: Icons.refresh_rounded,
              isLoading: scan.isScanning,
              onPressed: scan.isScanning ? null : () => unawaited(scan.scan()),
            )
          else if (operation.requiresReconcile)
            AppPrimaryButton(
              label: 'Rescaneaza pentru reconciliere',
              icon: Icons.sync_problem_rounded,
              onPressed: scan.isScanning ? null : () => unawaited(scan.scan()),
            )
          else if (!isResultState)
            AppPrimaryButton(
              label: 'Verifica si pregateste fuziunea',
              icon: Icons.merge_type_rounded,
              onPressed: !backupReady ||
                      !merge.canAttemptDestructiveMerge ||
                      operation.isRunning ||
                      scan.resultsStale ||
                      scan.isScanning
                  ? null
                  : () => unawaited(
                        _prepareAndConfirm(
                          context,
                          merge,
                          operation,
                          eligibleBackup.id,
                          scan.scanRevision,
                        ),
                      ),
            )
          else if (!operation.requiresReconcile && !operation.historyWriteFailed)
            AppSecondaryButton(
              label: 'Inchide rezultatul',
              icon: Icons.check_rounded,
              onPressed: operation.isRunning ? null : operation.acknowledgeResult,
            ),
        ],
      ),
    );
  }

  Future<void> _prepareAndConfirm(
    BuildContext context,
    MergeDetailController merge,
    MergeOperationController operation,
    String backupId,
    int scanRevision,
  ) async {
    final operationId = MergePlanFactory.generateOperationId(groupId: group.id);
    final plan = merge.buildPlan(
      backupId: backupId,
      scanRevision: scanRevision,
      operationId: operationId,
    );
    final validation = const MergePlanValidator().validate(
      plan,
      sourceRecords: merge.sourceRecords,
      expectedGroupFingerprint: group.revisionFingerprint,
    );
    if (!validation.isValid || !plan.isDestructive) {
      _showMessage(
        context,
        'Planul nu a trecut verificarile de siguranta (${validation.code.name}).',
      );
      return;
    }
    if (!operation.prepare(plan) || !context.mounted) return;

    final counters = plan.counters(merge.sourceRecords);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmi fuziunea?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('${counters.sourceContacts} contacte sursa au fost verificate.'),
              const SizedBox(height: 10),
              Text('${counters.deletionTargets} surse sunt eligibile pentru eliminare.'),
              const SizedBox(height: 10),
              Text('${counters.retainedSources} surse vor fi pastrate.'),
              const SizedBox(height: 10),
              Text('${counters.selectedFields} campuri vor fi scrise in rezultatul consolidat.'),
              const SizedBox(height: 14),
              const Text(
                'Operatia continua numai daca backupul, revizia scanarii, capabilitatile si continutul live corespund in continuare. Orice stare incerta opreste fluxul pentru reconciliere.',
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Renunta'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.merge_type_rounded),
            label: const Text('Executa fuziunea'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      operation.rejectConfirmation();
      return;
    }
    if (!context.mounted) return;
    final report = await operation.confirmAndExecute();
    if (!context.mounted || report == null) return;
    _showMessage(context, _reportMessage(report));
  }

  void _showMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _reportMessage(MergeReport report) => switch (report.status) {
        MergeExecutionStatus.success => 'Fuziunea a fost verificata integral.',
        MergeExecutionStatus.partialFailure =>
          'Fuziunea s-a incheiat partial. Consulta starea si rescaneaza agenda.',
        MergeExecutionStatus.cancelled => 'Fuziunea a fost oprita in punct sigur.',
        MergeExecutionStatus.reconcileRequired ||
        MergeExecutionStatus.rollbackFailed =>
          'Starea finala trebuie reconciliata inainte de orice retry.',
        _ => 'Fuziunea a fost oprita fara a putea fi finalizata.',
      };

  String _fieldLabels(Set<MergeFieldKind> kinds) {
    final labels = kinds.map((kind) => switch (kind) {
          MergeFieldKind.address => 'adrese',
          MergeFieldKind.company => 'companie',
          MergeFieldKind.department => 'departament',
          MergeFieldKind.jobTitle => 'functie',
          MergeFieldKind.birthday => 'data nasterii',
          MergeFieldKind.note => 'note',
          MergeFieldKind.photo => 'fotografie',
          MergeFieldKind.favorite => 'favorit',
          _ => kind.name,
        }).toList()
      ..sort();
    return labels.join(', ');
  }
}

class _PlanSafetySummary extends StatelessWidget {
  final MergeDetailController merge;
  const _PlanSafetySummary({required this.merge});

  @override
  Widget build(BuildContext context) {
    final writable = merge.sourceRecords.values
        .where((record) => record.capabilities.isFullyWritable)
        .length;
    final readOnly = merge.sourceRecords.values
        .where((record) => record.capabilities.isKnownReadOnly)
        .length;
    final unknown = merge.sourceRecords.length - writable - readOnly;
    return AppCard(
      semanticLabel:
          '${merge.contacts.length} surse, $writable modificabile, $readOnly read-only, $unknown cu capabilitate necunoscuta',
      child: Wrap(
        spacing: 18,
        runSpacing: 10,
        children: <Widget>[
          _Metric(label: 'Surse', value: merge.contacts.length),
          _Metric(label: 'Modificabile', value: writable),
          _Metric(label: 'Read-only', value: readOnly),
          _Metric(label: 'Necunoscute', value: unknown),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('$value', style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MergeProgressView extends StatelessWidget {
  final MergeOperationController operation;
  const _MergeProgressView({required this.operation});

  @override
  Widget build(BuildContext context) {
    final progress = operation.progress;
    final ratio = (progress?.ratio ?? 0).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();
    final phase = progress?.phase.name ?? 'pregatire';
    return Semantics(
      liveRegion: true,
      label: 'Fuziune in curs, faza $phase, $percent la suta',
      value: '$percent%',
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LinearProgressIndicator(value: ratio),
            const SizedBox(height: 12),
            Text('Faza: $phase'),
            const SizedBox(height: 4),
            Text('$percent%'),
          ],
        ),
      ),
    );
  }
}

class _MergeResultView extends StatelessWidget {
  final MergeOperationController operation;
  const _MergeResultView({required this.operation});

  @override
  Widget build(BuildContext context) {
    final report = operation.report;
    final status = operation.status;
    final text = switch (status) {
      MergeOperationControllerStatus.success =>
        'Fuziunea a fost finalizata si verificata.',
      MergeOperationControllerStatus.partial =>
        'Operatia s-a finalizat partial. Agenda trebuie rescannata inainte de alta actiune.',
      MergeOperationControllerStatus.reconcileRequired =>
        'Starea finala nu poate fi demonstrata. Nu repeta operatia pana dupa reconciliere.',
      MergeOperationControllerStatus.blocked =>
        'Planul a fost blocat de o conditie de siguranta.',
      MergeOperationControllerStatus.cancelled =>
        'Operatia a fost oprita intr-un punct sigur.',
      MergeOperationControllerStatus.failed =>
        'Operatia nu a putut fi finalizata.',
      _ => 'Operatia necesita verificare.',
    };
    return _MergeNotice(
      icon: status == MergeOperationControllerStatus.success
          ? Icons.verified_outlined
          : Icons.warning_amber_rounded,
      text: report == null
          ? text
          : '$text Sterse: ${report.deletedSourceIds.length}; pastrate: ${report.skippedSourceIds.length}.',
      isWarning: status != MergeOperationControllerStatus.success,
    );
  }
}

class _MergeNotice extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isWarning;

  const _MergeNotice({
    required this.icon,
    required this.text,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWarning
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
