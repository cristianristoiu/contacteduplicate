import 'dart:async';

import 'package:flutter/material.dart';

class AnimatedCard extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final Duration staggerDelay;
  final double verticalOffset;
  final bool enabled;

  const AnimatedCard({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 300),
    this.staggerDelay = const Duration(milliseconds: 50),
    this.verticalOffset = 20,
    this.enabled = true,
  })  : assert(index >= 0),
        assert(!duration.isNegative),
        assert(!staggerDelay.isNegative),
        assert(verticalOffset >= 0);

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _animation;
  Timer? _startTimer;
  bool _dependenciesConfigured = false;
  bool _hasStarted = false;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_dependenciesConfigured) {
      if (!_disableAnimations && disableAnimations) {
        _startTimer?.cancel();
        _animationController.value = 1;
        _hasStarted = true;
      }
      _disableAnimations = disableAnimations;
      return;
    }

    _dependenciesConfigured = true;
    _disableAnimations = disableAnimations;

    if (!widget.enabled || disableAnimations || widget.duration == Duration.zero) {
      _animationController.value = 1;
      _hasStarted = true;
      return;
    }

    _scheduleStart();
  }

  @override
  void didUpdateWidget(covariant AnimatedCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.duration != widget.duration) {
      _animationController.duration = widget.duration;
    }

    if (oldWidget.enabled && !widget.enabled) {
      _startTimer?.cancel();
      _animationController.value = 1;
      _hasStarted = true;
      return;
    }

    if (!oldWidget.enabled && widget.enabled && !_disableAnimations) {
      _animationController.value = 0;
      _hasStarted = false;
      _scheduleStart();
      return;
    }

    if (!_hasStarted &&
        (oldWidget.index != widget.index ||
            oldWidget.staggerDelay != widget.staggerDelay)) {
      _scheduleStart();
    }
  }

  void _scheduleStart() {
    _startTimer?.cancel();

    if (!widget.enabled || _disableAnimations || _hasStarted) {
      return;
    }

    final delay = Duration(
      microseconds: widget.staggerDelay.inMicroseconds * widget.index,
    );
    if (delay == Duration.zero) {
      _startAnimation();
      return;
    }

    _startTimer = Timer(delay, _startAnimation);
  }

  void _startAnimation() {
    if (!mounted || !widget.enabled || _disableAnimations || _hasStarted) {
      return;
    }

    _hasStarted = true;
    if (widget.duration == Duration.zero) {
      _animationController.value = 1;
      return;
    }

    _animationController.forward(from: 0);
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _disableAnimations) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        final progress = _animation.value;
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, widget.verticalOffset * (1 - progress)),
            child: child,
          ),
        );
      },
    );
  }
}
