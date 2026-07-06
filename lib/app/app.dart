import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/objectbox_providers.dart';
import '../features/nutrition/presentation/target_recalculation_gate.dart';
import '../features/profile/domain/profile_codes.dart';
import '../l10n/generated/app_localizations.dart';
import 'back_navigation.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class TotalTrackerApp extends ConsumerWidget {
  const TotalTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ThemeMode themeMode = ThemeMode.system;
    Locale? locale;

    final DatabaseInitializationStatus status =
        ref.watch(databaseInitializationStatusProvider);
    ref.watch(profileSettingsRevisionProvider);

    if (status.isReady) {
      final profile =
          ref.watch(userProfileRepositoryProvider).getActiveProfile();

      themeMode = switch (profile?.themeModeCode) {
        ThemePreferenceCodes.light => ThemeMode.light,
        ThemePreferenceCodes.dark => ThemeMode.dark,
        _ => ThemeMode.system,
      };

      locale = switch (profile?.languageCode) {
        'en' => const Locale('en'),
        'it' => const Locale('it'),
        _ => null,
      };
    }

    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: appRouter,
      builder: (BuildContext context, Widget? child) {
        return TargetRecalculationGate(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
