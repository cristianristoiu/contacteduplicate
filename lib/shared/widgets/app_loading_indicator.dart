import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AppLoadingIndicator extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;

  const AppLoadingIndicator({
    super.key,
    this.size = 40.0,
    this.strokeWidth = 4.0,
    this.color,
  });

  factory AppLoadingIndicator.small() => const AppLoadingIndicator(size: 20.0, strokeWidth: 2.0);
  factory AppLoadingIndicator.medium() => const AppLoadingIndicator(size: 40.0, strokeWidth: 4.0);
  factory AppLoadingIndicator.large() => const AppLoadingIndicator(size: 60.0, strokeWidth: 6.0);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? AppColors.blue500,
        ),
        backgroundColor: (color ?? AppColors.blue500).withOpacity(0.1),
      ),
    );
  }
}
