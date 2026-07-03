import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PrimaryBottomNavigation extends StatelessWidget {
  const PrimaryBottomNavigation({
    required this.currentSection,
    super.key,
  });

  final String currentSection;

  static const List<_Destination> _destinations = <_Destination>[
    _Destination(
      section: 'food',
      route: '/food',
      label: 'Alimentazione',
      icon: Icons.restaurant_menu_outlined,
      selectedIcon: Icons.restaurant_menu,
    ),
    _Destination(
      section: 'measurements',
      route: '/measurements',
      label: 'Misure',
      icon: Icons.monitor_weight_outlined,
      selectedIcon: Icons.monitor_weight,
    ),
    _Destination(
      section: 'workout',
      route: '/workout',
      label: 'Allenamento',
      icon: Icons.fitness_center_outlined,
      selectedIcon: Icons.fitness_center,
    ),
    _Destination(
      section: 'settings',
      route: '/settings',
      label: 'Impostazioni',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    int selectedIndex = _destinations.indexWhere(
      (_Destination destination) => destination.section == currentSection,
    );
    if (selectedIndex < 0) selectedIndex = 0;

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (int index) {
        final _Destination destination = _destinations[index];
        if (destination.section == currentSection) {
          context.go(destination.route);
          return;
        }
        context.go(destination.route);
      },
      destinations: <NavigationDestination>[
        for (final _Destination destination in _destinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
          ),
      ],
    );
  }
}

class FoodNavigationShell extends StatelessWidget {
  const FoodNavigationShell({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const PrimaryBottomNavigation(
        currentSection: 'food',
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.section,
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String section;
  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
