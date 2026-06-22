import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AppDivider extends StatelessWidget {
  final double thickness;
  final double indent;
  final double endIndent;
  final Axis direction;
  final Color? color;

  const AppDivider({
    super.key,
    this.thickness = 1.0,
    this.indent = 0,
    this.endIndent = 0,
    this.direction = Axis.horizontal,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final defaultColor = Theme.of(context).brightness == Brightness.light
        ? AppColors.lightBorder
        : AppColors.darkBorder;

    if (direction == Axis.vertical) {
      return VerticalDivider(
        width: thickness,
        thickness: thickness,
        indent: indent,
        endIndent: endIndent,
        color: color ?? defaultColor,
      );
    }

    return Divider(
      height: thickness,
      thickness: thickness,
      indent: indent,
      endIndent: endIndent,
      color: color ?? defaultColor,
    );
  }
}
