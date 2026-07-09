import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:total_tracker/features/nutrition/data/entities/ingredient_entity.dart';
import 'package:total_tracker/features/transfer/data/total_tracker_transfer_service.dart';
import 'package:total_tracker/features/transfer/domain/transfer_models.dart';

import '../../helpers/objectbox_test_helper.dart';

void main() {
  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'Total Tracker',
      packageName: 'com.totaltracker.app',
      version: '0.1.0',
      buildNumber: '20',
      buildSignature: '',
    );
  });

  test('schema 2 export/import is a real two-store round trip', () async {
    final source = await openTestDatabase();
    final destination = await openTestDatabase();
    final int now = DateTime.utc(2026, 7, 9).millisecondsSinceEpoch;

    final active = IngredientEntity(
      uuid: 'roundtrip-active',
      name: 'Round trip ingredient',
      brand: 'Test brand',
      imageUrl: 'media://ingredient-preview',
      notes: 'portable note',
      kcalPerReference: 321,
      proteinPerReference: 12,
      carbsPerReference: 45,
      fatPerReference: 7,
      createdAtEpochMs: now,
      updatedAtEpochMs: now,
    );
    final deleted = IngredientEntity(
      uuid: 'roundtrip-deleted',
      name: 'Deleted ingredient',
      kcalPerReference: 1,
      createdAtEpochMs: now,
      updatedAtEpochMs: now,
      deletedAtEpochMs: now,
    );
    source.store.box<IngredientEntity>().putMany(<IngredientEntity>[
      active,
      deleted,
    ]);

    final Directory exportDirectory =
        await Directory.systemTemp.createTemp('tt_roundtrip_export_');
    addTearDown(() async {
      if (await exportDirectory.exists()) {
        await exportDirectory.delete(recursive: true);
      }
    });

    final TotalTrackerTransferService exporter =
        TotalTrackerTransferService(source.store);
    final TransferExportResult exported = await exporter.exportArchive(
      options: const TransferExportOptions(),
      directoryPath: exportDirectory.path,
    );

    expect(exported.path, endsWith('.totaltracker'));
    final TransferArchivePayload decoded = const TransferArchiveCodec().decode(
      await File(exported.path).readAsBytes(),
    );
    expect(decoded.manifest['formatVersion'], totalTrackerArchiveVersion);
    expect(
        decoded.manifest['areas'],
        containsAll(<String>[
          'profile',
          'food',
          'workout',
        ]));

    final TotalTrackerTransferService importer =
        TotalTrackerTransferService(destination.store);
    final TransferImportAnalysis analysis =
        await importer.analyzeImport(exported.path);
    final TransferImportResult first = importer.applyImport(analysis);
    expect(first.created, greaterThanOrEqualTo(1));

    final List<IngredientEntity> imported =
        destination.store.box<IngredientEntity>().getAll();
    expect(imported, hasLength(1));
    expect(
      _canonical(imported.single),
      _canonical(active),
    );

    final TransferImportAnalysis secondAnalysis =
        await importer.analyzeImport(exported.path);
    final TransferImportResult second = importer.applyImport(secondAnalysis);
    expect(second.created, 0);
    expect(destination.store.box<IngredientEntity>().getAll(), hasLength(1));
  });

  test('corrupt archive is rejected without changing destination', () async {
    final destination = await openTestDatabase();
    final int now = DateTime.utc(2026, 7, 9).millisecondsSinceEpoch;
    destination.store.box<IngredientEntity>().put(
          IngredientEntity(
            uuid: 'preserved',
            name: 'Preserved',
            kcalPerReference: 10,
            createdAtEpochMs: now,
            updatedAtEpochMs: now,
          ),
        );

    final File fixture = File(
      'test/fixtures/transfer/schema_1_minimal.totaltracker',
    );
    final List<int> bytes = await fixture.readAsBytes();
    final Directory directory =
        await Directory.systemTemp.createTemp('tt_corrupt_archive_');
    final File corrupt = File('${directory.path}/corrupt.totaltracker');
    await corrupt.writeAsBytes(
      <int>[...bytes.take(bytes.length ~/ 2), 0, 1, 2, 3],
      flush: true,
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final TotalTrackerTransferService service =
        TotalTrackerTransferService(destination.store);
    final List<Map<String, Object?>> before = destination.store
        .box<IngredientEntity>()
        .getAll()
        .map(_canonical)
        .toList(growable: false);

    await expectLater(
      service.analyzeImport(corrupt.path),
      throwsA(isA<FormatException>()),
    );

    final List<Map<String, Object?>> after = destination.store
        .box<IngredientEntity>()
        .getAll()
        .map(_canonical)
        .toList(growable: false);
    expect(after, before);
  });

  test('write transaction used by import rolls back atomically on failure',
      () async {
    final destination = await openTestDatabase();
    final int now = DateTime.utc(2026, 7, 9).millisecondsSinceEpoch;
    final box = destination.store.box<IngredientEntity>();
    box.put(
      IngredientEntity(
        uuid: 'rollback-preserved',
        name: 'Preserved before transaction',
        kcalPerReference: 10,
        createdAtEpochMs: now,
        updatedAtEpochMs: now,
      ),
    );

    final List<Map<String, Object?>> before =
        box.getAll().map(_canonical).toList(growable: false);
    Object? thrown;
    try {
      destination.store.runInTransaction(TxMode.write, () {
        box.put(
          IngredientEntity(
            uuid: 'rollback-transient',
            name: 'Must be rolled back',
            kcalPerReference: 20,
            createdAtEpochMs: now,
            updatedAtEpochMs: now,
          ),
        );
        throw StateError('forced transfer transaction failure');
      });
    } catch (error) {
      thrown = error;
    }

    expect(thrown, anyOf(isA<StateError>(), isA<UnsupportedError>()));
    expect(box.getAll().map(_canonical).toList(growable: false), before);
  });

  test('real schema 1 fixture imports through legacy checksum path', () async {
    final destination = await openTestDatabase();
    final TotalTrackerTransferService service =
        TotalTrackerTransferService(destination.store);
    final String path = 'test/fixtures/transfer/schema_1_minimal.totaltracker';

    final TransferImportAnalysis analysis = await service.analyzeImport(path);
    expect(analysis.manifest['formatVersion'], 1);
    expect(analysis.sections, isNotEmpty);
    final TransferImportResult result = service.applyImport(analysis);
    expect(result.created, 1);
    expect(
      destination.store.box<IngredientEntity>().getAll().single.uuid,
      'schema-1-ingredient',
    );
  });
}

Map<String, Object?> _canonical(IngredientEntity item) => <String, Object?>{
      'uuid': item.uuid,
      'name': item.name,
      'brand': item.brand,
      'imageUrl': item.imageUrl,
      'kcal': item.kcalPerReference,
      'protein': item.proteinPerReference,
      'carbs': item.carbsPerReference,
      'fat': item.fatPerReference,
      'deletedAt': item.deletedAtEpochMs,
    };
