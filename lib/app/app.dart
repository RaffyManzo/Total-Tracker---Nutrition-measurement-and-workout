import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/objectbox_providers.dart';
import '../core/preferences/app_navigation_preferences.dart';
import '../features/profile/domain/profile_codes.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

final DashboardBackButtonDispatcher appBackButtonDispatcher =
    DashboardBackButtonDispatcher();

class DashboardBackButtonDispatcher extends RootBackButtonDispatcher {
  @override
  Future<bool> didPopRoute() async {
    if (appRouter.canPop()) {
      return super.didPopRoute();
    }

    final String preferredRoute =
        await AppNavigationPreferences.getDefaultDashboardRoute();
    final String currentRoute =
        appRouter.routerDelegate.currentConfiguration.uri.path;

    if (currentRoute != preferredRoute) {
      appRouter.go(preferredRoute);
      return true;
    }

    return super.didPopRoute();
  }
}

class TotalTrackerApp extends ConsumerWidget {
  const TotalTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ThemeMode themeMode = ThemeMode.system;
    final DatabaseInitializationStatus status =
        ref.watch(databaseInitializationStatusProvider);
    ref.watch(profileSettingsRevisionProvider);

    if (status.isReady) {
      final String? code = ref
          .watch(userProfileRepositoryProvider)
          .getActiveProfile()
          ?.themeModeCode;
      themeMode = switch (code) {
        ThemePreferenceCodes.light => ThemeMode.light,
        ThemePreferenceCodes.dark => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    }

    return MaterialApp.router(
      title: 'Total Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routeInformationProvider: appRouter.routeInformationProvider,
      routeInformationParser: appRouter.routeInformationParser,
      routerDelegate: appRouter.routerDelegate,
      backButtonDispatcher: appBackButtonDispatcher,
    );
  }
}
