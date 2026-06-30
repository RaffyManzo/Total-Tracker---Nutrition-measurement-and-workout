import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/database/objectbox_database.dart';
import 'core/database/objectbox_providers.dart';
import 'features/nutrition/data/import/obsidian_development_seed_service.dart';
import 'features/profile/data/repositories/user_profile_repository.dart';
import 'features/workout/data/seed/muscle_catalog_seeder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final ObjectBoxDatabase database = ObjectBoxDatabase();
  DatabaseInitializationStatus databaseStatus;

  try {
    await database.open();
    UserProfileRepository(database.store).createDefaultProfileIfMissing();
    final ObsidianDevelopmentSeedReport foodSeedReport =
        await ObsidianDevelopmentSeedService(database.store)
            .importFromAssetIfPresent();
    if (foodSeedReport.seedFound) {
      debugPrint(foodSeedReport.toString());
      if (foodSeedReport.hasWarnings) {
        debugPrint('Obsidian seed warnings: ${foodSeedReport.warnings.length}');
      }
    }
    final MuscleCatalogSeedReport seedReport =
        MuscleCatalogSeeder(database.store).seed();
    if (seedReport.hasErrors) {
      throw StateError(seedReport.errors.join(', '));
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
