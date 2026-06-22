import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../core/l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_primary_button.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_secondary_button.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppScaffold(
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.go(AppRoutes.settings),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text(
            l10n.text('dashboard_title'),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.text('dashboard_subtitle'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          const _DuplicateSummaryCard(),
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: l10n.text('scan_contacts'),
            icon: Icons.manage_search,
            onPressed: () {},
          ),
          const SizedBox(height: 12),
          AppSecondaryButton(
            label: l10n.text('view_duplicates'),
            icon: Icons.group_outlined,
            onPressed: () {},
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.text('backup_contacts'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Backup-ul va fi creat inainte de orice modificare reala.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DuplicateSummaryCard extends StatelessWidget {
  const _DuplicateSummaryCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: <Widget>[
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CircularProgressIndicator(
                  value: 0.38,
                  strokeWidth: 18,
                  backgroundColor: Theme.of(context).dividerTheme.color,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '0',
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      Text(
                        'duplicate',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Scaneaza agenda pentru a vedea rezultatele.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
