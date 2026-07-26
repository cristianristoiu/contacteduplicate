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
import '../../shared/widgets/merge_field_row.dart';
import '../dashboard/scan_controller.dart';

class DuplicateDetailsScreen extends StatelessWidget {
  final String groupId;

  const DuplicateDetailsScreen({
    required this.groupId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScanController>();
    final group = _findGroup(
      controller.result?.duplicateGroups ??
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

    return AppScaffold(
      title: 'Verificare grup',
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
                    'Mod read-only: poti verifica diferentele, dar agenda nu poate fi modificata din acest ecran.',
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
            'Contacte incluse',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          ...group.contacts.map(
            (contact) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ContactDetailsCard(contact: contact),
            ),
          ),
          if (group.contacts.length >= 2) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Comparatii',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            for (var index = 1; index < group.contacts.length; index++) ...<Widget>[
              _ContactComparison(
                reference: group.contacts.first,
                candidate: group.contacts[index],
                candidateNumber: index + 1,
              ),
              if (index < group.contacts.length - 1)
                const SizedBox(height: 16),
            ],
          ],
          const SizedBox(height: 28),
          AppPrimaryButton(
            label: 'Fuziunea necesita backup',
            icon: Icons.lock_outline_rounded,
            onPressed: null,
          ),
          const SizedBox(height: 10),
          Text(
            'Fuziunea va fi activata numai dupa implementarea backup-ului validat si a previzualizarii datelor finale.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
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
            'Potrivire detectata prin ${reasons.join(' si ')}. Scorul este orientativ si nu autorizeaza automat o fuziune.',
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

class _ContactComparison extends StatelessWidget {
  final ScannedContact reference;
  final ScannedContact candidate;
  final int candidateNumber;

  const _ContactComparison({
    required this.reference,
    required this.candidate,
    required this.candidateNumber,
  });

  @override
  Widget build(BuildContext context) {
    final leftLabel = 'Contact 1';
    final rightLabel = 'Contact $candidateNumber';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '${reference.displayName} / ${candidate.displayName}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 10),
        MergeFieldRow(
          fieldLabel: 'Nume',
          leftLabel: leftLabel,
          leftValue: reference.displayName,
          rightLabel: rightLabel,
          rightValue: candidate.displayName,
        ),
        const SizedBox(height: 10),
        MergeFieldRow(
          fieldLabel: 'Telefon',
          leftLabel: leftLabel,
          leftValue: reference.phones.join(', '),
          rightLabel: rightLabel,
          rightValue: candidate.phones.join(', '),
        ),
        const SizedBox(height: 10),
        MergeFieldRow(
          fieldLabel: 'Email',
          leftLabel: leftLabel,
          leftValue: reference.emails.join(', '),
          rightLabel: rightLabel,
          rightValue: candidate.emails.join(', '),
        ),
      ],
    );
  }
}
