import 'package:flutter/material.dart';

import '../../shared/widgets/tt_global_nav_fab.dart';

/// Compatibility wrapper for screens that still import the historical
/// primary navigation component. The legacy four-destination NavigationBar
/// must never be rendered: all sections use the same global three-control
/// navigation surface.
class PrimaryBottomNavigation extends StatelessWidget {
  const PrimaryBottomNavigation({
    required this.currentSection,
    super.key,
  });

  final String currentSection;

  @override
  Widget build(BuildContext context) {
    return TtFoodBottomNavBar(
      activeItem: switch (currentSection) {
        'settings' => TtFoodNavItem.settings,
        _ => TtFoodNavItem.dashboard,
      },
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
      bottomNavigationBar: const TtFoodBottomNavBar(),
    );
  }
}
