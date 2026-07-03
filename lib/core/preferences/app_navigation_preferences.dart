import 'package:shared_preferences/shared_preferences.dart';

class AppDashboardOption {
  const AppDashboardOption({
    required this.route,
    required this.label,
    required this.description,
  });

  final String route;
  final String label;
  final String description;
}

class AppNavigationPreferences {
  const AppNavigationPreferences._();

  static const String defaultDashboardKey = 'app.default_dashboard_route';
  static const String defaultRoute = '/food';

  static const List<AppDashboardOption> dashboardOptions = <AppDashboardOption>[
    AppDashboardOption(
      route: '/food',
      label: 'Alimentazione',
      description: 'Piano alimentare e diario giornaliero.',
    ),
    AppDashboardOption(
      route: '/measurements',
      label: 'Misurazioni',
      description: 'Peso e misurazioni corporee.',
    ),
    AppDashboardOption(
      route: '/workout',
      label: 'Allenamento',
      description: 'Schede, esercizi e sessioni.',
    ),
  ];

  static final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  static Future<String> getDefaultDashboardRoute() async {
    try {
      final String route =
          await _preferences.getString(defaultDashboardKey) ?? defaultRoute;
      return isAllowedRoute(route) ? route : defaultRoute;
    } catch (_) {
      return defaultRoute;
    }
  }

  static Future<void> setDefaultDashboardRoute(String route) async {
    if (!isAllowedRoute(route)) {
      throw ArgumentError.value(
        route,
        'route',
        'Dashboard non supportata.',
      );
    }
    await _preferences.setString(defaultDashboardKey, route);
  }

  static bool isAllowedRoute(String route) {
    return dashboardOptions.any(
      (AppDashboardOption option) => option.route == route,
    );
  }

  static String labelForRoute(String route) {
    for (final AppDashboardOption option in dashboardOptions) {
      if (option.route == route) return option.label;
    }
    return dashboardOptions.first.label;
  }
}
