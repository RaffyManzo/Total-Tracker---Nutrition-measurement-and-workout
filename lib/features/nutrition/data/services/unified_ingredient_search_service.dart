import 'package:uuid/uuid.dart';

import '../../../../core/preferences/food_service_preferences.dart';
import '../../domain/nutrition_codes.dart';
import '../entities/ingredient_entity.dart';
import '../entities/open_nutrition_food_entity.dart';
import '../repositories/ingredient_repository.dart';
import '../repositories/open_nutrition_catalog_repository.dart';

class UnifiedIngredientSearchScopeCodes {
  const UnifiedIngredientSearchScopeCodes._();

  static const String all = 'all';
  static const String personal = 'personal';
  static const String openNutrition = 'open_nutrition';
}

class UnifiedIngredientSearchItem {
  const UnifiedIngredientSearchItem.personal(this.personalIngredient)
      : openNutritionFood = null;
  const UnifiedIngredientSearchItem.openNutrition(this.openNutritionFood)
      : personalIngredient = null;

  final IngredientEntity? personalIngredient;
  final OpenNutritionFoodEntity? openNutritionFood;

  bool get isPersonal => personalIngredient != null;
  String get displayName =>
      personalIngredient?.name ?? openNutritionFood?.name ?? '';
  String get brand =>
      personalIngredient?.brand ?? openNutritionFood?.brand ?? '';
  String get imageUrl =>
      personalIngredient?.imageUrl ?? openNutritionFood?.imageUrl ?? '';
  String get sourceTypeCode => personalIngredient?.sourceTypeCode ??
      IngredientSourceTypeCodes.openNutrition;
  double get kcalPer100g => personalIngredient?.kcalPerReference ??
      openNutritionFood?.kcalPer100g ??
      0;
  double get proteinPer100g => personalIngredient?.proteinPerReference ??
      openNutritionFood?.proteinPer100g ??
      0;
  double get carbsPer100g => personalIngredient?.carbsPerReference ??
      openNutritionFood?.carbsPer100g ??
      0;
  double get fatPer100g => personalIngredient?.fatPerReference ??
      openNutritionFood?.fatPer100g ??
      0;
}

class UnifiedIngredientSearchPage {
  const UnifiedIngredientSearchPage({
    required this.items,
    required this.page,
    required this.hasNext,
    required this.hasPrevious,
  });

  final List<UnifiedIngredientSearchItem> items;
  final int page;
  final bool hasNext;
  final bool hasPrevious;
}

class UnifiedIngredientSearchPolicy {
  const UnifiedIngredientSearchPolicy._();

  static const int pageSize = 25;
  static const int initialLocalLimit = 50;

  /// Legacy compatibility for tests and callers that still modelled a single
  /// mixed page. The new UI does not use this method because local and
  /// OpenNutrition results now have independent sections and pagination.
  static int remainingAfterPersonal(int personalCount) {
    if (personalCount <= 0) return pageSize;
    if (personalCount >= pageSize) return 0;
    return pageSize - personalCount;
  }

  /// Legacy compatibility for the former combined pagination policy.
  /// New code must keep the two result sources independently paginated.
  static int externalOffsetForCombinedPage({
    required int page,
    required int externalAlreadyShown,
  }) {
    final safePage = page < 1 ? 1 : page;
    final safeAlreadyShown = externalAlreadyShown < 0
        ? 0
        : externalAlreadyShown;
    return ((safePage - 1) * pageSize) + safeAlreadyShown;
  }

  static bool canSearchOpenNutrition(String query) => query.trim().length >= 2;
}

class UnifiedIngredientSearchService {
  UnifiedIngredientSearchService({
    required this.personalRepository,
    required this.openNutritionRepository,
  });

  final IngredientRepository personalRepository;
  final OpenNutritionCatalogRepository openNutritionRepository;

  Future<bool> isOpenNutritionAvailable() async {
    if (!await FoodServicePreferences.isOpenNutritionSearchEnabled()) {
      return false;
    }
    final state = await openNutritionRepository.getState();
    return state.activeBatchId.isNotEmpty &&
        state.importStatusCode == 'installed' &&
        await openNutritionRepository.countActive() > 0;
  }

