import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/onboarding/onboarding_preferences.dart';
import '../../features/backup/backup_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/duplicates/duplicate_details_screen.dart';
import '../../features/duplicates/duplicates_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/restore/restore_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../shared/widgets/app_error_state.dart';

class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String dashboard = '/dashboard';
  static const String duplicates = '/duplicates';
  static const String backup = '/backup';
  static const String settings = '/settings';
  static const String history = '/history';
  static const String restore = '/restore';

  static String duplicateDetails(String groupId, {int? scanRevision}) {
    final encoded = Uri.encodeComponent(groupId.trim());
    final base = '$duplicates/$encoded';
    return scanRevision == null ? base : '$base?scanRevision=$scanRevision';
  }

  static String restoreBackup(String backupId) =>
      '$restore?backupId=${Uri.encodeQueryComponent(backupId.trim())}';

  static bool isValidBackupId(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    return trimmed.isNotEmpty &&
        trimmed.length <= 32 &&
        RegExp(r'^[1-9][0-9]*$').hasMatch(trimmed);
  }

  static bool isValidGroupId(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 128) return false;
    return RegExp(r'^group-[a-f0-9]{16,64}$').hasMatch(trimmed);
  }

  static int? parseScanRevision(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = int.tryParse(value);
    return parsed != null && parsed >= 0 ? parsed : null;
  }
}

final OnboardingPreferences _routerOnboardingPreferences = OnboardingPreferences();

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  redirect: (context, state) async {
    final location = state.matchedLocation;
    if (location == AppRoutes.splash) return null;
    final onboarding = await _routerOnboardingPreferences.read();
    if (!onboarding.isReliable) {
      return location == AppRoutes.onboarding ? null : AppRoutes.splash;
    }
    if (!onboarding.completed && location != AppRoutes.onboarding) {
      return AppRoutes.onboarding;
    }
    if (onboarding.completed && location == AppRoutes.onboarding) {
      return AppRoutes.dashboard;
    }
    return null;
  },
  errorBuilder: (context, state) => Scaffold(
    body: SafeArea(
      child: AppErrorState(
        title: 'Ruta nu este disponibila',
        message:
            'Ecranul solicitat nu poate fi deschis in starea curenta a aplicatiei.',
        onRetry: () => context.go(AppRoutes.dashboard),
      ),
    ),
  ),
  routes: <RouteBase>[
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: AppRoutes.duplicates,
      builder: (context, state) => const DuplicatesScreen(),
    ),
    GoRoute(
      path: '${AppRoutes.duplicates}/:groupId',
      redirect: (context, state) {
        final groupId = state.pathParameters['groupId'];
        if (!AppRoutes.isValidGroupId(groupId)) return AppRoutes.duplicates;
        final rawRevision = state.uri.queryParameters['scanRevision'];
        if (rawRevision != null &&
            AppRoutes.parseScanRevision(rawRevision) == null) {
          return AppRoutes.duplicates;
        }
        return null;
      },
      builder: (context, state) => DuplicateDetailsScreen(
        groupId: state.pathParameters['groupId']!.trim(),
        expectedScanRevision: AppRoutes.parseScanRevision(
          state.uri.queryParameters['scanRevision'],
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.backup,
      builder: (context, state) => const BackupScreen(),
    ),
    GoRoute(
      path: AppRoutes.restore,
      redirect: (context, state) =>
          AppRoutes.isValidBackupId(state.uri.queryParameters['backupId'])
              ? null
              : AppRoutes.backup,
      builder: (context, state) => RestoreScreen(
        backupId: state.uri.queryParameters['backupId']!.trim(),
      ),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.history,
      builder: (context, state) => const HistoryScreen(),
    ),
  ],
);
