import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_router.dart';
import '../../core/backup/contact_backup_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_primary_button.dart';
import 'backup_controller.dart';

class BackupMergeGate extends StatelessWidget {
  const BackupMergeGate({super.key});

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
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.verified_user_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Backup recent si validat: ${backup.contactCount} contacte, $scopeLabel. Continutul va fi verificat din nou inainte de orice scriere in agenda.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const AppPrimaryButton(
          label: 'Previzualizarea fuziunii nu este inca activa',
          icon: Icons.lock_outline_rounded,
          onPressed: null,
        ),
        const SizedBox(height: 10),
        Text(
          'Backupul indeplineste prima conditie de siguranta. Fuziunea ramane blocata pana la implementarea selectiei campurilor si a confirmarii finale.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
