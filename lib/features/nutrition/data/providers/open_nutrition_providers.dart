import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/objectbox_providers.dart';
import '../repositories/open_nutrition_catalog_repository.dart';
import '../services/open_nutrition_catalog_database.dart';
import '../services/open_nutrition_import_service.dart';
import '../services/unified_ingredient_search_service.dart';

final openNutritionCatalogDatabaseProvider = Provider((Ref ref) {
  final OpenNutritionCatalogDatabase database = OpenNutritionCatalogDatabase();
  ref.onDispose(database.close);
  return database;
});

final openNutritionCatalogRepositoryProvider = Provider((Ref ref) {
  return OpenNutritionCatalogRepository(
    ref.watch(openNutritionCatalogDatabaseProvider),
  );
});

final openNutritionImportServiceProvider = Provider(
  (Ref ref) {
    final OpenNutritionImportService service = OpenNutritionImportService(
      ref.watch(openNutritionCatalogRepositoryProvider),
    );
    ref.onDispose(service.dispose);
    return service;
  },
);

final unifiedIngredientSearchServiceProvider = Provider((Ref ref) {
  return UnifiedIngredientSearchService(
    personalRepository: ref.watch(ingredientRepositoryProvider),
    openNutritionRepository: ref.watch(
      openNutritionCatalogRepositoryProvider,
    ),
    openFoodFactsService: ref.watch(openFoodFactsServiceProvider),
  );
});

final openNutritionCatalogStateProvider = FutureProvider((Ref ref) async {
  return ref.watch(openNutritionCatalogRepositoryProvider).getState();
});

final openNutritionCatalogCountProvider = FutureProvider((Ref ref) async {
  return ref.watch(openNutritionCatalogRepositoryProvider).countActive();
});
