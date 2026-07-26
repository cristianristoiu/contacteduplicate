import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

class BadgeCount extends StatefulWidget {
  final int count;
  final int maxCount;
  final double minSize;
  final bool hideWhenZero;
  final Duration animationDuration;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? semanticLabel;

  const BadgeCount({
    super.key,
    required this.count,
    this.maxCount = 99,
    this.minSize = 20,
    this.hideWhenZero = true,
    this.animationDuration = const Duration(milliseconds: 220),
    this.backgroundColor,
    this.foregroundColor,
    this.semanticLabel,
  })  : assert(count >= 0),
        assert(maxCount > 0),
        assert(minSize >= 20),
        assert(!animationDuration.isNegative);

  @override
  State<BadgeCount> createState() => _BadgeCountState();
}

class _BadgeCountState extends State<BadgeCount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  bool get _isVisible => !widget.hideWhenZero || widget.count > 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    if (_isVisible) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant BadgeCount oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.animationDuration != widget.animationDuration) {
      _animationController.duration = widget.animationDuration;
    }

    final wasVisible = !oldWidget.hideWhenZero || oldWidget.count > 0;
    if (!wasVisible && _isVisible) {
      _animationController.forward(from: 0);
    } else if (wasVisible && !_isVisible) {
      _animationController.value = 0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    final label = widget.count > widget.maxCount
        ? '${widget.maxCount}+'
        : widget.count.toString();
    final badge = Semantics(
      container: true,
      liveRegion: true,
      label: widget.semanticLabel ?? widget.count.toString(),
      child: ExcludeSemantics(
        child: Container(
          constraints: BoxConstraints(
            minWidth: widget.minSize,
            minHeight: widget.minSize,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: label.length > 2 ? AppSpacing.xs + 2 : 0,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? AppColors.error,
            borderRadius: BorderRadius.circular(widget.minSize / 2),
          ),
          child: Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: widget.foregroundColor ?? Colors.white,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations || widget.animationDuration == Duration.zero) {
      return badge;
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: badge,
    );
  }
}
