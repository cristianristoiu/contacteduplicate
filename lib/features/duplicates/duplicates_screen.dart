import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_router.dart';
import '../../core/contacts/contact_models.dart';
import '../../core/contacts/contacts_scan_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_loading_indicator.dart';
import '../../shared/widgets/app_primary_button.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/contact_avatar.dart';
import '../dashboard/scan_controller.dart';
import 'duplicate_list_controller.dart';

class DuplicatesScreen extends StatefulWidget {
  const DuplicatesScreen({super.key});

  @override
  State<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends State<DuplicatesScreen> {
  late final DuplicateListController _listController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  int? _boundRevision;

  @override
  void initState() {
    super.initState();
    _listController = DuplicateListController();
    unawaited(_listController.initialize());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scan = context.watch<ScanController>();
    final busy = scan.isScanning || scan.resultsStale;
    if (_boundRevision != scan.scanRevision) {
      _boundRevision = scan.scanRevision;
      _listController.replaceDataset(
        scan.result?.duplicateGroups ?? const <DuplicateContactGroup>[],
        scanRevision: scan.scanRevision,
        accessScope: scan.accessScope,
        busy: busy,
      );
    } else {
      _listController.setDatasetBusy(busy);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanController>();

    return AppScaffold(
      title: 'Duplicate',
      actions: <Widget>[
        IconButton(
          tooltip: 'Acasa',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
      ],
      child: switch (scan.status) {
        ScanStatus.scanning => const Center(child: AppLoadingIndicator()),
        ScanStatus.completed when scan.resultsStale => AppEmptyState(
            icon: Icons.sync_problem_rounded,
            title: 'Rezultatele trebuie actualizate',
            description:
                'Agenda s-a modificat dupa ultima scanare. Grupurile vechi sunt blocate pana la o scanare noua.',
            primaryButton: AppPrimaryButton(
              label: 'Rescaneaza agenda',
              icon: Icons.refresh_rounded,
              onPressed: () => unawaited(scan.scan()),
            ),
          ),
        ScanStatus.completed when scan.duplicateGroupCount == 0 => AppEmptyState(
            icon: Icons.verified_outlined,
            title: 'Nu au fost gasite duplicate',
            description:
                'Au fost verificate ${scan.totalContacts} contacte folosind potriviri exacte si semnale de nume/companie.',
            primaryButton: AppPrimaryButton(
              label: 'Scaneaza din nou',
              icon: Icons.refresh_rounded,
              onPressed: () => unawaited(scan.scan()),
            ),
          ),
        ScanStatus.completed => ChangeNotifierProvider<DuplicateListController>.value(
            value: _listController,
            child: _DuplicateBrowser(
              scanRevision: scan.scanRevision,
              onRefresh: scan.scan,
              searchController: _searchController,
              searchFocus: _searchFocus,
            ),
          ),
        ScanStatus.cancelled => AppEmptyState(
            icon: Icons.cancel_outlined,
            title: 'Scanarea a fost anulata',
            description: 'Porneste o scanare noua pentru a reface lista de duplicate.',
            primaryButton: AppPrimaryButton(
              label: 'Scaneaza din nou',
              icon: Icons.refresh_rounded,
              onPressed: () => unawaited(scan.scan()),
            ),
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

class _DuplicateBrowser extends StatelessWidget {
  final int scanRevision;
  final Future<void> Function() onRefresh;
  final TextEditingController searchController;
  final FocusNode searchFocus;

  const _DuplicateBrowser({
    required this.scanRevision,
    required this.onRefresh,
    required this.searchController,
    required this.searchFocus,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DuplicateListController>();
    final groups = controller.visibleGroups;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          if (controller.limitedAccess) ...<Widget>[
            const AppCard(
              child: Text(
                'Rezultatele provin doar din subsetul de contacte permis de iOS. Numaratorile nu reprezinta intreaga agenda.',
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (controller.persistenceFailed) ...<Widget>[
            AppCard(
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Lista grupurilor ignorate nu a putut fi persistata local.',
                    ),
                  ),
                  TextButton(
                    onPressed: controller.loadingIgnored
                        ? null
                        : () => unawaited(controller.retryIgnoredPersistence()),
                    child: const Text('Reincearca'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: searchController,
            focusNode: searchFocus,
            enabled: !controller.datasetBusy,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Cauta in duplicate',
              hintText: 'Nume, telefon, email sau companie',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Sterge cautarea',
                      onPressed: () {
                        searchController.clear();
                        controller.clearQuery();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            onChanged: controller.updateQuery,
            onSubmitted: (_) => controller.submitQuery(),
          ),
          const SizedBox(height: 12),
          _Filters(controller: controller),
          const SizedBox(height: 12),
          _Summary(controller: controller),
          if (controller.hasSelection) ...<Widget>[
            const SizedBox(height: 12),
            _BulkSelection(controller: controller),
          ],
          const SizedBox(height: 16),
          if (groups.isEmpty)
            AppEmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: 'Niciun grup pentru filtrele curente',
              description:
                  'Modifica filtrele sau cautarea. Scanarea originala ramane neschimbata.',
              primaryButton: controller.hasActiveFilters
                  ? AppPrimaryButton(
                      label: 'Reseteaza filtrele',
                      icon: Icons.restart_alt_rounded,
                      onPressed: controller.clearFilters,
                    )
                  : null,
            )
          else
            ...groups.map(
              (group) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _DuplicateGroupCard(
                  group: group,
                  scanRevision: scanRevision,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final DuplicateListController controller;

  const _Filters({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilterChip(
                label: const Text('Sigur'),
                selected: controller.filter.confidence ==
                    DuplicateConfidenceFilter.safe,
                onSelected: controller.datasetBusy
                    ? null
                    : (selected) => controller.setConfidenceFilter(
                          selected
                              ? DuplicateConfidenceFilter.safe
                              : DuplicateConfidenceFilter.all,
                        ),
              ),
              FilterChip(
                label: const Text('Probabil'),
                selected: controller.filter.confidence ==
                    DuplicateConfidenceFilter.probable,
                onSelected: controller.datasetBusy
                    ? null
                    : (selected) => controller.setConfidenceFilter(
                          selected
                              ? DuplicateConfidenceFilter.probable
                              : DuplicateConfidenceFilter.all,
                        ),
              ),
              FilterChip(
                label: const Text('Revizuire manuala'),
                selected: controller.filter.confidence ==
                    DuplicateConfidenceFilter.manualReview,
                onSelected: controller.datasetBusy
                    ? null
                    : (selected) => controller.setConfidenceFilter(
                          selected
                              ? DuplicateConfidenceFilter.manualReview
                              : DuplicateConfidenceFilter.all,
                        ),
              ),
              FilterChip(
                label: const Text('Doar eligibile'),
                selected: controller.filter.mergeableOnly,
                onSelected: controller.datasetBusy
                    ? null
                    : controller.setMergeableOnly,
              ),
              FilterChip(
                label: const Text('Arata ignorate'),
                selected: controller.filter.includeIgnored,
                onSelected: controller.datasetBusy
                    ? null
                    : controller.setIncludeIgnored,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DuplicateMatchReason.values.map((reason) {
              return FilterChip(
                label: Text(_reasonLabel(reason)),
                selected: controller.filter.reasons.contains(reason),
                onSelected: controller.datasetBusy
                    ? null
                    : (selected) =>
                        controller.setReasonEnabled(reason, selected),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<DuplicateSortMode>(
            value: controller.sortMode,
            decoration: const InputDecoration(labelText: 'Sortare'),
            onChanged: controller.datasetBusy
                ? null
                : (value) {
                    if (value != null) controller.setSortMode(value);
                  },
            items: const <DropdownMenuItem<DuplicateSortMode>>[
              DropdownMenuItem(
                value: DuplicateSortMode.confidenceDesc,
                child: Text('Scor descrescator'),
              ),
              DropdownMenuItem(
                value: DuplicateSortMode.contactCountDesc,
                child: Text('Numar contacte'),
              ),
              DropdownMenuItem(
                value: DuplicateSortMode.nameAsc,
                child: Text('Nume'),
              ),
              DropdownMenuItem(
                value: DuplicateSortMode.reason,
                child: Text('Motiv'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final DuplicateListController controller;

  const _Summary({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${controller.visibleCount} din ${controller.totalCount} grupuri · '
      '${controller.mergeableCount} eligibile · '
      '${controller.manualReviewCount} necesita verificare · '
      '${controller.overlappingCount} suprapuse',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class _BulkSelection extends StatelessWidget {
  final DuplicateListController controller;

  const _BulkSelection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '${controller.selectedCount} grupuri selectate. Selectia exclude automat grupurile suprapuse si scorurile sub 95.',
            ),
          ),
          TextButton(
            onPressed: controller.datasetBusy ? null : controller.clearSelection,
            child: const Text('Goleste'),
          ),
        ],
      ),
    );
  }
}

class _DuplicateGroupCard extends StatelessWidget {
  final DuplicateContactGroup group;
  final int scanRevision;

  const _DuplicateGroupCard({
    required this.group,
    required this.scanRevision,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DuplicateListController>();
    final ignored = controller.isIgnored(group);
    final selected = controller.selectedGroupIds.contains(group.id);
    final previewContacts = group.contacts.take(4).toList(growable: false);
    final remaining = group.contacts.length - previewContacts.length;
    final reasons = group.reasons.map(_reasonLabel).toList()..sort();

    return AppCard(
      semanticLabel:
          'Verifica grupul cu ${group.contacts.length} contacte duplicate',
      onTap: controller.canOpenDetails(group)
          ? () => context.push(
                AppRoutes.duplicateDetails(
                  group.id,
                  scanRevision: scanRevision,
                ),
              )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${group.contacts.length} contacte',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reasons.join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Chip(label: Text('Scor ${group.confidenceScore}')),
            ],
          ),
          if (group.overlapsAnotherGroup) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Acest grup imparte cel putin un contact cu alt grup. Operatiile bulk sunt blocate.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
          if (!group.canBeMerged) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Fuziunea distructiva nu este eligibila inca pentru acest grup. Verificarea manuala ramane disponibila.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          ...previewContacts.map(
            (contact) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ContactPreview(contact: contact),
            ),
          ),
          if (remaining > 0)
            Text(
              '+ $remaining contacte in acest grup',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (!ignored)
                FilterChip(
                  label: const Text('Selecteaza bulk'),
                  selected: selected,
                  onSelected: controller.datasetBusy
                      ? null
                      : (_) => controller.toggleSelection(group),
                ),
              TextButton.icon(
                onPressed: controller.datasetBusy
                    ? null
                    : () => unawaited(
                          ignored
                              ? controller.restoreIgnoredGroup(group)
                              : controller.ignoreGroup(group),
                        ),
                icon: Icon(
                  ignored
                      ? Icons.undo_rounded
                      : Icons.visibility_off_outlined,
                ),
                label: Text(ignored ? 'Restaureaza' : 'Ignora'),
              ),
            ],
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
    final record = contact.record;
    final details = <String>[
      ...?record?.phones.take(2).map((value) => value.displayValue),
      ...?record?.emails.take(2).map((value) => value.displayValue),
      if ((record?.primaryCompany ?? '').isNotEmpty) record!.primaryCompany,
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

String _reasonLabel(DuplicateMatchReason reason) {
  return switch (reason) {
    DuplicateMatchReason.phone => 'Telefon',
    DuplicateMatchReason.email => 'Email',
    DuplicateMatchReason.name => 'Nume',
    DuplicateMatchReason.company => 'Companie',
  };
}
