import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/background/background_tasks.dart';
import 'core/database/objectbox_database.dart';
import 'core/database/objectbox_providers.dart';
import 'core/notifications/local_notification_service.dart';
import 'features/profile/data/repositories/user_profile_repository.dart';
import 'features/workout/data/seed/muscle_catalog_seeder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final ObjectBoxDatabase database = ObjectBoxDatabase();
  DatabaseInitializationStatus databaseStatus;
  bool databaseReady = false;

  try {
    await database.open();
    UserProfileRepository(database.store).createDefaultProfileIfMissing();
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

  if (databaseReady) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runDeferredBootstrap(database));
    });
  }
}

Future<void> _runDeferredBootstrap(ObjectBoxDatabase database) async {
  // Concede al primo frame e alla navigazione iniziale il thread UI.
  await Future<void>.delayed(const Duration(milliseconds: 700));

  if (Platform.isAndroid || Platform.isIOS) {
    try {
      await LocalNotificationService.initialize();
      await OpenNutritionBackgroundJobs.initialize();
      await ReminderBackgroundJobs.reconcileRegistration();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'total_tracker deferred background bootstrap',
        ),
      );
    }
  }

  await Future<void>.delayed(Duration.zero);

  try {
    final MuscleCatalogSeedReport seedReport =
        MuscleCatalogSeeder(database.store).seed();
    if (seedReport.hasErrors) {
      throw StateError(seedReport.errors.join(', '));
    }
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
      ReminderBackgroundJobs.startForegroundReconciliation(database);
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
