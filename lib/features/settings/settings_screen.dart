import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_router.dart';
import '../../core/theme/theme_provider.dart';
import '../../features/history/history_controller.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final history = context.watch<HistoryController>();

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
                    if (selection.isNotEmpty) {
                      themeProvider.setMode(selection.first);
                    }
                  },
                ),
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
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.privacy_tip_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Permisiunile pentru contacte sunt cerute doar cand sunt necesare. Istoricul pastreaza local doar metadate operationale si identificatori tehnici necesari pentru recuperare.',
                    style: Theme.of(context).textTheme.bodyMedium,
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
