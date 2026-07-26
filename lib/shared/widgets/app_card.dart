import 'package:flutter/material.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/theme/app_shadows.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.gradient,
    this.isTransparent = false,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Gradient? gradient;
  final bool isTransparent;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(24);
    final baseSurface =
        theme.cardTheme.color ?? theme.colorScheme.surface;
    final elevatedSurface = AppBoxShadows.elevatedSurface(
      baseSurface,
      theme.brightness,
    );
    final callback = onTap;
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: isTransparent || gradient != null ? null : elevatedSurface,
        gradient: isTransparent ? null : gradient,
        borderRadius: borderRadius,
        border: isTransparent
            ? null
            : Border.all(
                color: theme.dividerTheme.color ??
                    theme.colorScheme.outlineVariant,
              ),
        boxShadow: isTransparent
            ? const <BoxShadow>[]
            : AppBoxShadows.soft(theme.brightness),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: callback == null
                ? null
                : () {
                    AppHaptics.selection();
                    callback();
                  },
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );

    if (callback == null && semanticLabel == null) {
      return card;
    }

    return Semantics(
      container: true,
      button: callback != null,
      label: semanticLabel,
      child: card,
    );
  }
}
