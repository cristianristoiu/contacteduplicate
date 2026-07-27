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

  const BackupMergeGate({
    this.previewValid = false,
    this.sourceContactCount = 0,
    this.selectedValueCount = 0,
    this.sourceContactIds = const <String>[],
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
              'Backup recent si validat: ${backup.contactCount} contacte, $scopeLabel. Continutul va fi verificat din nou inainte de orice scriere in agenda.',
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
    if (sourceContactIds.isEmpty) {
      return <Widget>[
        const _GateStatusCard(
          icon: Icons.error_outline_rounded,
          message:
              'Identificatorii contactelor sursa nu sunt disponibili. Fuziunea nu poate continua.',
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

    if (validation == null) {
      return <Widget>[
        AppPrimaryButton(
          label: 'Verifica sursele in backup',
          icon: Icons.fact_check_outlined,
          onPressed: controller.isBusy
              ? null
              : () => unawaited(
                    controller.validateMergeSources(sourceContactIds),
                  ),
        ),
        const SizedBox(height: 10),
        Text(
          'Verificarea reciteste copia criptata si confirma ca toate contactele acestui grup sunt incluse.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ];
    }

    if (validation.isValid) {
      return <Widget>[
        const _GateStatusCard(
          icon: Icons.verified_outlined,
          message:
              'Toate contactele sursa sunt prezente in backupul recent si verificat.',
        ),
        const SizedBox(height: 12),
        const AppPrimaryButton(
          label: 'Executia fuziunii ramane blocata',
          icon: Icons.lock_outline_rounded,
          onPressed: null,
        ),
        const SizedBox(height: 10),
        Text(
          'Conditiile de pregatire sunt indeplinite. Scrierea in agenda va fi activata numai dupa implementarea confirmarii finale si a motorului de fuziune cu verificare post-operatie.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ];
    }

    final requiresNewBackup = validation.status ==
            MergeBackupValidationStatus.sourceContactsMissing ||
        validation.status == MergeBackupValidationStatus.backupExpired ||
        validation.status == MergeBackupValidationStatus.noEligibleBackup;
    final message = switch (validation.status) {
      MergeBackupValidationStatus.sourceContactsMissing =>
        'Backupul recent nu contine toate contactele sursa. Este necesara o copie noua inainte de fuziune.',
      MergeBackupValidationStatus.backupExpired =>
        'Backupul a expirat in timpul verificarii. Creeaza o copie noua a agendei.',
      MergeBackupValidationStatus.noEligibleBackup =>
        'Nu mai exista un backup eligibil pentru aceasta fuziune.',
      MergeBackupValidationStatus.failed =>
        'Sursele nu au putut fi validate in backup. Reincearca verificarea.',
      MergeBackupValidationStatus.valid =>
        'Sursele au fost validate.',
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
                : () => unawaited(
                      controller.validateMergeSources(sourceContactIds),
                    ),
      ),
    ];
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
