import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import 'app_empty_state.dart';
import 'app_primary_button.dart';

class SearchEmptyState extends StatelessWidget {
  final VoidCallback onReset;
  final String? title;
  final String? description;
  final String? resetLabel;
  final bool isFullWidthButton;

  const SearchEmptyState({
    super.key,
    required this.onReset,
    this.title,
    this.description,
    this.resetLabel,
    this.isFullWidthButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final normalizedTitle = _normalizedText(title);
    final normalizedDescription = _normalizedText(description);
    final normalizedResetLabel = _normalizedText(resetLabel);

    return AppEmptyState(
      icon: Icons.search_off_rounded,
      title: normalizedTitle ?? l10n.text('search_empty_title'),
      description: normalizedDescription ??
          l10n.text('search_empty_description'),
      primaryButton: AppPrimaryButton(
        label: normalizedResetLabel ?? l10n.text('reset_search'),
        icon: Icons.restart_alt_rounded,
        onPressed: onReset,
      ),
      isFullWidthButton: isFullWidthButton,
    );
  }

  String? _normalizedText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
