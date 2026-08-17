import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_router.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_loading_indicator.dart';
import '../../shared/widgets/app_primary_button.dart';
import '../../shared/widgets/app_scaffold.dart';
import 'restore_controller.dart';
import 'restore_service.dart';

class RestoreScreen extends StatefulWidget {
  final String backupId;

  const RestoreScreen({required this.backupId, super.key});

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  bool _previewScheduled = false;
  RestoreConflictPolicy _policy = RestoreConflictPolicy.block;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_previewScheduled) return;
    _previewScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = context.read<RestoreController>();
      if (!controller.isBusy && !controller.requiresReconcile) {
        unawaited(
          controller.prepare(
            backupId: widget.backupId,
            mode: RestoreMode.full,
            conflictPolicy: _policy,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RestoreController>();
    return AppScaffold(
      title: 'Restaurare backup',
      actions: <Widget>[
        IconButton(
          tooltip: 'Inchide restaurarea',
          onPressed: controller.isBusy
              ? null
              : () => context.go(AppRoutes.backup),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
      child: _buildContent(context, controller),
    );
  }

  Widget _buildContent(BuildContext context, RestoreController controller) {
    if (controller.status == RestoreControllerStatus.previewing) {
      return const Center(
        child: Semantics(
          liveRegion: true,
          label: 'Se verifica backupul pentru restaurare',
          child: AppLoadingIndicator(),
        ),
      );
    }

    if (controller.status == RestoreControllerStatus.restoring) {
      return _RestoreRunning(controller: controller);
    }

    if (controller.requiresReconcile) {
      return _ReconcileState(
        onClose: () => context.go(AppRoutes.backup),
      );
    }

    final preview = controller.preview;
    if (preview == null) {
      return AppEmptyState(
        icon: Icons.restore_page_outlined,
        title: 'Backupul nu poate fi pregatit',
        description:
            'Restaurarea nu porneste pana cand backupul nu poate fi citit si verificat complet.',
        primaryButton: AppPrimaryButton(
          label: 'Reincearca verificarea',
          icon: Icons.refresh_rounded,
          onPressed: controller.isBusy
              ? null
              : () => unawaited(_prepare(controller)),
        ),
        isFullWidthButton: true,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: <Widget>[
        const _SafetyNotice(),
        const SizedBox(height: 16),
        _PreviewSummary(preview: preview),
        const SizedBox(height: 16),
        _ConflictPolicyCard(
          policy: _policy,
          enabled: !controller.isBusy,
          onChanged: (policy) {
            if (policy == _policy) return;
            setState(() => _policy = policy);
            unawaited(_prepare(controller));
          },
        ),
        if (preview.hasConflicts && _policy == RestoreConflictPolicy.block) ...<Widget>[
          const SizedBox(height: 16),
          const _WarningCard(
            icon: Icons.gpp_bad_outlined,
            message:
                'Exista contacte care s-au schimbat fata de backup. Politica actuala blocheaza restaurarea pentru a evita suprascrierea starii curente.',
          ),
        ],
        if (preview.invalidCount > 0) ...<Widget>[
          const SizedBox(height: 16),
          _WarningCard(
            icon: Icons.rule_folder_outlined,
            message:
                '${preview.invalidCount} intrari din backup sunt invalide si nu vor fi restaurate.',
          ),
        ],
        if (controller.historyWriteFailed) ...<Widget>[
          const SizedBox(height: 16),
          const _WarningCard(
            icon: Icons.history_toggle_off_rounded,
            message:
                'Ultimul rezultat a fost aplicat, dar istoricul local nu a putut fi actualizat. Nu repeta operatia doar din acest motiv.',
          ),
        ],
        const SizedBox(height: 20),
        if (controller.status == RestoreControllerStatus.success ||
            controller.status == RestoreControllerStatus.partial) ...<Widget>[
          _ResultCard(controller: controller),
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: 'Revino la backupuri',
            icon: Icons.check_circle_outline_rounded,
            onPressed: () => context.go(AppRoutes.backup),
          ),
        ] else ...<Widget>[
          AppPrimaryButton(
            label: preview.hasWork
                ? 'Continua spre confirmare'
                : 'Nu exista contacte de restaurat',
            icon: Icons.restore_rounded,
            onPressed: controller.canExecute
                ? () => unawaited(_confirmAndRestore(controller))
                : null,
          ),
          const SizedBox(height: 10),
          Text(
            'Permisiunea de scriere este ceruta numai dupa confirmarea explicita. Restaurarea nu sterge contactele existente.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Future<RestorePreview?> _prepare(RestoreController controller) {
    return controller.prepare(
      backupId: widget.backupId,
      mode: RestoreMode.full,
      conflictPolicy: _policy,
    );
  }

  Future<void> _confirmAndRestore(RestoreController controller) async {
    final preview = controller.preview;
    if (preview == null || !controller.canExecute) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurezi contactele lipsa?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${preview.restoreCount} contacte sunt pregatite pentru recreare. ${preview.skipCount} vor fi omise.',
              ),
              if (preview.conflictCount > 0) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  '${preview.conflictCount} conflicte vor fi tratate conform politicii selectate.',
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Aplicatia va cere acces de scriere, va crea numai contactele aprobate si va verifica fiecare rezultat. Contactele existente nu sunt sterse.',
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
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Restaureaza'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await controller.executeConfirmed();
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      semanticLabel:
          'Restaurarea este non-distructiva si verifica fiecare contact creat',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.shield_outlined),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Backupul este recitit inainte de operatie. Contactele recreate sunt reverificate, iar o stare incerta opreste fluxul pentru reconciliere.',
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewSummary extends StatelessWidget {
  final RestorePreview preview;
  const _PreviewSummary({required this.preview});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      semanticLabel:
          '${preview.restoreCount} de restaurat, ${preview.skipCount} omise, ${preview.conflictCount} conflicte, ${preview.invalidCount} invalide',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Previzualizare verificata',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: <Widget>[
              _Counter(label: 'De restaurat', value: preview.restoreCount),
              _Counter(label: 'Omise', value: preview.skipCount),
              _Counter(label: 'Conflicte', value: preview.conflictCount),
              _Counter(label: 'Invalide', value: preview.invalidCount),
            ],
          ),
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final String label;
  final int value;
  const _Counter({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('$value', style: Theme.of(context).textTheme.headlineMedium),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ConflictPolicyCard extends StatelessWidget {
  final RestoreConflictPolicy policy;
  final bool enabled;
  final ValueChanged<RestoreConflictPolicy> onChanged;

  const _ConflictPolicyCard({
    required this.policy,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Conflicte cu agenda curenta',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          RadioGroup<RestoreConflictPolicy>(
            groupValue: policy,
            onChanged: enabled
                ? (value) {
                    if (value != null) onChanged(value);
                  }
                : null,
            child: const Column(
              children: <Widget>[
                RadioListTile<RestoreConflictPolicy>(
                  contentPadding: EdgeInsets.zero,
                  value: RestoreConflictPolicy.block,
                  title: Text('Blocheaza la conflict'),
                  subtitle: Text('Cea mai conservatoare optiune.'),
                ),
                RadioListTile<RestoreConflictPolicy>(
                  contentPadding: EdgeInsets.zero,
                  value: RestoreConflictPolicy.skipExisting,
                  title: Text('Omite contactele existente'),
                  subtitle: Text('Nu modifica nicio intrare deja prezenta.'),
                ),
                RadioListTile<RestoreConflictPolicy>(
                  contentPadding: EdgeInsets.zero,
                  value: RestoreConflictPolicy.restoreMissingOnly,
                  title: Text('Restaureaza numai lipsurile'),
                  subtitle: Text('Recreeaza doar contactele care nu mai exista.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestoreRunning extends StatelessWidget {
  final RestoreController controller;
  const _RestoreRunning({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          liveRegion: true,
          label: 'Restaurarea este in curs',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const AppLoadingIndicator(),
              const SizedBox(height: 20),
              Text(
                'Se restaureaza si se verifica contactele',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                controller.canCancel
                    ? 'Operatia poate fi oprita inaintea urmatoarei sectiuni critice.'
                    : 'Sectiunea curenta este critica si nu poate fi intrerupta in siguranta.',
                textAlign: TextAlign.center,
              ),
              if (controller.canCancel) ...<Widget>[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: controller.requestCancel,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Opreste in siguranta'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReconcileState extends StatelessWidget {
  final VoidCallback onClose;
  const _ReconcileState({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.sync_problem_rounded,
      title: 'Starea trebuie reconciliata',
      description:
          'Operatia a ajuns intr-o stare care nu poate fi clasificata sigur. Nu repeta restaurarea pana cand starea agendei este reverificata.',
      primaryButton: AppPrimaryButton(
        label: 'Inchide fara retry',
        icon: Icons.close_rounded,
        onPressed: onClose,
      ),
      isFullWidthButton: true,
    );
  }
}

class _ResultCard extends StatelessWidget {
  final RestoreController controller;
  const _ResultCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final report = controller.report;
    if (report == null) return const SizedBox.shrink();
    return AppCard(
      semanticLabel:
          'Restaurare finalizata: ${report.restoredIds.length} restaurate, ${report.skippedIds.length} omise',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            controller.status == RestoreControllerStatus.success
                ? 'Restaurare finalizata'
                : 'Restaurare finalizata partial',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${report.restoredIds.length} contacte recreate si verificate. ${report.skippedIds.length} omise.',
          ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _WarningCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
