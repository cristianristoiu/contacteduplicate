import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../core/l10n/app_localizations.dart';
import '../../shared/widgets/app_loading_indicator.dart';
import '../../shared/widgets/app_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _sequenceDuration = Duration(milliseconds: 2200);

  late final AnimationController _animationController;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentOffset;
  late final Animation<double> _indicatorOpacity;
  bool _started = false;
  bool _navigationScheduled = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: _sequenceDuration,
    )..addStatusListener(_handleAnimationStatus);

    _logoOpacity = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0, 0.36, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0, 0.36, curve: Curves.easeOutBack),
      ),
    );
    _contentOpacity = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.36, 0.68, curve: Curves.easeOut),
    );
    _contentOffset = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.36, 0.68, curve: Curves.easeOut),
      ),
    );
    _indicatorOpacity = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.68, 0.82, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_started) {
      return;
    }

    _started = true;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      _animationController.value = 1;
      _scheduleNavigation();
      return;
    }

    _animationController.forward();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _scheduleNavigation();
    }
  }

  void _scheduleNavigation() {
    if (_navigationScheduled) {
      return;
    }

    _navigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go(AppRoutes.dashboard);
      }
    });
  }

  @override
  void dispose() {
    _animationController
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FadeTransition(
                opacity: _logoOpacity,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: const AppLogo(size: 180),
                ),
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _contentOpacity,
                child: SlideTransition(
                  position: _contentOffset,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        l10n.text('app_title'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.text('dashboard_subtitle'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _indicatorOpacity,
                child: AppLoadingIndicator.small(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
