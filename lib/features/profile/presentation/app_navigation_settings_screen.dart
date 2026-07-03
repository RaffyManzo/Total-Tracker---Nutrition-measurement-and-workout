import 'package:flutter/material.dart';

import '../../../core/preferences/app_navigation_preferences.dart';

class AppNavigationSettingsScreen extends StatefulWidget {
  const AppNavigationSettingsScreen({super.key});

  @override
  State<AppNavigationSettingsScreen> createState() =>
      _AppNavigationSettingsScreenState();
}

class _AppNavigationSettingsScreenState
    extends State<AppNavigationSettingsScreen> {
  String _selectedRoute = AppNavigationPreferences.defaultRoute;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final String route =
        await AppNavigationPreferences.getDefaultDashboardRoute();
    if (!mounted) return;
    setState(() {
      _selectedRoute = route;
      _loading = false;
    });
  }

  Future<void> _select(String route) async {
    setState(() => _selectedRoute = route);
    await AppNavigationPreferences.setDefaultDashboardRoute(route);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Dashboard iniziale: '
          '${AppNavigationPreferences.labelForRoute(route)}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Navigazione')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Quando premi Indietro e non esiste una schermata '
                      'precedente, Total Tracker torna alla dashboard scelta. '
                      'Dalla dashboard scelta, Indietro può chiudere l’app.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final AppDashboardOption option
                    in AppNavigationPreferences.dashboardOptions)
                  Card(
                    child: RadioListTile<String>(
                      value: option.route,
                      groupValue: _selectedRoute,
                      title: Text(option.label),
                      subtitle: Text(option.description),
                      onChanged: (String? route) {
                        if (route != null) _select(route);
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
