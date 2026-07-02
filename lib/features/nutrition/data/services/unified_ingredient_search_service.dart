import 'package:uuid/uuid.dart';

import '../entities/ingredient_entity.dart';
import '../entities/open_nutrition_food_entity.dart';
import '../repositories/ingredient_repository.dart';
import '../repositories/open_nutrition_catalog_repository.dart';
import '../../domain/nutrition_codes.dart';

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
  double get kcalPer100g =>
      personalIngredient?.kcalPerReference ??
      openNutritionFood?.kcalPer100g ??
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
  static bool canSearchOpenNutrition(String query) => query.trim().length >= 2;
  static int remainingAfterPersonal(int personalCount) =>
      (pageSize - personalCount).clamp(0, pageSize).toInt();

  static int externalOffsetForCombinedPage({
    required int page,
    required int externalAlreadyShown,
  }) {
    if (page <= 0) return 0;
    return externalAlreadyShown + (page - 1) * pageSize;
  }
}

class UnifiedIngredientSearchService {
  UnifiedIngredientSearchService({
    required this.personalRepository,
    required this.openNutritionRepository,
  });

  final IngredientRepository personalRepository;
  final OpenNutritionCatalogRepository openNutritionRepository;

  Future<UnifiedIngredientSearchPage> search({
    required String query,
    required String scopeCode,
    int page = 0,
  }) async {
    final safePage = page < 0 ? 0 : page;
    final offset = safePage * UnifiedIngredientSearchPolicy.pageSize;

    if (scopeCode == UnifiedIngredientSearchScopeCodes.personal) {
      final personal = personalRepository.searchByNameLimited(
        query,
        offset: offset,
        limit: UnifiedIngredientSearchPolicy.pageSize + 1,
      );
      return _personalPage(personal, safePage);
    }

    if (scopeCode == UnifiedIngredientSearchScopeCodes.openNutrition) {
      if (!UnifiedIngredientSearchPolicy.canSearchOpenNutrition(query)) {
        return UnifiedIngredientSearchPage(
          items: const <UnifiedIngredientSearchItem>[],
          page: safePage,
          hasNext: false,
          hasPrevious: safePage > 0,
        );
      }
      final external = await openNutritionRepository.search(
        query: query,
        offset: offset,
        limit: UnifiedIngredientSearchPolicy.pageSize + 1,
      );
      final hasNext = external.length > UnifiedIngredientSearchPolicy.pageSize;
      return UnifiedIngredientSearchPage(
        items: external
            .take(UnifiedIngredientSearchPolicy.pageSize)
            .map(UnifiedIngredientSearchItem.openNutrition)
            .toList(),
        page: safePage,
        hasNext: hasNext,
        hasPrevious: safePage > 0,
      );
    }

    if (safePage > 0) {
      if (!UnifiedIngredientSearchPolicy.canSearchOpenNutrition(query)) {
        return UnifiedIngredientSearchPage(
          items: const <UnifiedIngredientSearchItem>[],
          page: safePage,
          hasNext: false,
          hasPrevious: true,
        );
      }
      final firstPagePersonal = personalRepository.searchByNameLimited(
        query,
        limit: UnifiedIngredientSearchPolicy.pageSize,
      );
      final externalAlreadyShown =
          UnifiedIngredientSearchPolicy.remainingAfterPersonal(
        firstPagePersonal.length,
      );
      final externalOffset =
          UnifiedIngredientSearchPolicy.externalOffsetForCombinedPage(
        page: safePage,
        externalAlreadyShown: externalAlreadyShown,
      );
      final external = await openNutritionRepository.search(
        query: query,
        offset: externalOffset,
        limit: UnifiedIngredientSearchPolicy.pageSize + 1,
      );
      final hasNext = external.length > UnifiedIngredientSearchPolicy.pageSize;
      return UnifiedIngredientSearchPage(
        items: external
            .take(UnifiedIngredientSearchPolicy.pageSize)
            .map(UnifiedIngredientSearchItem.openNutrition)
            .toList(),
        page: safePage,
        hasNext: hasNext,
        hasPrevious: true,
      );
    }

    final personal = personalRepository.searchByNameLimited(
      query,
      limit: UnifiedIngredientSearchPolicy.pageSize,
    );
    final remaining = UnifiedIngredientSearchPolicy.remainingAfterPersonal(
      personal.length,
    );
    final canSearchExternal =
        UnifiedIngredientSearchPolicy.canSearchOpenNutrition(query);
    final external = canSearchExternal
        ? await openNutritionRepository.search(
            query: query,
            limit: remaining > 0 ? remaining + 1 : 1,
          )
        : <OpenNutritionFoodEntity>[];
    final items = <UnifiedIngredientSearchItem>[
      ...personal.map(UnifiedIngredientSearchItem.personal),
      ...external
          .take(remaining)
          .map(UnifiedIngredientSearchItem.openNutrition),
    ];
    return UnifiedIngredientSearchPage(
      items: items.take(UnifiedIngredientSearchPolicy.pageSize).toList(),
      page: 0,
      hasNext: external.length > remaining,
      hasPrevious: false,
    );
  }

  UnifiedIngredientSearchPage _personalPage(
    List<IngredientEntity> values,
    int page,
  ) {
    final hasNext = values.length > UnifiedIngredientSearchPolicy.pageSize;
    return UnifiedIngredientSearchPage(
      items: values
          .take(UnifiedIngredientSearchPolicy.pageSize)
          .map(UnifiedIngredientSearchItem.personal)
          .toList(),
      page: page,
      hasNext: hasNext,
      hasPrevious: page > 0,
    );
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
