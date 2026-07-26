import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class ProgressRing extends StatefulWidget {
  final double value;
  final double size;
  final double strokeWidth;
  final Duration animationDuration;
  final bool showPercentage;
  final Color? backgroundColor;
  final Gradient? progressGradient;
  final String? semanticLabel;

  const ProgressRing({
    super.key,
    required this.value,
    this.size = 80,
    this.strokeWidth = 8,
    this.animationDuration = const Duration(milliseconds: 600),
    this.showPercentage = true,
    this.backgroundColor,
    this.progressGradient,
    this.semanticLabel,
  })  : assert(value >= 0 && value <= 1),
        assert(size > 0),
        assert(strokeWidth > 0),
        assert(size > strokeWidth * 2),
        assert(!animationDuration.isNegative);

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  double _startValue = 0;
  late double _targetValue;
  bool _dependenciesConfigured = false;
  bool _disableAnimations = false;

  double get _displayedValue {
    final curvedProgress = Curves.easeOut.transform(
      _animationController.value,
    );
    return _startValue + (_targetValue - _startValue) * curvedProgress;
  }

  @override
  void initState() {
    super.initState();
    _targetValue = widget.value;
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_dependenciesConfigured) {
      if (!_disableAnimations && disableAnimations) {
        _animationController.stop();
        _startValue = widget.value;
        _targetValue = widget.value;
        _animationController.value = 1;
      }
      _disableAnimations = disableAnimations;
      return;
    }

    _dependenciesConfigured = true;
    _disableAnimations = disableAnimations;

    if (disableAnimations || widget.animationDuration == Duration.zero) {
      _startValue = widget.value;
      _targetValue = widget.value;
      _animationController.value = 1;
      return;
    }

    _animationController.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.animationDuration != widget.animationDuration) {
      _animationController.duration = widget.animationDuration;
    }

    if (oldWidget.value == widget.value) {
      if (widget.animationDuration == Duration.zero) {
        _animationController.stop();
        _startValue = widget.value;
        _targetValue = widget.value;
        _animationController.value = 1;
      }
      return;
    }

    final currentValue = _displayedValue;
    _startValue = currentValue;
    _targetValue = widget.value;

    if (_disableAnimations || widget.animationDuration == Duration.zero) {
      _startValue = widget.value;
      _animationController.stop();
      _animationController.value = 1;
      return;
    }

    _animationController.forward(from: 0);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedBackgroundColor = widget.backgroundColor ??
        (isDark ? AppColors.darkBorder : AppColors.lightBorder);
    final resolvedGradient =
        widget.progressGradient ?? AppColors.brandGradient;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        final value = _displayedValue.clamp(0.0, 1.0).toDouble();
        final percentage = (value * 100).round();

        return Semantics(
          container: true,
          label: widget.semanticLabel,
          value: '$percentage%',
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: SizedBox.square(
                dimension: widget.size,
                child: Stack(
                  alignment: Alignment.center,
                  fit: StackFit.expand,
                  children: <Widget>[
                    CustomPaint(
                      painter: _ProgressRingPainter(
                        value: value,
                        strokeWidth: widget.strokeWidth,
                        backgroundColor: resolvedBackgroundColor,
                        progressGradient: resolvedGradient,
                      ),
                    ),
                    if (widget.showPercentage)
                      Center(
                        child: SizedBox.square(
                          dimension: math.max(
                            0.0,
                            widget.size - widget.strokeWidth * 2 - 8,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$percentage%',
                              maxLines: 1,
                              style: AppTextStyles.h2.copyWith(
                                color: Color.lerp(
                                  AppColors.error,
                                  AppColors.success,
                                  value,
                                ),
                                fontFeatures: const <FontFeature>[
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
