import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_router.dart';
import '../../core/theme/theme_provider.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return AppScaffold(
      title: 'Setari',
      actions: <Widget>[
        IconButton(
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
                      label: Text('System'),
                    ),
                    ButtonSegment<AppThemeMode>(
                      value: AppThemeMode.light,
                      label: Text('Light'),
                    ),
                    ButtonSegment<AppThemeMode>(
                      value: AppThemeMode.dark,
                      label: Text('Dark'),
                    ),
                  ],
                  selected: <AppThemeMode>{themeProvider.mode},
                  onSelectionChanged: (Set<AppThemeMode> selection) {
                    themeProvider.setMode(selection.first);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Text(
              'Permisiunile pentru contacte vor fi cerute doar cand sunt necesare.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
