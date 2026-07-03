import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/background/background_tasks.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/database/objectbox_database.dart';
import 'core/database/objectbox_providers.dart';
import 'features/profile/data/repositories/user_profile_repository.dart';
import 'features/workout/data/seed/muscle_catalog_seeder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
          library: 'total_tracker background bootstrap',
        ),
      );
    }
  }

  final ObjectBoxDatabase database = ObjectBoxDatabase();
  DatabaseInitializationStatus databaseStatus;

  try {
    await database.open();
    UserProfileRepository(database.store).createDefaultProfileIfMissing();
    final MuscleCatalogSeedReport seedReport =
        MuscleCatalogSeeder(database.store).seed();
    if (seedReport.hasErrors) {
      throw StateError(seedReport.errors.join(', '));
    }
    if (Platform.isAndroid || Platform.isIOS) {
      ReminderBackgroundJobs.startForegroundReconciliation(database);
    }
    databaseStatus = const DatabaseInitializationStatus.ready();
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
}
