import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/objectbox_providers.dart';
import '../features/profile/domain/profile_codes.dart';
import 'back_navigation.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

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
      scaffoldMessengerKey: appScaffoldMessengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
