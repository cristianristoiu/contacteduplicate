import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_router.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_loading_indicator.dart';
import '../../shared/widgets/app_scaffold.dart';
import 'history_controller.dart';
import 'operation_history.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HistoryController>();
    return AppScaffold(
      title: 'Istoric operatii',
      actions: <Widget>[
        IconButton(
          tooltip: 'Reincarca istoricul',
          onPressed: controller.isLoading
              ? null
              : () => unawaited(controller.load()),
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Inchide istoricul',
          onPressed: () => context.go(AppRoutes.settings),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
      child: switch (controller.status) {
        HistoryControllerStatus.idle || HistoryControllerStatus.loading =>
          const Center(child: AppLoadingIndicator()),
        HistoryControllerStatus.error => _HistoryError(controller: controller),
        HistoryControllerStatus.ready => _HistoryContent(controller: controller),
      },
    );
  }
}

class _HistoryError extends StatelessWidget {
  final HistoryController controller;
  const _HistoryError({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.history_toggle_off_rounded,
      title: 'Istoricul nu poate fi citit',
      description:
          'Datele locale ale operatiilor nu au putut fi incarcate. Agenda nu este modificata de aceasta eroare.',
      primaryButton: FilledButton.icon(
        onPressed: () => unawaited(controller.load()),
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Reincearca'),
      ),
    );
  }
}

class _HistoryContent extends StatelessWidget {
  final HistoryController controller;
  const _HistoryContent({required this.controller});

  @override
  Widget build(BuildContext context) {
    final entries = controller.visibleEntries;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: <Widget>[
        _SummaryCard(controller: controller),
        const SizedBox(height: 16),
        _Filters(controller: controller),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          AppEmptyState(
            icon: Icons.manage_search_rounded,
            title: controller.hasFilters
                ? 'Nicio operatie nu corespunde filtrelor'
                : 'Istoricul este gol',
            description: controller.hasFilters
                ? 'Elimina filtrele pentru a vedea toate operatiile locale.'
                : 'Operatiile de fuziune, restaurare si undo vor aparea aici dupa executie.',
            primaryButton: controller.hasFilters
                ? FilledButton.icon(
                    onPressed: controller.clearFilters,
                    icon: const Icon(Icons.filter_alt_off_rounded),
                    label: const Text('Sterge filtrele'),
                  )
                : null,
          )
        else
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HistoryEntryCard(
                entry: entry,
                onDelete: entry.canUndo
                    ? null
                    : () => _confirmDelete(context, controller, entry),
              ),
            ),
          ),
        if (controller.entries.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: controller.isLoading
                ? null
                : () => _confirmClear(context, controller),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Curata istoricul finalizat'),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    HistoryController controller,
    OperationHistoryEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stergi aceasta intrare?'),
        content: const Text(
          'Se elimina doar inregistrarea locala din istoric. Contactele si backupurile nu sunt modificate.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Renunta'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sterge'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deleteEntry(entry.operationId);
    }
  }

