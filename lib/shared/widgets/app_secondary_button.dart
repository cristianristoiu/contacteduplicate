import 'package:flutter/material.dart';

import '../../core/platform/app_haptics.dart';

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final accessibleLabel = semanticLabel?.trim().isNotEmpty == true
        ? semanticLabel!.trim()
        : label.trim();
    final callback = !enabled
        ? null
        : () {
            AppHaptics.selection();
            onPressed?.call();
          };
    final style = OutlinedButton.styleFrom(
      foregroundColor: colorScheme.primary,
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      side: BorderSide(color: colorScheme.primary.withOpacity(0.35)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
    final labelWidget = Flexible(
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final child = icon == null
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[labelWidget],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              labelWidget,
            ],
          );

    return Semantics(
      button: true,
      enabled: enabled,
      label: accessibleLabel,
      child: ExcludeSemantics(
        child: OutlinedButton(
          onPressed: callback,
          style: style,
          child: child,
        ),
      ),
    );
  }
}
