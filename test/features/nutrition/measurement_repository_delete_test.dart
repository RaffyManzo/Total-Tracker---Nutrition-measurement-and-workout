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
}
