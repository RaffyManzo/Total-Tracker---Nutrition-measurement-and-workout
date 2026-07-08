import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/entities/nutrition_tracking_entities.dart';
import 'package:total_tracker/features/nutrition/data/repositories/measurement_repository.dart';

import '../../helpers/objectbox_test_helper.dart';

void main() {
  test('soft delete hides a scale measurement without removing the record',
      () async {
    final database = await openTestDatabase();
    final repository = MeasurementRepository(database.store);

    final measurement = repository.saveScale(
      ScaleMeasurementEntity(
        uuid: '',
        dateKey: '2026-07-02',
        title: 'Bilancia - 2026-07-02',
        weightKg: 64,
        createdAtEpochMs: 0,
        updatedAtEpochMs: 0,
      ),
    );

    repository.softDeleteScale(measurement);

    expect(repository.getScaleMeasurements(), isEmpty);
    final stored =
        database.store.box<ScaleMeasurementEntity>().get(measurement.id);
    expect(stored, isNotNull);
    expect(stored!.deletedAtEpochMs, isNotNull);
  });

  test('soft delete hides a tape measurement and tombstones entries', () async {
    final database = await openTestDatabase();
    final repository = MeasurementRepository(database.store);

    final measurement = repository.saveTapeWithEntries(
      TapeMeasurementEntity(
        uuid: '',
        dateKey: '2026-07-03',
        title: 'Metro - 2026-07-03',
        createdAtEpochMs: 0,
        updatedAtEpochMs: 0,
      ),
      <TapeMeasurementEntryEntity>[
        TapeMeasurementEntryEntity(
          uuid: '',
          measurementCode: 'waist_cm',
          valueCm: 82,
          position: 0,
          createdAtEpochMs: 0,
          updatedAtEpochMs: 0,
        ),
      ],
    );

    repository.softDeleteTape(measurement);

    expect(repository.getTapeMeasurements(), isEmpty);
    expect(repository.getTapeEntries(measurement.id), isEmpty);
    final stored =
        database.store.box<TapeMeasurementEntity>().get(measurement.id);
    expect(stored, isNotNull);
    expect(stored!.deletedAtEpochMs, isNotNull);
    final entries = database.store.box<TapeMeasurementEntryEntity>().getAll();
    expect(entries, hasLength(1));
    expect(entries.single.deletedAtEpochMs, isNotNull);
  });
}
