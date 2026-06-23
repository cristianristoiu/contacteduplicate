import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum AppIconButtonShape {
  circle,
  roundedRect,
}

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final AppIconButtonShape shape;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? iconColor;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.shape = AppIconButtonShape.circle,
    this.size = 40,
    this.iconSize = 22,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = shape == AppIconButtonShape.circle ? size / 2 : 12.0;
    final background = backgroundColor ?? (isDark ? AppColors.darkSurfaceMuted : AppColors.lightSurfaceMuted);
    final foreground = iconColor ?? AppColors.blue500;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
