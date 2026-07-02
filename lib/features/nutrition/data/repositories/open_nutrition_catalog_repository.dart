import '../../../../objectbox.g.dart';
import '../entities/open_nutrition_catalog_state_entity.dart';
import '../entities/open_nutrition_food_entity.dart';
import '../services/open_nutrition_catalog_database.dart';
import '../services/open_nutrition_tsv_parser.dart';

class OpenNutritionCatalogRepository {
  OpenNutritionCatalogRepository(this.database);
  final OpenNutritionCatalogDatabase database;

  Future<Box<OpenNutritionFoodEntity>> get _foodBox async =>
      (await database.store).box<OpenNutritionFoodEntity>();
  Future<Box<OpenNutritionCatalogStateEntity>> get _stateBox async =>
      (await database.store).box<OpenNutritionCatalogStateEntity>();

  Future<OpenNutritionCatalogStateEntity> getState() async {
    final box = await _stateBox;
    final states = box.getAll();
    if (states.isNotEmpty) return states.first;
    final state = OpenNutritionCatalogStateEntity();
    state.id = box.put(state);
    return state;
  }

  Future<void> saveState(OpenNutritionCatalogStateEntity state) async {
    state.id = (await _stateBox).put(state);
  }

  Future<List<OpenNutritionFoodEntity>> search({
    required String query,
    int offset = 0,
    int limit = 25,
  }) async {
    final state = await getState();
    if (state.activeBatchId.isEmpty ||
        state.importStatusCode != OpenNutritionImportStatusCodes.installed) {
      return <OpenNutritionFoodEntity>[];
    }
    final normalized = OpenNutritionTsvParser.normalizeSearch(query);
    final box = await _foodBox;
    final builder = normalized.isEmpty
        ? box.query(
            OpenNutritionFoodEntity_.importBatchId.equals(state.activeBatchId),
          )
        : box.query(
            OpenNutritionFoodEntity_.importBatchId
                .equals(state.activeBatchId)
                .and(
                  OpenNutritionFoodEntity_.normalizedSearchText.contains(
                    normalized,
                  ),
                ),
          );
    final objectQuery =
        builder.order(OpenNutritionFoodEntity_.normalizedName).build();
    objectQuery.offset = offset;
    objectQuery.limit = limit;
    try {
      return objectQuery.find();
    } finally {
      objectQuery.close();
    }
  }

  Future<int> countActive() async {
    final state = await getState();
    if (state.activeBatchId.isEmpty) return 0;
    final query = (await _foodBox)
        .query(
          OpenNutritionFoodEntity_.importBatchId.equals(state.activeBatchId),
        )
        .build();
    try {
      return query.count();
    } finally {
      query.close();
    }
  }

  Future<OpenNutritionFoodEntity?> findByExternalId(String externalId) async {
    final state = await getState();
    if (state.activeBatchId.isEmpty) return null;
    final query = (await _foodBox)
        .query(
          OpenNutritionFoodEntity_.importBatchId
              .equals(state.activeBatchId)
              .and(OpenNutritionFoodEntity_.externalFoodId.equals(externalId)),
        )
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  Future<void> putBatch(List<OpenNutritionFoodEntity> items) async {
    if (items.isEmpty) return;
    final store = await database.store;
    store.runInTransaction(TxMode.write, () {
      store.box<OpenNutritionFoodEntity>().putMany(items);
    });
  }

  Future<void> deleteBatch(String batchId) async {
    if (batchId.isEmpty) return;
    final query = (await _foodBox)
        .query(OpenNutritionFoodEntity_.importBatchId.equals(batchId))
        .build();
    try {
      query.remove();
    } finally {
      query.close();
    }
  }

  Future<void> removeCatalog() async {
    await database.deleteDirectory();
  }
}
