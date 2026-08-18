import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_router.dart';
import '../../core/backup/contact_backup_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_loading_indicator.dart';
import '../../shared/widgets/app_primary_button.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../history/history_controller.dart';
import 'backup_controller.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _loadScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadScheduled) return;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = context.read<BackupController>();
      if (controller.status == BackupStatus.idle) {
        unawaited(controller.load());
      }
      final history = context.read<HistoryController>();
      if (history.status == HistoryControllerStatus.idle) {
        unawaited(history.load());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BackupController>();
    final history = context.watch<HistoryController>();
    final protectedIds = history.entries
        .expand((entry) => entry.protectedBackupIds)
        .toSet();
    return AppScaffold(
      title: 'Backup',
      child: _buildContent(context, controller, protectedIds),
    );
  }

  Widget _buildContent(
    BuildContext context,
    BackupController controller,
    Set<String> protectedIds,
  ) {
    if ((controller.status == BackupStatus.idle ||
            controller.status == BackupStatus.loading) &&
        controller.backups.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }
    if (controller.status == BackupStatus.error && controller.backups.isEmpty) {
      return AppErrorState(
        title: 'Backupurile nu pot fi incarcate',
        message:
            'Spatiul local securizat nu a putut fi accesat. Reincearca operatia.',
        onRetry: () => unawaited(controller.load()),
      );
    }
    if (controller.status == BackupStatus.permissionDenied &&
        controller.backups.isEmpty) {
      return AppErrorState(
        title: 'Accesul la contacte este necesar',
        message:
            'Backupul local nu poate fi creat fara contactele disponibile aplicatiei.',
        onRetry: () => unawaited(_createBackup(context, controller)),
        retryLabel: 'Creeaza backup',
      );
    }
    if (controller.backups.isEmpty) {
      return AppEmptyState(
        icon: Icons.backup_outlined,
        title: 'Nu exista backupuri locale',
        description:
            'Creeaza o copie criptata a agendei inainte de operatiile care pot modifica contacte.',
        primaryButton: AppPrimaryButton(
          label: 'Creeaza backup',
          icon: Icons.enhanced_encryption_outlined,
          isLoading: controller.status == BackupStatus.creating,
          onPressed: controller.isBusy
              ? null
              : () => unawaited(_createBackup(context, controller)),
        ),
      );
    }

    final invalidCount = controller.backups.where((backup) => !backup.isValid).length;
    final protectedCount = controller.backups
        .where((backup) => protectedIds.contains(backup.id))
        .length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: <Widget>[
        const _BackupSecurityNotice(),
        const SizedBox(height: 16),
        if (protectedCount > 0) ...<Widget>[
          _BackupMessageCard(
            icon: Icons.lock_clock_outlined,
            message:
                '$protectedCount backupuri sunt protejate de operatii cu undo disponibil si nu pot fi sterse momentan.',
          ),
          const SizedBox(height: 16),
        ],
        AppPrimaryButton(
          label: controller.status == BackupStatus.creating
              ? 'Se creeaza backupul'
              : 'Creeaza backup nou',
          icon: Icons.enhanced_encryption_outlined,
          isLoading: controller.status == BackupStatus.creating,
          onPressed: controller.isBusy
              ? null
              : () => unawaited(_createBackup(context, controller)),
        ),
        if (controller.status == BackupStatus.permissionDenied) ...<Widget>[
          const SizedBox(height: 16),
          const _BackupMessageCard(
            icon: Icons.lock_outline_rounded,
            message:
                'Permisiunea pentru contacte a fost refuzata. Backupurile existente raman disponibile.',
            isError: true,
          ),
        ],
        if (controller.status == BackupStatus.error) ...<Widget>[
          const SizedBox(height: 16),
          _BackupMessageCard(
            icon: Icons.error_outline_rounded,
            message:
                'Ultima operatie de backup a esuat (${controller.errorCode ?? 'backup_error'}). Backupurile deja validate nu au fost eliminate.',
            isError: true,
          ),
        ],
        if (invalidCount > 0) ...<Widget>[
          const SizedBox(height: 16),
          const _BackupMessageCard(
            icon: Icons.gpp_bad_outlined,
            message:
                'Cel putin un fisier nu a trecut verificarea de integritate si nu poate fi folosit pentru restaurare.',
            isError: true,
          ),
        ],
        const SizedBox(height: 24),
        Text('Copii locale', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        ...controller.backups.map(
          (backup) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _BackupCard(
              backup: backup,
              isBusy: controller.isBusy,
              isProtected: protectedIds.contains(backup.id),
              onRestore: backup.isValid && !controller.isBusy
                  ? () => context.push(AppRoutes.restoreBackup(backup.id))
                  : null,
              onDelete: () => unawaited(
                _confirmDelete(
                  context,
                  controller,
                  backup,
                  protectedIds.contains(backup.id),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createBackup(
    BuildContext context,
    BackupController controller,
  ) async {
    final backup = await controller.create();
    if (!context.mounted || backup == null) return;
    final message = backup.accessScope == BackupAccessScope.limited
        ? 'Backup manual validat pentru contactele permise de accesul limitat iOS.'
        : 'Backup manual criptat si validat cu succes.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    BackupController controller,
    ContactBackup backup,
    bool isProtected,
  ) async {
    if (isProtected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Backupul este necesar pentru undo si nu poate fi sters pana cand dependinta nu este consumata.',
          ),
        ),
      );
      return;
    }
    final purpose = _purposeLabel(backup.purpose);
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Stergi backupul?',
      message:
          'Backupul de tip $purpose va fi eliminat definitiv din stocarea locala a aplicatiei. Aceasta actiune nu modifica agenda.',
      confirmText: 'Sterge',
      cancelText: 'Anuleaza',
      isDestructive: true,
      barrierDismissible: false,
    );
    if (!confirmed || !context.mounted) return;
    final deleted = await controller.delete(backup.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted ? 'Backup sters.' : 'Backupul nu a putut fi sters.',
        ),
      ),
    );
  }
}

