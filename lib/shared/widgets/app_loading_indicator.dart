import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AppLoadingIndicator extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;
  final String semanticLabel;
  final String? semanticValue;

  const AppLoadingIndicator({
    super.key,
    this.size = 40.0,
    this.strokeWidth = 4.0,
    this.color,
    this.semanticLabel = 'Se incarca',
    this.semanticValue,
  })  : assert(size > 0),
        assert(strokeWidth > 0);

  factory AppLoadingIndicator.small() => const AppLoadingIndicator(
        size: 20.0,
        strokeWidth: 2.0,
      );
  factory AppLoadingIndicator.medium() => const AppLoadingIndicator(
        size: 40.0,
        strokeWidth: 4.0,
      );
  factory AppLoadingIndicator.large() => const AppLoadingIndicator(
        size: 60.0,
        strokeWidth: 6.0,
      );

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.blue500;
    return Semantics(
      label: semanticLabel,
      value: semanticValue,
      liveRegion: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: strokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
            backgroundColor: effectiveColor.withOpacity(0.1),
          ),
        ),
      ),
    );
  }
}
