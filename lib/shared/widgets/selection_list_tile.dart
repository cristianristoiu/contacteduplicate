import 'package:flutter/material.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

class SelectionListTile extends StatelessWidget {
  final String value;
  final String label;
  final bool selected;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry padding;

  const SelectionListTile({
    super.key,
    required this.value,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
  })  : assert(value.trim().isNotEmpty),
        assert(label.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onChanged != null;
    final primaryTextColor = theme.brightness == Brightness.dark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondaryTextColor = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final borderColor = theme.brightness == Brightness.dark
        ? AppColors.darkBorder
        : AppColors.lightBorder;
    final selectedColor = AppColors.blue500.withOpacity(
      theme.brightness == Brightness.dark ? 0.14 : 0.08,
    );

    void changeSelection(bool newValue) {
      AppHaptics.selection();
      onChanged?.call(newValue);
    }

    void toggle() {
      changeSelection(!selected);
    }

    return Semantics(
      container: true,
      checked: selected,
      enabled: enabled,
      label: '${label.trim()}: ${value.trim()}',
      onTap: enabled ? toggle : null,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Material(
            color: selected ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: enabled ? toggle : null,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: padding,
                  child: Row(
                    children: <Widget>[
                      Checkbox(
                        value: selected,
                        onChanged: enabled
                            ? (isSelected) {
                                if (isSelected != null) {
                                  changeSelection(isSelected);
                                }
                              }
                            : null,
                        activeColor: AppColors.blue500,
                        checkColor: AppColors.navy950,
                        side: BorderSide(
                          color: selected ? AppColors.blue500 : borderColor,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              value,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyStrong.copyWith(
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
