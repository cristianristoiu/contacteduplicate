import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/onboarding/onboarding_preferences.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_loading_indicator.dart';
import '../../shared/widgets/app_logo.dart';

class SplashScreen extends StatefulWidget {
  final OnboardingPreferences? preferences;
  const SplashScreen({this.preferences, super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _animationDuration = Duration(milliseconds: 700);
  static const Duration _minimumVisibleDuration = Duration(milliseconds: 350);

  late final AnimationController _animationController;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final OnboardingPreferences _preferences;
  DateTime? _startedAt;
  bool _loading = true;
  String? _errorCode;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _preferences = widget.preferences ?? OnboardingPreferences();
    _animationController = AnimationController(vsync: this, duration: _animationDuration);
    _logoOpacity = CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
    _logoScale = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedAt != null) return;
    _startedAt = DateTime.now();
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      _animationController.value = 1;
    } else {
      unawaited(_animationController.forward());
    }
    unawaited(_resolveDestination());
  }

  Future<void> _resolveDestination() async {
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _loading = true;
        _errorCode = null;
      });
    }
    final result = await _preferences.read();
    if (!mounted || generation != _loadGeneration) return;
    if (!result.isReliable) {
      setState(() {
        _loading = false;
        _errorCode = result.errorCode ?? 'onboarding_read_failed';
      });
      return;
    }
    final startedAt = _startedAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(startedAt);
    final remaining = _minimumVisibleDuration - elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    if (!mounted || generation != _loadGeneration) return;
    context.go(result.completed ? AppRoutes.dashboard : AppRoutes.onboarding);
  }

  @override
  void dispose() {
    _loadGeneration++;
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_errorCode != null) {
      return Scaffold(
        body: SafeArea(
          child: AppErrorState(
            title: 'Initializarea nu a putut fi verificata',
            message: 'Preferintele locale nu au putut fi citite in siguranta. Reincearca fara a presupune ca onboardingul este finalizat.',
            onRetry: () => unawaited(_resolveDestination()),
            retryLabel: 'Reincearca initializarea',
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Semantics(
            liveRegion: _loading,
            label: _loading ? 'Aplicatia se initializeaza' : null,
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
                const SizedBox(height: 24),
                if (_loading) AppLoadingIndicator.small(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
