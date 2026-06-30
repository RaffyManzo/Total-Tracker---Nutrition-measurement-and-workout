import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/workout/data/repositories/muscle_repository.dart';
import 'package:total_tracker/features/workout/data/seed/muscle_catalog_seed.dart';
import 'package:total_tracker/features/workout/data/seed/muscle_catalog_seeder.dart';

import '../../helpers/objectbox_test_helper.dart';

void main() {
  test('il seeder inserisce il catalogo iniziale', () async {
    final database = await openTestDatabase();
    final seeder = MuscleCatalogSeeder(database.store);

    final report = seeder.seed();

    expect(report.inserted, muscleCatalogSeed.length);
    expect(report.updated, 0);
    expect(report.duplicateCodes, 0);
    expect(report.errors, isEmpty);
  });

  test('una seconda esecuzione non crea duplicati', () async {
    final database = await openTestDatabase();
    final seeder = MuscleCatalogSeeder(database.store);
    final repository = MuscleRepository(database.store);

    seeder.seed();
    final secondReport = seeder.seed();

    expect(secondReport.inserted, 0);
    expect(secondReport.unchanged, muscleCatalogSeed.length);
    expect(repository.getAllActive().length, muscleCatalogSeed.length);
  });

  test('tutti i code sono univoci', () async {
    final codes = muscleCatalogSeed.map((entry) => entry.code).toList();
    expect(codes.toSet().length, codes.length);
  });

  test('tutti i nomi italiani sono valorizzati', () {
    expect(
      muscleCatalogSeed.every((entry) => entry.displayNameIt.trim().isNotEmpty),
      isTrue,
    );
  });

  test('tutti i groupCode sono valorizzati', () {
    expect(
      muscleCatalogSeed.every((entry) => entry.groupCode.trim().isNotEmpty),
      isTrue,
    );
  });
}