class _BackupSecurityNotice extends StatelessWidget {
  const _BackupSecurityNotice();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      semanticLabel:
          'Backupurile sunt locale, criptate si protejate de operatiile care necesita undo',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.shield_outlined),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Copiile sunt pastrate local si criptat. Backupurile de siguranta legate de undo sunt protejate automat impotriva stergerii din acest ecran.',
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupMessageCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isError;

  const _BackupMessageCard({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _BackupCard extends StatelessWidget {
  final ContactBackup backup;
  final bool isBusy;
  final bool isProtected;
  final VoidCallback? onRestore;
  final VoidCallback onDelete;

  const _BackupCard({
    required this.backup,
    required this.isBusy,
    required this.isProtected,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = backup.isValid
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    final scopeLabel = switch (backup.accessScope) {
      BackupAccessScope.full => 'Acces complet',
      BackupAccessScope.limited => 'Acces limitat iOS',
      BackupAccessScope.unknown => 'Domeniu necunoscut',
    };
    final purposeLabel = _purposeLabel(backup.purpose);
    return AppCard(
      semanticLabel: backup.isValid
          ? 'Backup valid, $purposeLabel, ${backup.contactCount} contacte, $scopeLabel${isProtected ? ', protejat pentru undo' : ''}'
          : 'Backup invalid, restaurarea este blocata${isProtected ? ', protejat pentru undo' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                backup.isValid
                    ? Icons.verified_user_outlined
                    : Icons.warning_amber_rounded,
                color: statusColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      backup.isValid ? 'Backup validat' : 'Backup invalid',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: statusColor,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(_formatDate(backup.createdAt)),
                    const SizedBox(height: 4),
                    Text(
                      backup.isValid
                          ? '${backup.contactCount} contacte · $scopeLabel'
                          : 'Fisierul nu a trecut verificarea de integritate.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: <Widget>[
                        _BackupBadge(
                          icon: backup.isSafetyBackup
                              ? Icons.health_and_safety_outlined
                              : Icons.person_outline_rounded,
                          label: purposeLabel,
                        ),
                        if (isProtected)
                          const _BackupBadge(
                            icon: Icons.lock_clock_outlined,
                            label: 'Protejat pentru undo',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isProtected
                    ? 'Backup protejat - stergerea este blocata'
                    : 'Sterge backupul',
                onPressed: isBusy || isProtected ? null : onDelete,
                icon: Icon(
                  isProtected ? Icons.lock_outline_rounded : Icons.delete_outline_rounded,
                ),
              ),
            ],
          ),
          if (backup.isValid) ...<Widget>[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRestore,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Verifica pentru restaurare'),
            ),
          ],
        ],
      ),
    );
  }
}

class _BackupBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _BackupBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 15),
              const SizedBox(width: 5),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

String _purposeLabel(BackupPurpose purpose) => switch (purpose) {
      BackupPurpose.manual => 'Manual',
      BackupPurpose.mergeSafety => 'Siguranta fuziune',
      BackupPurpose.restoreSafety => 'Siguranta restaurare',
      BackupPurpose.undoSafety => 'Siguranta undo',
    };

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
