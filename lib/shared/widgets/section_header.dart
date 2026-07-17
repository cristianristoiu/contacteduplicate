import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final int titleMaxLines;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionPressed,
    this.titleMaxLines = 1,
  }) : assert(titleMaxLines > 0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final normalizedActionLabel = actionLabel?.trim();
    final hasAction = normalizedActionLabel != null &&
        normalizedActionLabel.isNotEmpty &&
        onActionPressed != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          flex: 3,
          child: Semantics(
            header: true,
            child: Text(
              title,
              maxLines: titleMaxLines,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.h2.copyWith(
                fontSize: 20,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ),
        if (hasAction) ...<Widget>[
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: TextButton(
              onPressed: onActionPressed,
              style: TextButton.styleFrom(
                foregroundColor:
                    isDark ? AppColors.blue500 : AppColors.blue600,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerRight,
              ),
              child: Text(
                normalizedActionLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
