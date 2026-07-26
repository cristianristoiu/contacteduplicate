import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_router.dart';
import '../../core/contacts/contacts_scan_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_primary_button.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_secondary_button.dart';
import 'scan_controller.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scanController = context.watch<ScanController>();

    return AppScaffold(
      actions: <Widget>[
        IconButton(
          tooltip: l10n.text('settings'),
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
          _DuplicateSummaryCard(controller: scanController),
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: scanController.isScanning
                ? 'Se scaneaza contactele'
                : l10n.text('scan_contacts'),
            icon: Icons.manage_search,
            isLoading: scanController.isScanning,
            onPressed: scanController.isScanning
                ? null
                : () => unawaited(_startScan(context)),
          ),
          if (scanController.status == ScanStatus.permissionDenied) ...<Widget>[
            const SizedBox(height: 16),
            _PermissionMessage(controller: scanController),
          ],
          if (scanController.status == ScanStatus.error) ...<Widget>[
            const SizedBox(height: 16),
            AppCard(
              child: Text(
                'Scanarea nu a putut fi finalizata. Reincearca dupa ce verifici permisiunea pentru contacte.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
          if (scanController.result?.permissionState ==
              ContactsPermissionState.limited) ...<Widget>[
            const SizedBox(height: 16),
            AppCard(
              child: Text(
                'iOS permite accesul doar la contactele selectate. Rezultatele includ exclusiv acele contacte.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
          const SizedBox(height: 12),
          AppSecondaryButton(
            label: l10n.text('view_duplicates'),
            icon: Icons.group_outlined,
            onPressed: () => context.go(AppRoutes.duplicates),
          ),
          const SizedBox(height: 20),
          AppCard(
            semanticLabel: l10n.text('backup_contacts'),
            onTap: () => context.go(AppRoutes.backup),
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

  Future<void> _startScan(BuildContext context) async {
    final controller = context.read<ScanController>();
    await controller.scan();
    if (!context.mounted) {
      return;
    }

    if (controller.status == ScanStatus.completed) {
      context.go(AppRoutes.duplicates);
    }
  }
}

class _PermissionMessage extends StatelessWidget {
  final ScanController controller;

  const _PermissionMessage({required this.controller});

  @override
  Widget build(BuildContext context) {
    final permissionState = controller.result?.permissionState;
    final requiresSettings = permissionState ==
            ContactsPermissionState.permanentlyDenied ||
        permissionState == ContactsPermissionState.restricted;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Accesul la contacte nu este disponibil.',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(
            requiresSettings
                ? 'Activeaza accesul din setarile sistemului pentru a putea scana agenda.'
                : 'Acorda permisiunea cand sistemul o solicita pentru a putea scana agenda.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (requiresSettings) ...<Widget>[
            const SizedBox(height: 12),
            AppSecondaryButton(
              label: 'Deschide setarile',
              icon: Icons.settings_outlined,
              onPressed: () => unawaited(controller.openAppSettings()),
            ),
          ],
        ],
      ),
    );
  }
}

class _DuplicateSummaryCard extends StatelessWidget {
  final ScanController controller;

  const _DuplicateSummaryCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isScanning = controller.isScanning;
    final groupCount = controller.duplicateGroupCount;
    final totalContacts = controller.totalContacts;
    final summary = switch (controller.status) {
      ScanStatus.idle => 'Scaneaza agenda pentru a vedea rezultatele.',
      ScanStatus.scanning => 'Contactele sunt citite si comparate local.',
      ScanStatus.completed => groupCount == 0
          ? 'Nu au fost gasite duplicate exacte in $totalContacts contacte.'
          : 'Au fost gasite $groupCount grupuri in $totalContacts contacte.',
      ScanStatus.permissionDenied =>
        'Scanarea necesita acces la contactele dispozitivului.',
      ScanStatus.error => 'Ultima scanare nu a putut fi finalizata.',
    };

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
                  value: isScanning ? null : 0,
                  strokeWidth: 18,
                  backgroundColor: Theme.of(context).dividerTheme.color,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '$groupCount',
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      Text(
                        groupCount == 1 ? 'grup duplicat' : 'grupuri duplicate',
                        textAlign: TextAlign.center,
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
            summary,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
