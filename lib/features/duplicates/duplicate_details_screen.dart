import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_router.dart';
import '../../core/contacts/contacts_scan_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_primary_button.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/contact_avatar.dart';
import '../backup/backup_merge_gate.dart';
import '../dashboard/scan_controller.dart';
import 'contact_copy_action.dart';
import 'merge_detail_controller.dart';
import 'merge_preview_editor.dart';

class DuplicateDetailsScreen extends StatelessWidget {
  final String groupId;

  const DuplicateDetailsScreen({
    required this.groupId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scanController = context.watch<ScanController>();
    final group = _findGroup(
      scanController.result?.duplicateGroups ??
          const <DuplicateContactGroup>[],
      groupId,
    );

    if (group == null) {
      return AppScaffold(
        title: 'Verificare grup',
        child: AppEmptyState(
          icon: Icons.search_off_rounded,
          title: 'Grupul nu mai este disponibil',
          description:
              'Rezultatele s-au schimbat sau aplicatia a fost repornita. Porneste o scanare noua pentru a continua.',
          primaryButton: AppPrimaryButton(
            label: 'Inapoi la duplicate',
            icon: Icons.arrow_back_rounded,
            onPressed: () => context.go(AppRoutes.duplicates),
          ),
        ),
      );
    }

    return ChangeNotifierProvider<MergeDetailController>(
      key: ValueKey<String>(group.id),
      create: (_) => MergeDetailController(group),
      child: _DuplicateDetailsContent(group: group),
    );
  }

  DuplicateContactGroup? _findGroup(
    List<DuplicateContactGroup> groups,
    String id,
  ) {
    for (final group in groups) {
      if (group.id == id) {
        return group;
      }
    }
    return null;
  }
}

class _DuplicateDetailsContent extends StatelessWidget {
  final DuplicateContactGroup group;

  const _DuplicateDetailsContent({required this.group});

  @override
  Widget build(BuildContext context) {
    final mergeController = context.watch<MergeDetailController>();
    final selectedValueCount = mergeController.selectedPhones.length +
        mergeController.selectedEmails.length;
    final sourceContactIds = group.contacts
        .map((contact) => contact.nativeId)
        .toList(growable: false);

    return AppScaffold(
      title: 'Previzualizare fuziune',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        children: <Widget>[
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.visibility_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Mod de previzualizare: poti alege campurile rezultatului, dar nicio selectie nu modifica agenda dispozitivului.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _GroupSummary(group: group),
          const SizedBox(height: 24),
          Text(
            'Contacte sursa',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          ...group.contacts.map(
            (contact) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ContactDetailsCard(contact: contact),
            ),
          ),
          const SizedBox(height: 12),
          const MergePreviewEditor(),
          const SizedBox(height: 28),
          BackupMergeGate(
            previewValid: mergeController.isValid,
            sourceContactCount: group.contacts.length,
            selectedValueCount: selectedValueCount,
            sourceContactIds: sourceContactIds,
          ),
          ContactCopyAction(sourceContactIds: sourceContactIds),
        ],
      ),
    );
  }
}

class _GroupSummary extends StatelessWidget {
  final DuplicateContactGroup group;

  const _GroupSummary({required this.group});

  @override
  Widget build(BuildContext context) {
    final reasons = <String>[
      if (group.reasons.contains(DuplicateMatchReason.phone))
        'telefon identic',
      if (group.reasons.contains(DuplicateMatchReason.email))
        'email identic',
    ];
    final reasonSummary =
        reasons.isEmpty ? 'date identice' : reasons.join(' si ');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${group.contacts.length} contacte in grup',
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
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Potrivire detectata prin $reasonSummary. Scorul este orientativ si nu autorizeaza automat o fuziune.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ContactDetailsCard extends StatelessWidget {
  final ScannedContact contact;

  const _ContactDetailsCard({required this.contact});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ContactAvatar(name: contact.displayName, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  contact.displayName,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ContactValues(
            icon: Icons.phone_outlined,
            emptyLabel: 'Fara telefon',
            values: contact.phones,
          ),
          const SizedBox(height: 10),
          _ContactValues(
            icon: Icons.email_outlined,
            emptyLabel: 'Fara email',
            values: contact.emails,
          ),
        ],
      ),
    );
  }
}

class _ContactValues extends StatelessWidget {
  final IconData icon;
  final String emptyLabel;
  final List<String> values;

  const _ContactValues({
    required this.icon,
    required this.emptyLabel,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    final text = values.isEmpty ? emptyLabel : values.join('\n');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SelectableText(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
