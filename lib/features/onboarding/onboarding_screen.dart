import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../core/onboarding/onboarding_preferences.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/app_primary_button.dart';

class OnboardingScreen extends StatefulWidget {
  final OnboardingPreferences? preferences;

  const OnboardingScreen({
    this.preferences,
    super.key,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final OnboardingPreferences _preferences;
  bool _isSaving = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _preferences = widget.preferences ?? OnboardingPreferences();
  }

  Future<void> _completeOnboarding() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
      _hasError = false;
    });

    try {
      await _preferences.markCompleted();
      if (!mounted) {
        return;
      }
      context.go(AppRoutes.dashboard);
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          children: <Widget>[
            const Center(child: AppLogo(size: 112)),
            const SizedBox(height: 28),
            Text(
              'Curata agenda in siguranta',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Aplicatia compara contactele direct pe dispozitiv si iti arata doar potrivirile care trebuie verificate.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            const _OnboardingItem(
              icon: Icons.lock_outline_rounded,
              title: 'Datele raman pe dispozitiv',
              description:
                  'Numele, telefoanele si adresele de email nu sunt incarcate in cloud si nu sunt trimise unui server.',
            ),
            const SizedBox(height: 14),
            const _OnboardingItem(
              icon: Icons.contact_phone_outlined,
              title: 'Tu controlezi permisiunea',
              description:
                  'Accesul la contacte este cerut de sistem doar cand pornesti prima scanare.',
            ),
            const SizedBox(height: 14),
            const _OnboardingItem(
              icon: Icons.fact_check_outlined,
              title: 'Scanarea nu modifica agenda',
              description:
                  'In aceasta etapa aplicatia doar citeste si compara datele. Niciun contact nu este editat sau sters.',
            ),
            if (_hasError) ...<Widget>[
              const SizedBox(height: 16),
              AppCard(
                child: Text(
                  'Preferinta nu a putut fi salvata. Reincearca pentru a continua.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            AppPrimaryButton(
              label: 'Continua',
              icon: Icons.arrow_forward_rounded,
              isLoading: _isSaving,
              onPressed: _isSaving
                  ? null
                  : () {
                      unawaited(_completeOnboarding());
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Text(description, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
