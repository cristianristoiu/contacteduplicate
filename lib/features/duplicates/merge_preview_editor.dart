import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_secondary_button.dart';
import '../../shared/widgets/contact_avatar.dart';
import 'merge_detail_controller.dart';

class MergePreviewEditor extends StatelessWidget {
  const MergePreviewEditor({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MergeDetailController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Construieste rezultatul final',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Selectiile modifica doar previzualizarea. Agenda dispozitivului ramane neschimbata.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _MasterSelection(controller: controller),
        const SizedBox(height: 16),
        const _FinalNameField(),
        const SizedBox(height: 16),
        _ValueSelectionCard(
          title: 'Telefoane pastrate',
          emptyMessage: 'Contactele nu contin numere de telefon.',
          icon: Icons.phone_outlined,
          options: controller.phoneOptions,
          selectedIds: controller.selectedPhoneIds,
          onChanged: controller.setPhoneSelected,
        ),
        const SizedBox(height: 16),
        _ValueSelectionCard(
          title: 'Emailuri pastrate',
          emptyMessage: 'Contactele nu contin adrese de email.',
          icon: Icons.email_outlined,
          options: controller.emailOptions,
          selectedIds: controller.selectedEmailIds,
          onChanged: controller.setEmailSelected,
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: AppSecondaryButton(
                label: 'Pastreaza toate',
                icon: Icons.select_all_rounded,
                onPressed: controller.keepAllValues,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppSecondaryButton(
                label: 'Reseteaza',
                icon: Icons.restart_alt_rounded,
                onPressed: controller.resetToSafeDefault,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _LivePreview(controller: controller),
        if (!controller.isValid) ...<Widget>[
          const SizedBox(height: 16),
          _ValidationCard(messages: controller.validationMessages),
        ],
      ],
    );
  }
}

class _MasterSelection extends StatelessWidget {
  final MergeDetailController controller;

  const _MasterSelection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Sursa principala pentru nume',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Schimbarea sursei selecteaza initial valorile acelui contact. Poti adauga apoi orice valoare din celelalte surse.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: controller.contacts.map((contact) {
              final selected =
                  contact.nativeId == controller.masterContactId;
              return ChoiceChip(
                selected: selected,
                avatar: ContactAvatar(
                  name: contact.displayName,
                  size: 28,
                ),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    contact.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                onSelected: selected
                    ? null
                    : (_) => controller.selectMaster(contact.nativeId),
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _FinalNameField extends StatefulWidget {
  const _FinalNameField();

  @override
  State<_FinalNameField> createState() => _FinalNameFieldState();
}

class _FinalNameFieldState extends State<_FinalNameField> {
  final FocusNode _focusNode = FocusNode();
  late final TextEditingController _textController;
  MergeDetailController? _mergeController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<MergeDetailController>();
    if (!identical(controller, _mergeController)) {
      _mergeController?.removeListener(_synchronizeText);
      _mergeController = controller;
      controller.addListener(_synchronizeText);
      _replaceText(controller.displayName);
    }
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) {
      _synchronizeText();
    }
  }

  void _synchronizeText() {
    final controller = _mergeController;
    if (controller == null || _focusNode.hasFocus) {
      return;
    }
    if (_textController.text != controller.displayName) {
      _replaceText(controller.displayName);
    }
  }

  void _replaceText(String value) {
    _textController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  void dispose() {
    _mergeController?.removeListener(_synchronizeText);
    _focusNode.removeListener(_handleFocusChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: TextField(
        controller: _textController,
        focusNode: _focusNode,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        maxLength: 160,
        decoration: const InputDecoration(
          labelText: 'Numele final',
          helperText: 'Poti corecta manual numele rezultat.',
          prefixIcon: Icon(Icons.badge_outlined),
        ),
        onChanged: context.read<MergeDetailController>().updateDisplayName,
      ),
    );
  }
}

class _ValueSelectionCard extends StatelessWidget {
  final String title;
  final String emptyMessage;
  final IconData icon;
  final List<MergeValueOption> options;
  final Set<String> selectedIds;
  final void Function(String optionId, bool selected) onChanged;

  const _ValueSelectionCard({
    required this.title,
    required this.emptyMessage,
    required this.icon,
    required this.options,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: <Widget>[
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
          if (options.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                emptyMessage,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            ...options.map((option) {
              final sourceCount = option.sourceContactIds.length;
              return CheckboxListTile(
                value: selectedIds.contains(option.id),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(option.value),
                subtitle: Text(
                  sourceCount == 1
                      ? 'Prezenta intr-un contact'
                      : 'Prezenta in $sourceCount contacte',
                ),
                onChanged: (selected) {
                  if (selected != null) {
                    onChanged(option.id, selected);
                  }
                },
              );
            }),
        ],
      ),
    );
  }
}

class _LivePreview extends StatelessWidget {
  final MergeDetailController controller;

  const _LivePreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final draft = controller.draft;
    final name = draft.displayName.isEmpty ? 'Nume necompletat' : draft.displayName;

    return AppCard(
      semanticLabel: 'Previzualizarea contactului final',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Previzualizare finala',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ContactAvatar(name: name, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    _PreviewValues(
                      icon: Icons.phone_outlined,
                      values: draft.phones,
                      emptyLabel: 'Niciun telefon selectat',
                    ),
                    const SizedBox(height: 6),
                    _PreviewValues(
                      icon: Icons.email_outlined,
                      values: draft.emails,
                      emptyLabel: 'Niciun email selectat',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewValues extends StatelessWidget {
  final IconData icon;
  final List<String> values;
  final String emptyLabel;

  const _PreviewValues({
    required this.icon,
    required this.values,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            values.isEmpty ? emptyLabel : values.join('\n'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _ValidationCard extends StatelessWidget {
  final List<String> messages;

  const _ValidationCard({required this.messages});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: messages
                  .map(
                    (message) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}
