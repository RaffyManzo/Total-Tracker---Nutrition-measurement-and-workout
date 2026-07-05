import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/background/background_tasks.dart';
import 'core/database/objectbox_database.dart';
import 'core/database/objectbox_providers.dart';
import 'core/diagnostics/app_diagnostics.dart';
import 'core/notifications/local_notification_service.dart';
import 'features/profile/data/repositories/user_profile_repository.dart';
import 'features/workout/data/seed/muscle_catalog_seeder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppDiagnostics diagnostics = AppDiagnostics.instance;
  await diagnostics.initialize();

  final previousFlutterError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    unawaited(diagnostics.recordFlutterError(details));
    if (previousFlutterError != null) {
      previousFlutterError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final ErrorCallback? previousPlatformError =
      PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    unawaited(
      diagnostics.error(
        'platform.uncaught_error',
        error: error,
        stackTrace: stackTrace,
      ),
    );
    return previousPlatformError?.call(error, stackTrace) ?? false;
  };

  final Future<void>? startup = runZonedGuarded<Future<void>>(
    () => _startApplication(diagnostics),
    (Object error, StackTrace stackTrace) {
      unawaited(
        diagnostics.error(
          'zone.uncaught_error',
          error: error,
          stackTrace: stackTrace,
        ),
      );
    },
  );
  if (startup != null) {
    await startup;
  }
}

Future<void> _startApplication(AppDiagnostics diagnostics) async {
  final ObjectBoxDatabase database = ObjectBoxDatabase();
  DatabaseInitializationStatus databaseStatus;
  bool databaseReady = false;

  try {
    await diagnostics.measure<void>('bootstrap.database_open', database.open);
    diagnostics.measureSync<void>(
      'bootstrap.default_profile',
      () {
        UserProfileRepository(
          database.store,
        ).createDefaultProfileIfMissing();
      },
    );
    databaseStatus = const DatabaseInitializationStatus.ready();
    databaseReady = true;
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'total_tracker bootstrap',
      ),
    );
    databaseStatus = DatabaseInitializationStatus.failed(error.toString());
  }

  runApp(
    ProviderScope(
      overrides: [
        objectBoxDatabaseProvider.overrideWithValue(database),
        databaseInitializationStatusProvider.overrideWithValue(databaseStatus),
      ],
      child: const TotalTrackerApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      diagnostics.info(
        'app.first_frame',
        data: <String, Object?>{'databaseReady': databaseReady},
      ),
    );
    if (databaseReady) {
      unawaited(_runDeferredBootstrap(database, diagnostics));
    }
  });
}

Future<void> _runDeferredBootstrap(
  ObjectBoxDatabase database,
  AppDiagnostics diagnostics,
) async {
  await Future<void>.delayed(const Duration(milliseconds: 700));

  if (Platform.isAndroid || Platform.isIOS) {
    await _guardedBootstrap(
      diagnostics,
      'bootstrap.notifications',
      LocalNotificationService.initialize,
    );
    await _guardedBootstrap(
      diagnostics,
      'bootstrap.open_nutrition_jobs',
      OpenNutritionBackgroundJobs.initialize,
    );
    await _guardedBootstrap(
      diagnostics,
      'bootstrap.reminder_registration',
      ReminderBackgroundJobs.reconcileRegistration,
    );
  }

  await Future<void>.delayed(Duration.zero);
  try {
    diagnostics.measureSync<void>('bootstrap.muscle_seed', () {
      final MuscleCatalogSeedReport seedReport =
          MuscleCatalogSeeder(database.store).seed();
      if (seedReport.hasErrors) {
        throw StateError(seedReport.errors.join(', '));
      }
    });
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'total_tracker deferred muscle seed',
      ),
    );
  }

  if (Platform.isAndroid || Platform.isIOS) {
    try {
      diagnostics.measureSync<void>(
        'bootstrap.reminder_foreground_reconciliation',
        () => ReminderBackgroundJobs.startForegroundReconciliation(database),
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'total_tracker reminder reconciliation',
        ),
      );
    }
  }
}

Future<void> _guardedBootstrap(
  AppDiagnostics diagnostics,
  String event,
  Future<dynamic> Function() operation,
) async {
  try {
    await diagnostics.measure<dynamic>(event, operation);
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: event,
      ),
    );
  }
}
