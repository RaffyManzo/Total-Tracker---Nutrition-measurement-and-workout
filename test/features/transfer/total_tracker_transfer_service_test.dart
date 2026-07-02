import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/entities/ingredient_entity.dart';
import 'package:total_tracker/features/transfer/data/total_tracker_transfer_service.dart';
import 'package:total_tracker/features/transfer/domain/transfer_models.dart';

import '../../helpers/objectbox_test_helper.dart';

void main() {
  test('analysis detects an ingredient conflict before transactional import',
      () async {
    final database = await openTestDatabase();
    final ingredientBox = database.store.box<IngredientEntity>();
    final int now = DateTime.utc(2026, 7, 2).millisecondsSinceEpoch;
    ingredientBox.put(
      IngredientEntity(
        uuid: 'local-rice',
        name: 'Riso',
        brand: 'Marca',
        kcalPerReference: 100,
        createdAtEpochMs: now,
        updatedAtEpochMs: now,
      ),
    );

    const TransferArchiveCodec codec = TransferArchiveCodec();
    final List<int> bytes = codec.encode(
      TransferArchivePayload(
        manifest: <String, dynamic>{
          'format': totalTrackerArchiveFormat,
          'formatVersion': totalTrackerArchiveVersion,
          'areas': <String>['food'],
        },
        data: <String, dynamic>{
          'ingredients': <Map<String, dynamic>>[
            <String, dynamic>{
              'uuid': 'imported-rice',
              'name': 'Riso',
              'brand': 'Marca',
              'nutritionReferenceAmount': 100,
              'nutritionReferenceUnitCode': 'g',
              'kcalPerReference': 350,
              'proteinPerReference': 7,
              'carbsPerReference': 78,
              'fatPerReference': 1,
              'fiberPerReference': 1,
              'sugarPerReference': 0,
              'saltPerReference': 0,
            },
          ],
        },
      ),
    );
    final Directory directory =
        await Directory.systemTemp.createTemp('total_tracker_transfer_test_');
    final File file = File('${directory.path}/sample.totaltracker');
    await file.writeAsBytes(bytes, flush: true);
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final service = TotalTrackerTransferService(database.store);
    final TransferImportAnalysis analysis =
        await service.analyzeImport(file.path);

    expect(analysis.sections, hasLength(1));
    expect(analysis.sections.single.code, 'ingredients');
    expect(analysis.sections.single.items, hasLength(1));
    expect(analysis.sections.single.items.single.hasConflict, isTrue);
    expect(ingredientBox.getAll(), hasLength(1));

    final TransferImportResult result = service.applyImport(analysis);

    expect(result.updated, 1);
    expect(result.created, 0);
    final List<IngredientEntity> stored = ingredientBox.getAll();
    expect(stored, hasLength(1));
    expect(stored.single.uuid, 'local-rice');
    expect(stored.single.kcalPerReference, 350);
  });
}
