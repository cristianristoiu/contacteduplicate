import 'package:flutter/material.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/theme/app_colors.dart';

enum AppIconButtonShape { circle, roundedRect }

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final AppIconButtonShape shape;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? iconColor;
  final String? tooltip;
  final String? semanticLabel;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.shape = AppIconButtonShape.circle,
    this.size = 48,
    this.iconSize = 22,
    this.backgroundColor,
    this.iconColor,
    this.tooltip,
    this.semanticLabel,
  })  : assert(size >= 44),
        assert(iconSize > 0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveSize = size < 48 ? 48.0 : size;
    final radius = shape == AppIconButtonShape.circle ? effectiveSize / 2 : 12.0;
    final callback = onPressed;
    final background = backgroundColor ??
        (isDark ? AppColors.darkSurfaceMuted : AppColors.lightSurfaceMuted);
    final foreground = iconColor ?? AppColors.blue500;
    final tooltipText = tooltip?.trim() ?? '';
    final semanticText = semanticLabel?.trim().isNotEmpty == true
        ? semanticLabel!.trim()
        : tooltipText.isNotEmpty
            ? tooltipText
            : 'Actiune';
    final button = Semantics(
      button: true,
      enabled: callback != null,
      label: semanticText,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: callback == null ? 0.5 : 1,
          child: Material(
            color: background,
            borderRadius: BorderRadius.circular(radius),
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              splashColor: AppColors.blue500.withOpacity(0.1),
              highlightColor: AppColors.blue500.withOpacity(0.08),
              canRequestFocus: callback != null,
              mouseCursor: callback == null
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              onTap: callback == null
                  ? null
                  : () {
                      AppHaptics.selection();
                      callback();
                    },
              child: SizedBox(
                width: effectiveSize,
                height: effectiveSize,
                child: Center(
                  child: Icon(icon, size: iconSize, color: foreground),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (tooltipText.isEmpty) return button;
    return Tooltip(message: tooltipText, child: button);
  }
}
