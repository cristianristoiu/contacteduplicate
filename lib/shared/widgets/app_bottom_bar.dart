import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/router/app_router.dart';
import '../../core/theme/app_colors.dart';

class AppBottomBarItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  const AppBottomBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}

class AppBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<AppBottomBarItem> onItemSelected;
  final List<AppBottomBarItem> items;

  const AppBottomBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
    this.items = defaultItems,
  });

  static const List<AppBottomBarItem> defaultItems = <AppBottomBarItem>[
    AppBottomBarItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Acasa',
      route: AppRoutes.dashboard,
    ),
    AppBottomBarItem(
      icon: Icons.people_alt_outlined,
      activeIcon: Icons.people_alt_rounded,
      label: 'Duplicate',
      route: '/duplicates',
    ),
    AppBottomBarItem(
      icon: Icons.backup_outlined,
      activeIcon: Icons.backup_rounded,
      label: 'Backup',
      route: '/backup',
    ),
    AppBottomBarItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Setari',
      route: AppRoutes.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkSurface : AppColors.lightSurface).withOpacity(0.82),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.28 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: NavigationBar(
                height: 64,
                backgroundColor: Colors.transparent,
                indicatorColor: AppColors.blue500.withOpacity(isDark ? 0.22 : 0.12),
                selectedIndex: currentIndex,
                destinations: items.map((item) {
                  return NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.activeIcon),
                    label: item.label,
                  );
                }).toList(growable: false),
                onDestinationSelected: (index) => onItemSelected(items[index]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
