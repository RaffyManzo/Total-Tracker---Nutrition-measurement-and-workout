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

  test('scale pagination is stable and excludes soft deleted rows', () async {
    final database = await openTestDatabase();
    final repository = MeasurementRepository(database.store);

    final List<ScaleMeasurementEntity> saved = <ScaleMeasurementEntity>[];
    for (int index = 0; index < 25; index += 1) {
      saved.add(
        repository.saveScale(
          ScaleMeasurementEntity(
            uuid: '',
            dateKey: '2026-07-${(index % 9 + 1).toString().padLeft(2, '0')}',
            title: 'Bilancia $index',
            weightKg: (70 + index).toDouble(),
            createdAtEpochMs: 0,
            updatedAtEpochMs: 0,
          ),
        ),
      );
    }
    repository.softDeleteScale(saved.first);

    final page1 = repository.loadScaleMeasurementPage(page: 1);
    final page2 = repository.loadScaleMeasurementPage(page: 2);

    expect(page1.items, hasLength(10));
    expect(page2.items, hasLength(10));
    expect(page1.totalCount, 24);
    expect(page1.items.any((item) => item.id == saved.first.id), isFalse);
    expect(
      page1.items.map((item) => item.id).toSet().intersection(
            page2.items.map((item) => item.id).toSet(),
          ),
      isEmpty,
    );
    expect(repository.findScaleByDate(saved.first.dateKey)?.id,
        isNot(saved.first.id));
  });

  test('tape pagination is stable and excludes soft deleted rows', () async {
    final database = await openTestDatabase();
    final repository = MeasurementRepository(database.store);

    final List<TapeMeasurementEntity> saved = <TapeMeasurementEntity>[];
    for (int index = 0; index < 25; index += 1) {
      saved.add(
        repository.saveTapeWithEntries(
          TapeMeasurementEntity(
            uuid: '',
            dateKey: '2026-08-${(index + 1).toString().padLeft(2, '0')}',
            title: 'Metro $index',
            createdAtEpochMs: 0,
            updatedAtEpochMs: 0,
          ),
          <TapeMeasurementEntryEntity>[
            TapeMeasurementEntryEntity(
              uuid: '',
              measurementCode: 'waist_cm',
              valueCm: (80 + index).toDouble(),
              createdAtEpochMs: 0,
              updatedAtEpochMs: 0,
            ),
          ],
        ),
      );
    }
    repository.softDeleteTape(saved.last);

    final page1 = repository.loadTapeMeasurementPage(page: 1);
    final page2 = repository.loadTapeMeasurementPage(page: 2);

    expect(page1.items, hasLength(10));
    expect(page2.items, hasLength(10));
    expect(page1.totalCount, 24);
    expect(page1.items.any((item) => item.id == saved.last.id), isFalse);
    expect(
      page1.items.map((item) => item.id).toSet().intersection(
            page2.items.map((item) => item.id).toSet(),
          ),
      isEmpty,
    );
  });

  test('combined measurement history pages are bounded and stable', () async {
    final database = await openTestDatabase();
    final repository = MeasurementRepository(database.store);

    for (int index = 1; index <= 12; index += 1) {
      repository.saveScale(
        ScaleMeasurementEntity(
          uuid: '',
          dateKey: '2026-06-${index.toString().padLeft(2, '0')}',
          title: 'Bilancia $index',
          weightKg: 60 + index.toDouble(),
          createdAtEpochMs: 0,
          updatedAtEpochMs: 0,
        ),
      );
      repository.saveTapeWithEntries(
        TapeMeasurementEntity(
          uuid: '',
          dateKey: '2026-07-${index.toString().padLeft(2, '0')}',
          title: 'Metro $index',
          createdAtEpochMs: 0,
          updatedAtEpochMs: 0,
        ),
        <TapeMeasurementEntryEntity>[],
      );
    }

    final page1 = repository.loadMeasurementHistoryPage(page: 1);
    final page2 = repository.loadMeasurementHistoryPage(page: 2);

    expect(page1.items, hasLength(10));
    expect(page2.items, hasLength(10));
    expect(page1.totalCount, 24);
    expect(
      page1.items
          .map((item) => '${item.isScale}:${item.id}')
          .toSet()
          .intersection(
            page2.items.map((item) => '${item.isScale}:${item.id}').toSet(),
          ),
      isEmpty,
    );
  });
}
