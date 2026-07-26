import 'package:flutter/material.dart';

import '../../core/platform/app_haptics.dart';

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final callback = onPressed == null
        ? null
        : () {
            AppHaptics.selection();
            onPressed?.call();
          };
    final style = OutlinedButton.styleFrom(
      foregroundColor: colorScheme.primary,
      minimumSize: const Size.fromHeight(52),
      side: BorderSide(color: colorScheme.primary.withOpacity(0.35)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );

    final buttonIcon = icon;
    if (buttonIcon == null) {
      return OutlinedButton(
        onPressed: callback,
        style: style,
        child: Text(label),
      );
    }

    return OutlinedButton.icon(
      onPressed: callback,
      icon: Icon(buttonIcon, size: 20),
      label: Text(label),
      style: style,
    );
  }
}
