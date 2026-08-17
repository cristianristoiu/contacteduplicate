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
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BackupController>();
    return AppScaffold(
      title: 'Backup',
      child: _buildContent(context, controller),
    );
  }

  Widget _buildContent(BuildContext context, BackupController controller) {
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
            'Backupul poate fi creat doar dupa acordarea accesului la contactele dispozitivului.',
        onRetry: () => unawaited(_createBackup(context, controller)),
        retryLabel: 'Creeaza backup',
      );
    }
    if (controller.backups.isEmpty) {
      return AppEmptyState(
        icon: Icons.backup_outlined,
        title: 'Nu exista copii de rezerva',
        description:
            'Creeaza o copie locala criptata si validata inainte de orice modificare a contactelor.',
        primaryButton: AppPrimaryButton(
          label: controller.status == BackupStatus.creating
              ? 'Se creeaza backupul'
              : 'Creeaza backup',
          icon: Icons.enhanced_encryption_outlined,
          isLoading: controller.status == BackupStatus.creating,
          onPressed: controller.isBusy
              ? null
              : () => unawaited(_createBackup(context, controller)),
        ),
        isFullWidthButton: true,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: <Widget>[
        const _BackupSecurityNotice(),
        const SizedBox(height: 16),
        AppPrimaryButton(
          label: controller.status == BackupStatus.creating
              ? 'Se creeaza backupul'
              : 'Creeaza backup nou',
          icon: Icons.add_to_photos_outlined,
          isLoading: controller.status == BackupStatus.creating,
          onPressed: controller.isBusy
              ? null
              : () => unawaited(_createBackup(context, controller)),
        ),
        if (controller.status == BackupStatus.permissionDenied) ...<Widget>[
          const SizedBox(height: 16),
          const _BackupMessageCard(
            icon: Icons.lock_person_outlined,
            message:
                'Accesul la contacte a fost refuzat. Backupurile existente raman disponibile, dar nu poate fi creat unul nou.',
            isError: true,
          ),
        ],
        if (controller.status == BackupStatus.error) ...<Widget>[
          const SizedBox(height: 16),
          const _BackupMessageCard(
            icon: Icons.error_outline_rounded,
            message:
                'Ultima operatie de backup nu a putut fi finalizata. Copiile validate anterior nu au fost modificate.',
            isError: true,
          ),
        ],
        if (controller.backups.any((backup) => !backup.isValid)) ...<Widget>[
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
              onRestore: backup.isValid && !controller.isBusy
                  ? () => context.push(AppRoutes.restoreBackup(backup.id))
                  : null,
              onDelete: () => unawaited(
                _confirmDelete(context, controller, backup),
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
        ? 'Backup validat pentru contactele permise de accesul limitat iOS.'
        : 'Backup criptat si validat cu succes.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    BackupController controller,
    ContactBackup backup,
  ) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Stergi copia de rezerva?',
      message:
          'Fisierul local va fi eliminat definitiv. Contactele din agenda nu vor fi modificate.',
      confirmText: 'Sterge',
      cancelText: 'Anuleaza',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final deleted = await controller.delete(backup.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Copia de rezerva a fost stearsa.'
              : 'Copia de rezerva nu a putut fi stearsa.',
        ),
      ),
    );
  }
}

class _BackupSecurityNotice extends StatelessWidget {
  const _BackupSecurityNotice();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.shield_outlined,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Copiile sunt criptate, pastrate doar in spatiul intern al aplicatiei si verificate prin autentificarea criptografica a continutului.',
              style: Theme.of(context).textTheme.bodyMedium,
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
    required this.isError,
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
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _BackupCard extends StatelessWidget {
  final ContactBackup backup;
  final bool isBusy;
  final VoidCallback? onRestore;
  final VoidCallback onDelete;

  const _BackupCard({
    required this.backup,
    required this.isBusy,
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
    return AppCard(
      semanticLabel: backup.isValid
          ? 'Backup valid cu ${backup.contactCount} contacte, $scopeLabel'
          : 'Backup invalid, restaurarea este blocata',
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
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sterge backupul',
                onPressed: isBusy ? null : onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
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

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year}, $hour:$minute';
  }
}
