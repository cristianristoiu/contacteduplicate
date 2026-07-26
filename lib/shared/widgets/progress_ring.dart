import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double strokeWidth;
  final Color? backgroundColor;
  final Gradient? progressGradient;
  final String? semanticLabel;

  const ProgressRing({
    super.key,
    required this.value,
    this.size = 80,
    this.strokeWidth = 8,
    this.backgroundColor,
    this.progressGradient,
    this.semanticLabel,
  })  : assert(value >= 0 && value <= 1),
        assert(size > 0),
        assert(strokeWidth > 0),
        assert(size > strokeWidth * 2);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedBackgroundColor = backgroundColor ??
        (isDark ? AppColors.darkBorder : AppColors.lightBorder);
    final resolvedGradient = progressGradient ?? AppColors.brandGradient;
    final percentage = (value * 100).round();

    return Semantics(
      container: true,
      label: semanticLabel,
      value: '$percentage%',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.square(size),
            painter: _ProgressRingPainter(
              value: value,
              strokeWidth: strokeWidth,
              backgroundColor: resolvedBackgroundColor,
              progressGradient: resolvedGradient,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double value;
  final double strokeWidth;
  final Color backgroundColor;
  final Gradient progressGradient;

  const _ProgressRingPainter({
    required this.value,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressGradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    if (value == 0) {
      return;
    }

    final progressPaint = Paint()
      ..shader = progressGradient.createShader(arcRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return value != oldDelegate.value ||
        strokeWidth != oldDelegate.strokeWidth ||
        backgroundColor != oldDelegate.backgroundColor ||
        progressGradient != oldDelegate.progressGradient;
  }
}
