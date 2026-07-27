import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/contacts/contact_copy_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_primary_button.dart';
import '../backup/backup_controller.dart';
import 'contact_copy_controller.dart';
import 'merge_detail_controller.dart';

class ContactCopyAction extends StatelessWidget {
  final List<String> sourceContactIds;

  const ContactCopyAction({
    required this.sourceContactIds,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final backupController = context.watch<BackupController>();
    final mergeController = context.watch<MergeDetailController>();
    final copyController = context.watch<ContactCopyController>();
    final backup = backupController.latestMergeEligibleBackup;
    final validation = backupController.mergeValidation;
    final validationReady = mergeController.isValid &&
        backup != null &&
        validation != null &&
        validation.isValid &&
        validation.backupId == backup.id &&
        validation.matchesSources(sourceContactIds);

    if (!validationReady) {
      return const SizedBox.shrink();
    }

    final stateBelongsToCurrentGroup =
        copyController.matchesSources(sourceContactIds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 16),
        const _CopyInformationCard(),
        if (stateBelongsToCurrentGroup) ...<Widget>[
          const SizedBox(height: 12),
          _CopyStatusCard(status: copyController.status),
        ],
        const SizedBox(height: 12),
        AppPrimaryButton(
          label: copyController.isBusy
              ? 'Se creeaza si se verifica copia'
              : stateBelongsToCurrentGroup &&
                      copyController.status ==
                          ContactCopyControllerStatus.success
                  ? 'Creeaza alta copie consolidata'
                  : 'Creeaza copia consolidata',
          icon: Icons.person_add_alt_1_outlined,
          isLoading: copyController.isBusy,
          onPressed: copyController.isBusy
              ? null
              : () => _confirmAndCreate(
                    context,
                    backupController,
                    mergeController,
                    copyController,
                  ),
        ),
      ],
    );
  }

  Future<void> _confirmAndCreate(
    BuildContext context,
    BackupController backupController,
    MergeDetailController mergeController,
    ContactCopyController copyController,
  ) async {
    final draft = mergeController.draft;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Creeaza copia consolidata?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Va fi creat un contact nou cu ${draft.phones.length} telefoane si ${draft.emails.length} emailuri.',
              ),
              const SizedBox(height: 12),
              Text(
                'Cele ${sourceContactIds.length} contacte sursa raman neschimbate. Nicio sursa nu va fi stearsa.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Dupa creare, aplicatia reciteste contactul nou si verifica toate valorile selectate.',
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Renunta'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Creeaza copia'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final sourceValidation =
        await backupController.validateMergeSources(sourceContactIds);
    if (!context.mounted) {
      return;
    }

    final currentBackup = backupController.latestMergeEligibleBackup;
    if (!sourceValidation.isValid ||
        currentBackup == null ||
        sourceValidation.backupId != currentBackup.id ||
        !mergeController.isValid) {
      _showMessage(
        context,
        'Conditiile de siguranta s-au schimbat. Revalideaza backupul si previzualizarea.',
      );
      return;
    }

    final currentDraft = mergeController.draft;
    final result = await copyController.create(
      ContactCopyDraft(
        displayName: currentDraft.displayName,
        phones: currentDraft.phones,
        emails: currentDraft.emails,
        sourceContactIds: sourceContactIds,
      ),
    );
    if (!context.mounted || result == null) {
      return;
    }

    _showMessage(context, _resultMessage(result));
  }

  String _resultMessage(ContactCopyResult result) {
    return switch (result.status) {
      ContactCopyStatus.success =>
        'Copia consolidata a fost creata si verificata. Contactele sursa au ramas neschimbate.',
      ContactCopyStatus.permissionDenied =>
        'Permisiunea de scriere in agenda a fost refuzata.',
      ContactCopyStatus.invalidDraft =>
        'Previzualizarea nu mai contine toate datele obligatorii.',
      ContactCopyStatus.createFailed =>
        'Copia consolidata nu a putut fi creata.',
      ContactCopyStatus.verificationFailed =>
        'Verificarea a esuat, iar copia noua a fost eliminata prin rollback.',
      ContactCopyStatus.rollbackFailed =>
        'Verificarea si rollbackul au esuat. Contactul nou poate exista in agenda si trebuie verificat manual.',
    };
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CopyInformationCard extends StatelessWidget {
  const _CopyInformationCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.shield_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Mod non-distructiv: aplicatia poate crea si verifica un contact consolidat, dar nu sterge si nu modifica sursele originale.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyStatusCard extends StatelessWidget {
  final ContactCopyControllerStatus status;

  const _CopyStatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, message, isError) = switch (status) {
      ContactCopyControllerStatus.idle => (
          Icons.info_outline_rounded,
          'Copia consolidata nu a fost creata inca.',
          false,
        ),
      ContactCopyControllerStatus.creating => (
          Icons.hourglass_top_rounded,
          'Copia este creata si verificata in agenda.',
          false,
        ),
      ContactCopyControllerStatus.success => (
          Icons.verified_outlined,
          'Ultima copie pentru acest grup a fost creata si verificata.',
          false,
        ),
      ContactCopyControllerStatus.permissionDenied => (
          Icons.lock_outline_rounded,
          'Permisiunea de scriere in agenda a fost refuzata.',
          true,
        ),
      ContactCopyControllerStatus.failed => (
          Icons.error_outline_rounded,
          'Copia nu a fost pastrata deoarece operatia sau verificarea a esuat.',
          true,
        ),
      ContactCopyControllerStatus.rollbackFailed => (
          Icons.warning_amber_rounded,
          'Rollbackul a esuat. Verifica manual agenda pentru un contact nou ramas partial.',
          true,
        ),
    };

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
