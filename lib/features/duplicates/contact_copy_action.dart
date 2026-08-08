import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/contacts/contact_copy_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_primary_button.dart';
import '../../shared/widgets/app_secondary_button.dart';
import '../backup/backup_controller.dart';
import '../dashboard/scan_controller.dart';
import 'contact_copy_controller.dart';
import 'merge_detail_controller.dart';

class ContactCopyAction extends StatelessWidget {
  final List<String> sourceContactIds;
  final List<MergeSourceSnapshot> sourceSnapshots;

  const ContactCopyAction({
    required this.sourceContactIds,
    required this.sourceSnapshots,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final backupController = context.watch<BackupController>();
    final scanController = context.watch<ScanController>();
    final mergeController = context.watch<MergeDetailController>();
    final copyController = context.watch<ContactCopyController>();
    final currentDraft = _copyDraft(mergeController.draft);
    final stateBelongsToCurrentDraft = copyController.matchesDraft(currentDraft);
    final backup = backupController.latestMergeEligibleBackup;
    final validation = backupController.mergeValidation;
    final validationReady = !scanController.resultsStale &&
        mergeController.isValid &&
        backup != null &&
        validation != null &&
        validation.isValid &&
        validation.sourceContentValidated &&
        validation.backupId == backup.id &&
        validation.matchesSources(sourceContactIds);
    final persistentState = stateBelongsToCurrentDraft &&
        (copyController.status == ContactCopyControllerStatus.success ||
            copyController.status == ContactCopyControllerStatus.rollbackFailed ||
            copyController.status == ContactCopyControllerStatus.removing ||
            copyController.status == ContactCopyControllerStatus.removed ||
            copyController.status ==
                ContactCopyControllerStatus.removalPermissionDenied ||
            copyController.status == ContactCopyControllerStatus.removalFailed);

    if (!validationReady && !persistentState) {
      return const SizedBox.shrink();
    }

    final isBusyForCurrentDraft =
        copyController.isBusy && stateBelongsToCurrentDraft;
    final isBusyForAnotherDraft =
        copyController.isBusy && !stateBelongsToCurrentDraft;
    final isRemoving = stateBelongsToCurrentDraft &&
        copyController.status == ContactCopyControllerStatus.removing;
    final exactDraftSucceeded = stateBelongsToCurrentDraft &&
        copyController.status == ContactCopyControllerStatus.success;
    final exactDraftRemoved = stateBelongsToCurrentDraft &&
        copyController.status == ContactCopyControllerStatus.removed;
    final exactDraftRequiresManualCheck = stateBelongsToCurrentDraft &&
        (copyController.status == ContactCopyControllerStatus.rollbackFailed ||
            copyController.status ==
                ContactCopyControllerStatus.removalPermissionDenied ||
            copyController.status == ContactCopyControllerStatus.removalFailed);
    final canRescanAfterRemoval =
        exactDraftRemoved && scanController.resultsStale && !scanController.isScanning;
    final writeBlocked = !validationReady ||
        copyController.isBusy ||
        exactDraftSucceeded ||
        exactDraftRequiresManualCheck;

    final buttonLabel = scanController.isScanning && exactDraftRemoved
        ? 'Se rescaneaza agenda'
        : canRescanAfterRemoval
            ? 'Rescaneaza agenda'
            : isRemoving
                ? 'Se elimina copia consolidata'
                : isBusyForCurrentDraft
                    ? 'Se creeaza si se verifica copia'
                    : isBusyForAnotherDraft
                        ? 'Alta operatie este in curs'
                        : exactDraftSucceeded
                            ? 'Copia acestui draft a fost creata'
                            : exactDraftRequiresManualCheck
                                ? 'Verifica agenda manual'
                                : !validationReady
                                    ? 'Revalideaza sursele pentru continuare'
                                    : 'Creeaza copia consolidata';
    final buttonIcon = canRescanAfterRemoval ||
            (scanController.isScanning && exactDraftRemoved)
        ? Icons.refresh_rounded
        : exactDraftSucceeded
            ? Icons.verified_outlined
            : exactDraftRequiresManualCheck
                ? Icons.warning_amber_rounded
                : isRemoving
                    ? Icons.delete_outline_rounded
                    : Icons.person_add_alt_1_outlined;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 16),
        const _CopyInformationCard(),
        if (stateBelongsToCurrentDraft) ...<Widget>[
          const SizedBox(height: 12),
          _CopyStatusCard(status: copyController.status),
        ],
        const SizedBox(height: 12),
        AppPrimaryButton(
          label: buttonLabel,
          icon: buttonIcon,
          isLoading: isBusyForCurrentDraft ||
              (scanController.isScanning && exactDraftRemoved),
          onPressed: canRescanAfterRemoval
              ? () => unawaited(scanController.scan())
              : writeBlocked
                  ? null
                  : () => _confirmAndCreate(
                        context,
                        backupController,
                        mergeController,
                        copyController,
                        currentDraft,
                      ),
        ),
        if (exactDraftSucceeded) ...<Widget>[
          const SizedBox(height: 12),
          AppSecondaryButton(
            label: 'Sterge copia creata',
            icon: Icons.delete_outline_rounded,
            onPressed: copyController.isBusy
                ? null
                : () => _confirmAndRemove(
                      context,
                      copyController,
                      currentDraft,
                    ),
          ),
          const SizedBox(height: 10),
          Text(
            'Eliminarea verifica mai intai identitatea copiei. Contactele sursa nu sunt atinse.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Future<void> _confirmAndCreate(
    BuildContext context,
    BackupController backupController,
    MergeDetailController mergeController,
    ContactCopyController copyController,
    ContactCopyDraft confirmedDraft,
  ) async {
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
                'Va fi creat un contact nou cu ${confirmedDraft.phones.length} telefoane si ${confirmedDraft.emails.length} emailuri.',
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

    final sourceValidation = await backupController.validateMergeSources(
      sourceContactIds,
      sourceSnapshots: sourceSnapshots,
    );
    if (!context.mounted) {
      return;
    }

    final currentBackup = backupController.latestMergeEligibleBackup;
    final currentDraft = _copyDraft(mergeController.draft);
    if (!sourceValidation.isValid ||
        !sourceValidation.sourceContentValidated ||
        currentBackup == null ||
        sourceValidation.backupId != currentBackup.id ||
        !mergeController.isValid ||
        currentDraft.fingerprint != confirmedDraft.fingerprint) {
      _showMessage(
        context,
        'Backupul, sursele sau previzualizarea nu mai corespund. Revalideaza datele inainte de scriere.',
      );
      return;
    }

    final result = await copyController.create(currentDraft);
    if (!context.mounted || result == null) {
      return;
    }

    if (_creationMayHaveChangedAgenda(result.status)) {
      context.read<ScanController>().markResultsStale();
    }
    _showMessage(context, _resultMessage(result));
  }

  Future<void> _confirmAndRemove(
    BuildContext context,
    ContactCopyController copyController,
    ContactCopyDraft expectedDraft,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sterge copia consolidata?'),
          content: const Text(
            'Aplicatia va reverifica identitatea contactului creat si va sterge numai acea copie. Contactele sursa raman neschimbate.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Renunta'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Sterge copia'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final result = await copyController.removeCurrentCopy(expectedDraft);
    if (!context.mounted || result == null) {
      return;
    }

    if (_removalMayHaveChangedAgenda(result.status)) {
      context.read<ScanController>().markResultsStale();
    }
    _showMessage(context, _removalResultMessage(result));
  }

  bool _creationMayHaveChangedAgenda(ContactCopyStatus status) {
    return status == ContactCopyStatus.success ||
        status == ContactCopyStatus.createFailed ||
        status == ContactCopyStatus.rollbackFailed;
  }

  bool _removalMayHaveChangedAgenda(ContactCopyRemovalStatus status) {
    return status != ContactCopyRemovalStatus.permissionDenied &&
        status != ContactCopyRemovalStatus.invalidRequest;
  }

  ContactCopyDraft _copyDraft(MergeDraft draft) {
    return ContactCopyDraft(
      displayName: draft.displayName,
      phones: draft.phones,
      emails: draft.emails,
      sourceContactIds: sourceContactIds,
    );
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

  String _removalResultMessage(ContactCopyRemovalResult result) {
    return switch (result.status) {
      ContactCopyRemovalStatus.success =>
        'Copia consolidata a fost stearsa si absenta ei a fost verificata.',
      ContactCopyRemovalStatus.alreadyAbsent =>
        'Copia consolidata nu mai exista in agenda.',
      ContactCopyRemovalStatus.permissionDenied =>
        'Permisiunea de scriere a fost refuzata. Copia nu a fost stearsa.',
      ContactCopyRemovalStatus.invalidRequest =>
        'Datele necesare pentru eliminarea copiei nu mai sunt valide.',
      ContactCopyRemovalStatus.identityMismatch =>
        'Contactul s-a schimbat dupa creare. Stergerea automata a fost blocata.',
      ContactCopyRemovalStatus.deleteFailed =>
        'Copia nu a putut fi stearsa. Verifica agenda manual.',
      ContactCopyRemovalStatus.verificationFailed =>
        'Sistemul nu a confirmat eliminarea copiei. Verifica agenda manual.',
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
          'Ultima copie pentru acest draft a fost creata si verificata.',
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
      ContactCopyControllerStatus.removing => (
          Icons.hourglass_top_rounded,
          'Identitatea copiei este verificata, apoi copia va fi eliminata.',
          false,
        ),
      ContactCopyControllerStatus.removed => (
          Icons.delete_sweep_outlined,
          'Copia consolidata a fost eliminata sau era deja absenta.',
          false,
        ),
      ContactCopyControllerStatus.removalPermissionDenied => (
          Icons.lock_outline_rounded,
          'Permisiunea de stergere a fost refuzata. Copia poate exista inca.',
          true,
        ),
      ContactCopyControllerStatus.removalFailed => (
          Icons.warning_amber_rounded,
          'Eliminarea nu a putut fi verificata. Verifica agenda manual.',
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
