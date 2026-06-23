import 'package:flutter/material.dart';

import '../../app/router/app_router.dart';

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
    return SafeArea(
      top: false,
      child: NavigationBar(
        height: 64,
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
    );
  }
}
