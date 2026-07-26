import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;
  final bool autofocus;

  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveThumbColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final inactiveTrackColor =
        isDark ? AppColors.darkSurfaceMuted : AppColors.lightSurfaceMuted;

    final switchWidget = Switch.adaptive(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.blue500,
      activeTrackColor: AppColors.blue500.withOpacity(0.4),
      inactiveThumbColor: inactiveThumbColor,
      inactiveTrackColor: inactiveTrackColor,
      autofocus: autofocus,
    );

    final normalizedLabel = semanticLabel?.trim();
    if (normalizedLabel == null || normalizedLabel.isEmpty) {
      return switchWidget;
    }

    return Semantics(
      label: normalizedLabel,
      child: switchWidget,
    );
  }
}
