import 'package:go_router/go_router.dart';

import '../../features/backup/backup_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/duplicates/duplicate_details_screen.dart';
import '../../features/duplicates/duplicates_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splash/splash_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String dashboard = '/dashboard';
  static const String duplicates = '/duplicates';
  static const String backup = '/backup';
  static const String settings = '/settings';

  static String duplicateDetails(String groupId) {
    return '$duplicates/${Uri.encodeComponent(groupId)}';
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
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
      builder: (context, state) => DuplicateDetailsScreen(
        groupId: state.pathParameters['groupId'] ?? '',
      ),
    ),
    GoRoute(
      path: AppRoutes.backup,
      builder: (context, state) => const BackupScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