  Future<UnifiedIngredientSearchPage> searchPersonal({
    required String query,
    int page = 0,
  }) async {
    final safePage = page < 0 ? 0 : page;
    if (query.trim().isEmpty) {
      final values = personalRepository.getRecentActive(
        limit: UnifiedIngredientSearchPolicy.initialLocalLimit,
      );
      return UnifiedIngredientSearchPage(
        items: values.map(UnifiedIngredientSearchItem.personal).toList(),
        page: 0,
        hasNext: false,
        hasPrevious: false,
      );
    }
    final values = personalRepository.searchByNameLimited(
      query,
      offset: safePage * UnifiedIngredientSearchPolicy.pageSize,
      limit: UnifiedIngredientSearchPolicy.pageSize + 1,
    );
    final hasNext = values.length > UnifiedIngredientSearchPolicy.pageSize;
    return UnifiedIngredientSearchPage(
      items: values
          .take(UnifiedIngredientSearchPolicy.pageSize)
          .map(UnifiedIngredientSearchItem.personal)
          .toList(),
      page: safePage,
      hasNext: hasNext,
      hasPrevious: safePage > 0,
    );
  }

  Future<UnifiedIngredientSearchPage> searchOpenNutrition({
    required String query,
    int page = 0,
  }) async {
    final safePage = page < 0 ? 0 : page;
    if (!UnifiedIngredientSearchPolicy.canSearchOpenNutrition(query) ||
        !await isOpenNutritionAvailable()) {
      return UnifiedIngredientSearchPage(
        items: const <UnifiedIngredientSearchItem>[],
        page: safePage,
        hasNext: false,
        hasPrevious: safePage > 0,
      );
    }
    final values = await openNutritionRepository.search(
      query: query,
      offset: safePage * UnifiedIngredientSearchPolicy.pageSize,
      limit: UnifiedIngredientSearchPolicy.pageSize + 1,
    );
    final hasNext = values.length > UnifiedIngredientSearchPolicy.pageSize;
    return UnifiedIngredientSearchPage(
      items: values
          .take(UnifiedIngredientSearchPolicy.pageSize)
          .map(UnifiedIngredientSearchItem.openNutrition)
          .toList(),
      page: safePage,
      hasNext: hasNext,
      hasPrevious: safePage > 0,
    );
  }

  /// Compatibility method for existing callers. New UI should call the two
  /// independent methods so the sections never share pagination.
  Future<UnifiedIngredientSearchPage> search({
    required String query,
    required String scopeCode,
    int page = 0,
  }) {
    if (scopeCode == UnifiedIngredientSearchScopeCodes.openNutrition) {
      return searchOpenNutrition(query: query, page: page);
    }
    return searchPersonal(query: query, page: page);
  }

  IngredientEntity promote(OpenNutritionFoodEntity food) {
    final existing = personalRepository.findByExternalSource(
      IngredientSourceTypeCodes.openNutrition,
      food.externalFoodId,
    );
    if (existing != null) return existing;
    if (food.barcode.trim().isNotEmpty) {
      final byBarcode = personalRepository.findByBarcode(food.barcode);
      if (byBarcode != null) return byBarcode;
    }

    final attribution = food.fromOpenFoodFacts
        ? 'OpenNutrition; © Open Food Facts contributors'
        : 'OpenNutrition';
    return personalRepository.save(
      IngredientEntity(
        uuid: const Uuid().v4(),
        name: food.name,
        brand: food.brand,
        barcode: food.barcode,
        sourceTypeCode: IngredientSourceTypeCodes.openNutrition,
        sourceName: 'OpenNutrition',
        sourceUrl:
            'https://www.opennutrition.app/search?search=${Uri.encodeQueryComponent(food.name)}',
        sourceExternalId: food.externalFoodId,
        sourceDatasetVersion: food.datasetVersion,
        sourceLicenseCode: 'ODbL-1.0 / modified DbCL-1.0',
        sourceAttribution: attribution,
        wasModifiedByUser: false,
        imageUrl: food.imageUrl.isNotEmpty
            ? food.imageUrl
            : food.imageSmallUrl,
        nutritionReferenceAmount: 100,
        kcalPerReference: food.kcalPer100g,
        proteinPerReference: food.proteinPer100g,
        carbsPerReference: food.carbsPer100g,
        fatPerReference: food.fatPer100g,
        fiberPerReference: food.fiberPer100g,
        sugarPerReference: food.sugarPer100g,
        saltPerReference: food.saltPer100g,
        notes: food.hasEstimatedValues
            ? 'OpenNutrition segnala valori stimati o derivati.'
            : '',
        createdAtEpochMs: 0,
        updatedAtEpochMs: 0,
      ),
    );
  }
}