  Future<void> _confirmClear(
    BuildContext context,
    HistoryController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cureti istoricul finalizat?'),
        content: const Text(
          'Intrarile care mai pot fi folosite pentru undo sunt pastrate automat.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Renunta'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Curata'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.clear(preserveUndoable: true);
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final HistoryController controller;
  const _SummaryCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      semanticLabel:
          '${controller.entries.length} operatii in istoric, ${controller.undoableCount} cu undo disponibil, ${controller.reconcileCount} necesita reconciliere',
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        children: <Widget>[
          _Metric(label: 'Total', value: controller.entries.length),
          _Metric(label: 'Undo', value: controller.undoableCount),
          _Metric(label: 'Reconciliere', value: controller.reconcileCount),
          _Metric(label: 'Esecuri', value: controller.failedCount),
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
          Text('$value', style: Theme.of(context).textTheme.headlineMedium),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final HistoryController controller;
  const _Filters({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Filtre',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (controller.hasFilters)
                TextButton(
                  onPressed: controller.clearFilters,
                  child: const Text('Reseteaza'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: OperationHistoryType.values
                .map(
                  (type) => FilterChip(
                    label: Text(_typeLabel(type)),
                    selected: controller.selectedTypes.contains(type),
                    onSelected: (selected) =>
                        controller.setTypeEnabled(type, selected),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: OperationHistoryOutcome.values
                .map(
                  (outcome) => FilterChip(
                    label: Text(_outcomeLabel(outcome)),
                    selected: controller.selectedOutcomes.contains(outcome),
                    onSelected: (selected) =>
                        controller.setOutcomeEnabled(outcome, selected),
                  ),
                )
                .toList(growable: false),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Doar operatii cu undo disponibil'),
            value: controller.undoableOnly,
            onChanged: controller.setUndoableOnly,
          ),
        ],
      ),
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  final OperationHistoryEntry entry;
  final VoidCallback? onDelete;

  const _HistoryEntryCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final localTime = entry.finishedAt.toLocal();
    final date = '${localTime.day.toString().padLeft(2, '0')}.'
        '${localTime.month.toString().padLeft(2, '0')}.${localTime.year} '
        '${localTime.hour.toString().padLeft(2, '0')}:'
        '${localTime.minute.toString().padLeft(2, '0')}';
    final summary = '${_typeLabel(entry.type)}, ${_outcomeLabel(entry.outcome)}, '
        '${entry.changedCount} schimbate, ${entry.skippedCount} omise';
    return AppCard(
      semanticLabel: '$summary, finalizata la $date'
          '${entry.canUndo ? ', undo disponibil' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(_typeIcon(entry.type)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _typeLabel(entry.type),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _OutcomeBadge(outcome: entry.outcome),
            ],
          ),
          const SizedBox(height: 10),
          Text(date, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            '${entry.sourceCount} surse · ${entry.changedCount} schimbate · ${entry.skippedCount} omise',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (entry.canUndo) ...<Widget>[
            const SizedBox(height: 10),
            const Row(
              children: <Widget>[
                Icon(Icons.undo_rounded, size: 18),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Backupul necesar pentru undo este protejat.',
                  ),
                ),
              ],
            ),
          ],
          if (entry.outcome == OperationHistoryOutcome.reconcile) ...<Widget>[
            const SizedBox(height: 10),
            const Text(
              'Starea finala trebuie reconciliata inainte de repetarea operatiei.',
            ),
          ],
          if (onDelete != null) ...<Widget>[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Sterge intrarea'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OutcomeBadge extends StatelessWidget {
  final OperationHistoryOutcome outcome;
  const _OutcomeBadge({required this.outcome});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Rezultat: ${_outcomeLabel(outcome)}',
      child: Chip(label: Text(_outcomeLabel(outcome))),
    );
  }
}

String _typeLabel(OperationHistoryType type) => switch (type) {
      OperationHistoryType.scan => 'Scanare',
      OperationHistoryType.merge => 'Fuziune',
      OperationHistoryType.restore => 'Restaurare',
      OperationHistoryType.undo => 'Undo',
    };

String _outcomeLabel(OperationHistoryOutcome outcome) => switch (outcome) {
      OperationHistoryOutcome.success => 'Reusita',
      OperationHistoryOutcome.partial => 'Partial',
      OperationHistoryOutcome.blocked => 'Blocata',
      OperationHistoryOutcome.failed => 'Esuata',
      OperationHistoryOutcome.cancelled => 'Anulata',
      OperationHistoryOutcome.reconcile => 'Reconciliere',
    };

IconData _typeIcon(OperationHistoryType type) => switch (type) {
      OperationHistoryType.scan => Icons.manage_search_rounded,
      OperationHistoryType.merge => Icons.merge_type_rounded,
      OperationHistoryType.restore => Icons.restore_rounded,
      OperationHistoryType.undo => Icons.undo_rounded,
    };
