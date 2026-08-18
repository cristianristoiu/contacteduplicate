import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_router.dart';
import '../../app/runtime/operation_coordinator.dart';
import '../../app/runtime/release_readiness.dart';
import '../../core/theme/theme_provider.dart';
import '../../features/backup/backup_controller.dart';
import '../../features/dashboard/scan_controller.dart';
import '../../features/duplicates/merge_operation_controller.dart';
import '../../features/history/history_controller.dart';
import '../../features/restore/restore_controller.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final history = context.watch<HistoryController>();
    final evaluator = const ReleaseReadinessEvaluator();
    final readiness = evaluator.evaluate(
      coordinator: context.watch<OperationCoordinator>(),
      scan: context.watch<ScanController>(),
      merge: context.watch<MergeOperationController>(),
      restore: context.watch<RestoreController>(),
      backup: context.watch<BackupController>(),
      history: history,
      theme: themeProvider,
    );

    return AppScaffold(
      title: 'Setari',
      actions: <Widget>[
        IconButton(
          tooltip: 'Inchide setarile',
          icon: const Icon(Icons.close),
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          _ReadinessCard(readiness: readiness, evaluator: evaluator),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Tema aplicatiei',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                SegmentedButton<AppThemeMode>(
                  segments: const <ButtonSegment<AppThemeMode>>[
                    ButtonSegment<AppThemeMode>(
                      value: AppThemeMode.system,
                      label: Text('Sistem'),
                    ),
                    ButtonSegment<AppThemeMode>(
                      value: AppThemeMode.light,
                      label: Text('Luminoasa'),
                    ),
                    ButtonSegment<AppThemeMode>(
                      value: AppThemeMode.dark,
                      label: Text('Intunecata'),
                    ),
                  ],
                  selected: <AppThemeMode>{themeProvider.mode},
                  onSelectionChanged: (Set<AppThemeMode> selection) {
                    if (selection.isNotEmpty) themeProvider.setMode(selection.first);
                  },
                ),
                if (themeProvider.persistenceStatus == ThemePersistenceStatus.saving) ...<Widget>[
                  const SizedBox(height: 12),
                  const Semantics(
                    liveRegion: true,
                    child: Text('Se salveaza preferinta de tema...'),
                  ),
                ],
                if (themeProvider.hasPersistenceError) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'Tema este aplicata pentru sesiunea curenta, dar preferinta nu a putut fi salvata.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            semanticLabel:
                'Istoric local: ${history.entries.length} operatii, ${history.undoableCount} cu undo disponibil',
            onTap: () => context.push(AppRoutes.history),
            child: Row(
              children: <Widget>[
                const Icon(Icons.history_rounded),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Istoric operatii',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        history.status == HistoryControllerStatus.error
                            ? 'Istoricul local nu a putut fi citit.'
                            : history.status == HistoryControllerStatus.loading
                                ? 'Se incarca istoricul local.'
                                : '${history.entries.length} operatii · ${history.undoableCount} cu undo disponibil',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.privacy_tip_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Permisiunile pentru contacte sunt cerute doar cand sunt necesare. Istoricul pastreaza local doar metadate operationale si identificatori tehnici necesari pentru recuperare.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  final ReleaseReadinessSnapshot readiness;
  final ReleaseReadinessEvaluator evaluator;

  const _ReadinessCard({required this.readiness, required this.evaluator});

  @override
  Widget build(BuildContext context) {
    final ready = readiness.isReadyForDeviceValidation;
    final blockers = readiness.blockers.toList()
      ..sort((left, right) => left.index.compareTo(right.index));
    return Semantics(
      container: true,
      liveRegion: true,
      label: ready
          ? 'Stare tehnica locala pregatita pentru validare pe dispozitiv'
          : '${readiness.blockerCount} blocaje tehnice locale necesita rezolvare inainte de validare',
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  ready ? Icons.verified_outlined : Icons.rule_folder_outlined,
                  color: ready
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ready ? 'Stare locala coerenta' : 'Stare locala de reconciliat',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ready
                  ? 'Nu exista operatii active, stari de reconciliere sau dependente locale cunoscute care sa invalideze o sesiune de test pe dispozitiv.'
                  : 'Aceasta verificare nu inlocuieste buildul si testarea pe dispozitive reale. Ea blocheaza doar declararea prematura a unei stari locale coerente.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!ready) ...<Widget>[
              const SizedBox(height: 12),
              ...blockers.map(
                (blocker) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.circle, size: 8),
                      const SizedBox(width: 8),
                      Expanded(child: Text(evaluator.label(blocker))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
