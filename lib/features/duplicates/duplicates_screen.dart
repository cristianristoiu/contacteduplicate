import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_router.dart';
import '../../core/contacts/contacts_scan_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_loading_indicator.dart';
import '../../shared/widgets/app_primary_button.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/contact_avatar.dart';
import '../dashboard/scan_controller.dart';

class DuplicatesScreen extends StatelessWidget {
  const DuplicatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScanController>();
    final groups = controller.result?.duplicateGroups ??
        const <DuplicateContactGroup>[];

    return AppScaffold(
      title: 'Duplicate',
      actions: <Widget>[
        IconButton(
          tooltip: 'Acasa',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
      ],
      child: switch (controller.status) {
        ScanStatus.scanning => const Center(
            child: AppLoadingIndicator(),
          ),
        ScanStatus.completed when controller.resultsStale => AppEmptyState(
            icon: Icons.sync_problem_rounded,
            title: 'Rezultatele trebuie actualizate',
            description:
                'Agenda s-a modificat dupa ultima scanare. Grupurile vechi sunt blocate pentru a evita folosirea unor date care nu mai corespund contactelor curente.',
            primaryButton: AppPrimaryButton(
              label: 'Rescaneaza agenda',
              icon: Icons.refresh_rounded,
              onPressed: () => unawaited(controller.scan()),
            ),
          ),
        ScanStatus.completed when groups.isEmpty => AppEmptyState(
            icon: Icons.verified_outlined,
            title: 'Nu au fost gasite duplicate exacte',
            description:
                'Au fost verificate ${controller.totalContacts} contacte. Potrivirile aproximative vor fi adaugate intr-o etapa separata.',
            primaryButton: AppPrimaryButton(
              label: 'Scaneaza din nou',
              icon: Icons.refresh_rounded,
              onPressed: () => unawaited(controller.scan()),
            ),
          ),
        ScanStatus.completed => _DuplicateGroupsList(
            groups: groups,
            limitedAccess: controller.result?.permissionState ==
                ContactsPermissionState.limited,
          ),
        _ => AppEmptyState(
            icon: Icons.people_alt_outlined,
            title: 'Nu exista rezultate de afisat',
            description:
                'Porneste o scanare din Dashboard pentru a identifica grupurile de contacte duplicate.',
            primaryButton: AppPrimaryButton(
              label: 'Mergi la Dashboard',
              icon: Icons.dashboard_outlined,
              onPressed: () => context.go(AppRoutes.dashboard),
            ),
          ),
      },
    );
  }
}

class _DuplicateGroupsList extends StatelessWidget {
  final List<DuplicateContactGroup> groups;
  final bool limitedAccess;

  const _DuplicateGroupsList({
    required this.groups,
    required this.limitedAccess,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: groups.length + (limitedAccess ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (limitedAccess && index == 0) {
          return AppCard(
            child: Text(
              'Rezultatele sunt calculate doar din contactele selectate in permisiunea limitata iOS.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        final groupIndex = limitedAccess ? index - 1 : index;
        return _DuplicateGroupCard(group: groups[groupIndex]);
      },
    );
  }
}

class _DuplicateGroupCard extends StatelessWidget {
  final DuplicateContactGroup group;

  const _DuplicateGroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final reasonLabels = group.reasons.map((reason) {
      return switch (reason) {
        DuplicateMatchReason.phone => 'telefon identic',
        DuplicateMatchReason.email => 'email identic',
      };
    }).join(' si ');

    return AppCard(
      semanticLabel:
          'Verifica grupul cu ${group.contacts.length} contacte duplicate',
      onTap: () => context.push(AppRoutes.duplicateDetails(group.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${group.contacts.length} contacte',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    'Scor ${group.confidenceScore}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Motiv: $reasonLabels',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ...group.contacts.map(
            (contact) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ContactPreview(contact: contact),
            ),
          ),
          Text(
            'Deschide grupul pentru comparare si pregatirea copiei consolidate. Stergerea contactelor sursa ramane blocata.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ContactPreview extends StatelessWidget {
  final ScannedContact contact;

  const _ContactPreview({required this.contact});

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      ...contact.phones,
      ...contact.emails,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ContactAvatar(name: contact.displayName, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                contact.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              if (details.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  details.join(' · '),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
