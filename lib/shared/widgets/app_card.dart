import 'package:flutter/material.dart';

import '../../core/theme/app_shadows.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.gradient,
    this.isTransparent = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Gradient? gradient;
  final bool isTransparent;

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

    return Container(
      margin: margin,
      padding: padding,
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
      child: child,
    );
  }
}
