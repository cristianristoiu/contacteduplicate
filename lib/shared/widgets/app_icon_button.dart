import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final String? tooltip;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.shape = AppIconButtonShape.circle,
    this.size = 40,
    this.iconSize = 22,
    this.backgroundColor,
    this.iconColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = shape == AppIconButtonShape.circle ? size / 2 : 12.0;
    final callback = onPressed;
    final background = backgroundColor ?? (isDark ? AppColors.darkSurfaceMuted : AppColors.lightSurfaceMuted);
    final foreground = iconColor ?? AppColors.blue500;
    final button = Semantics(
      button: true,
      enabled: callback != null,
      label: tooltip,
      child: Opacity(
        opacity: callback == null ? 0.5 : 1,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            splashColor: AppColors.blue500.withOpacity(0.1),
            highlightColor: AppColors.blue500.withOpacity(0.08),
            onTap: callback == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    callback();
                  },
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: Icon(
                  icon,
                  size: iconSize,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) {
      return button;
    }

    return Tooltip(
      message: tooltip!,
      child: button,
    );
  }
}
