import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/objectbox_providers.dart';
import '../repositories/open_nutrition_catalog_repository.dart';
import '../services/open_nutrition_catalog_database.dart';
import '../services/open_nutrition_gateway_service.dart';
import '../services/open_nutrition_import_service.dart';
import '../services/unified_ingredient_search_service.dart';

final openNutritionCatalogDatabaseProvider =
    Provider.autoDispose<OpenNutritionCatalogDatabase>((Ref ref) {
  final OpenNutritionCatalogDatabase database = OpenNutritionCatalogDatabase();
  ref.onDispose(database.close);
  return database;
});

final openNutritionCatalogRepositoryProvider =
    Provider.autoDispose<OpenNutritionCatalogRepository>((Ref ref) {
  return OpenNutritionCatalogRepository(
    ref.watch(openNutritionCatalogDatabaseProvider),
  );
});

final openNutritionImportServiceProvider =
    Provider.autoDispose<OpenNutritionImportService>((Ref ref) {
  final OpenNutritionImportService service = OpenNutritionImportService(
    ref.watch(openNutritionCatalogRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final openNutritionGatewayServiceProvider =
    Provider.autoDispose<OpenNutritionGatewayService>((Ref ref) {
  final OpenNutritionGatewayService service = OpenNutritionGatewayService();
  ref.onDispose(service.dispose);
  return service;
});

final unifiedIngredientSearchServiceProvider =
    Provider.autoDispose<UnifiedIngredientSearchService>((Ref ref) {
  return UnifiedIngredientSearchService(
    personalRepository: ref.watch(ingredientRepositoryProvider),
    openNutritionRepository: ref.watch(
      openNutritionCatalogRepositoryProvider,
    ),
    openNutritionGatewayService: ref.watch(
      openNutritionGatewayServiceProvider,
    ),
    openFoodFactsService: ref.watch(openFoodFactsServiceProvider),
  );
});

final openNutritionCatalogStateProvider =
    FutureProvider.autoDispose((Ref ref) async {
  return ref.watch(openNutritionCatalogRepositoryProvider).getState();
});

final openNutritionCatalogCountProvider =
    FutureProvider.autoDispose<int>((Ref ref) async {
  return ref.watch(openNutritionCatalogRepositoryProvider).countActive();
});

final openNutritionGatewayConfiguredProvider =
    FutureProvider.autoDispose<bool>((Ref ref) async {
  return ref.watch(openNutritionGatewayServiceProvider).isConfigured();
});
