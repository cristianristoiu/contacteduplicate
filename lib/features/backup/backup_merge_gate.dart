import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_router.dart';
import '../../core/backup/contact_backup_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_primary_button.dart';
import 'backup_controller.dart';

class BackupMergeGate extends StatelessWidget {
  final bool previewValid;
  final int sourceContactCount;
  final int selectedValueCount;
  final List<String> sourceContactIds;
  final List<MergeSourceSnapshot> sourceSnapshots;

  const BackupMergeGate({
    this.previewValid = false,
    this.sourceContactCount = 0,
    this.selectedValueCount = 0,
    this.sourceContactIds = const <String>[],
    this.sourceSnapshots = const <MergeSourceSnapshot>[],
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BackupController>();
    final backup = controller.latestMergeEligibleBackup;
    final hasStaleValidatedBackup =
        backup == null && controller.latestValidatedBackup != null;

    if (controller.status == BackupStatus.loading ||
        controller.status == BackupStatus.idle) {
      return const AppPrimaryButton(
        label: 'Se verifica backupurile',
        icon: Icons.hourglass_top_rounded,
        isLoading: true,
        onPressed: null,
      );
    }

    if (backup == null) {
      final message = hasStaleValidatedBackup
          ? 'Exista un backup valid, dar este mai vechi de 5 minute. Fuziunea necesita o copie noua a starii curente a agendei.'
          : 'Nu exista niciun backup care a trecut verificarea de integritate. Fuziunea trebuie sa ramana blocata.';
      final buttonLabel = hasStaleValidatedBackup
          ? 'Creeaza backup recent'
          : 'Creeaza backup pentru fuziune';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _GateStatusCard(
            icon: Icons.warning_amber_rounded,
            message: message,
            isError: true,
          ),
          const SizedBox(height: 12),
          AppPrimaryButton(
            label: buttonLabel,
            icon: Icons.enhanced_encryption_outlined,
            onPressed: controller.isBusy
                ? null
                : () => context.go(AppRoutes.backup),
          ),
        ],
      );
    }

    final scopeLabel = backup.accessScope == BackupAccessScope.limited
        ? 'acces limitat iOS'
        : 'acces complet';
    final validation = controller.mergeValidation;
    final validationForCurrentSources = validation != null &&
            validation.matchesSources(sourceContactIds)
        ? validation
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _GateStatusCard(
          icon: Icons.verified_user_outlined,
          message:
              'Backup recent si validat: ${backup.contactCount} contacte, $scopeLabel. Continutul surselor va fi comparat cu snapshotul scanarii inainte de orice scriere in agenda.',
        ),
        const SizedBox(height: 12),
        if (!previewValid) ...<Widget>[
          const AppPrimaryButton(
            label: 'Completeaza campurile obligatorii',
            icon: Icons.rule_rounded,
            onPressed: null,
          ),
          const SizedBox(height: 10),
          Text(
            'Backupul este pregatit, dar rezultatul final trebuie sa aiba un nume si cel putin o metoda de contact.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ] else ...<Widget>[
          _GateStatusCard(
            icon: Icons.preview_outlined,
            message:
                'Previzualizare valida: $sourceContactCount contacte sursa si $selectedValueCount valori de contact selectate.',
          ),
          const SizedBox(height: 12),
          ..._buildSourceValidation(
            context,
            controller,
            validationForCurrentSources,
          ),
        ],
      ],
    );
  }

  List<Widget> _buildSourceValidation(
    BuildContext context,
    BackupController controller,
    MergeBackupValidation? validation,
  ) {
    if (sourceContactIds.isEmpty || sourceSnapshots.isEmpty) {
      return <Widget>[
        const _GateStatusCard(
          icon: Icons.error_outline_rounded,
          message:
              'Snapshotul contactelor sursa nu este disponibil complet. Operatia nu poate continua.',
          isError: true,
        ),
      ];
    }

    if (controller.isValidatingMergeSources) {
      return const <Widget>[
        AppPrimaryButton(
          label: 'Se verifica sursele in backup',
          icon: Icons.fact_check_outlined,
          isLoading: true,
          onPressed: null,
        ),
      ];
    }

    if (validation == null ||
        (validation.isValid && !validation.sourceContentValidated)) {
      return <Widget>[
        AppPrimaryButton(
          label: 'Verifica sursele in backup',
          icon: Icons.fact_check_outlined,
          onPressed: controller.isBusy
              ? null
              : () => unawaited(_validateSources(controller)),
        ),
        const SizedBox(height: 10),
        Text(
          'Verificarea reciteste copia criptata si compara ID-ul, numele, telefoanele si emailurile fiecarui contact sursa cu snapshotul scanarii curente.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ];
    }

    if (validation.isValid && validation.sourceContentValidated) {
      return <Widget>[
        const _GateStatusCard(
          icon: Icons.verified_outlined,
          message:
              'Contactele sursa corespund continutului salvat in backupul recent si verificat.',
        ),
        const SizedBox(height: 12),
        const AppPrimaryButton(
          label: 'Stergerea surselor ramane blocata',
          icon: Icons.lock_outline_rounded,
          onPressed: null,
        ),
        const SizedBox(height: 10),
        Text(
          'Poti crea mai jos o copie consolidata non-distructiva. Fuziunea care sterge sursele va fi activata numai dupa implementarea motorului tranzactional si a restaurarii verificate.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ];
    }

    final requiresNewBackup = validation.status ==
            MergeBackupValidationStatus.sourceContactsMissing ||
        validation.status == MergeBackupValidationStatus.sourceContactsChanged ||
        validation.status == MergeBackupValidationStatus.backupExpired ||
        validation.status == MergeBackupValidationStatus.noEligibleBackup;
    final message = switch (validation.status) {
      MergeBackupValidationStatus.sourceContactsMissing =>
        'Backupul recent nu contine toate contactele sursa. Este necesara o copie noua inainte de orice operatie.',
      MergeBackupValidationStatus.sourceContactsChanged =>
        'Cel putin un contact sursa s-a schimbat fata de backup. Creeaza un backup nou din starea curenta a agendei.',
      MergeBackupValidationStatus.backupExpired =>
        'Backupul a expirat in timpul verificarii. Creeaza o copie noua a agendei.',
      MergeBackupValidationStatus.noEligibleBackup =>
        'Nu mai exista un backup eligibil pentru aceasta operatie.',
      MergeBackupValidationStatus.failed =>
        'Sursele nu au putut fi validate complet in backup. Reincearca verificarea.',
      MergeBackupValidationStatus.valid =>
        'Validarea continutului surselor trebuie refacuta.',
    };

    return <Widget>[
      _GateStatusCard(
        icon: Icons.gpp_bad_outlined,
        message: message,
        isError: true,
      ),
      const SizedBox(height: 12),
      AppPrimaryButton(
        label: requiresNewBackup ? 'Creeaza backup nou' : 'Reincearca verificarea',
        icon: requiresNewBackup
            ? Icons.enhanced_encryption_outlined
            : Icons.refresh_rounded,
        onPressed: controller.isBusy
            ? null
            : requiresNewBackup
                ? () => context.go(AppRoutes.backup)
                : () => unawaited(_validateSources(controller)),
      ),
    ];
  }

  Future<MergeBackupValidation> _validateSources(
    BackupController controller,
  ) {
    return controller.validateMergeSources(
      sourceContactIds,
      sourceSnapshots: sourceSnapshots,
    );
  }
}

class _GateStatusCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isError;

  const _GateStatusCard({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            color: isError
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
