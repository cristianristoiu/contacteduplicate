import 'package:flutter/material.dart';

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
    final boxShadow = BoxShadow(
      color: Colors.black.withOpacity(
        theme.brightness == Brightness.dark ? 0.18 : 0.05,
      ),
      blurRadius: 18,
      offset: const Offset(0, 12),
    );

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: isTransparent || gradient != null
            ? null
            : theme.cardTheme.color ?? theme.colorScheme.surface,
        gradient: isTransparent ? null : gradient,
        borderRadius: borderRadius,
        border: isTransparent
            ? null
            : Border.all(
                color: theme.dividerTheme.color ??
                    theme.colorScheme.outlineVariant,
              ),
        boxShadow: isTransparent ? const <BoxShadow>[] : <BoxShadow>[boxShadow],
      ),
      child: child,
    );
  }
}
