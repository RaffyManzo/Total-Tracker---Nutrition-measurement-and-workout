import 'package:uuid/uuid.dart';

import '../../../../core/preferences/food_service_preferences.dart';
import '../../domain/nutrition_codes.dart';
import '../entities/ingredient_entity.dart';
import '../entities/open_nutrition_food_entity.dart';
import '../repositories/ingredient_repository.dart';
import '../repositories/open_nutrition_catalog_repository.dart';
import 'open_food_facts_service.dart';
import 'open_nutrition_gateway_service.dart';

class UnifiedIngredientSearchScopeCodes {
  const UnifiedIngredientSearchScopeCodes._();

  static const String all = 'all';
  static const String personal = 'personal';
  static const String openNutrition = 'open_nutrition';
  static const String openFoodFacts = 'open_food_facts';
}

enum OpenNutritionSearchMode {
  unavailable,
  local,
  remote,
}

class UnifiedIngredientSearchItem {
  const UnifiedIngredientSearchItem.personal(
    this.personalIngredient,
  )   : openNutritionFood = null,
        openFoodFactsProduct = null;

  const UnifiedIngredientSearchItem.openNutrition(
    this.openNutritionFood,
  )   : personalIngredient = null,
        openFoodFactsProduct = null;

  const UnifiedIngredientSearchItem.openFoodFacts(
    this.openFoodFactsProduct,
  )   : personalIngredient = null,
        openNutritionFood = null;

  final IngredientEntity? personalIngredient;
  final OpenNutritionFoodEntity? openNutritionFood;
  final OpenFoodFactsProduct? openFoodFactsProduct;

  bool get isPersonal => personalIngredient != null;
  bool get isOpenNutrition => openNutritionFood != null;
  bool get isOpenFoodFacts => openFoodFactsProduct != null;
  bool get isRemoteOpenNutrition =>
      openNutritionFood?.importBatchId.startsWith('remote:') ?? false;

  String get displayName =>
      personalIngredient?.name ??
      openNutritionFood?.name ??
      openFoodFactsProduct?.name ??
      '';

  String get brand =>
      personalIngredient?.brand ??
      openNutritionFood?.brand ??
      openFoodFactsProduct?.brand ??
      '';

  String get imageUrl =>
      personalIngredient?.imageUrl ??
      (openNutritionFood == null
          ? null
          : openNutritionFood!.imageSmallUrl.isNotEmpty
              ? openNutritionFood!.imageSmallUrl
              : openNutritionFood!.imageUrl) ??
      openFoodFactsProduct?.preferredImageUrl ??
      '';

  String get sourceTypeCode {
    if (personalIngredient != null) {
      return personalIngredient!.sourceTypeCode;
    }
    if (openFoodFactsProduct != null) {
      return IngredientSourceTypeCodes.openFoodFacts;
    }
    return IngredientSourceTypeCodes.openNutrition;
  }

  double get kcalPer100g =>
      personalIngredient?.kcalPerReference ??
      openNutritionFood?.kcalPer100g ??
      openFoodFactsProduct?.kcal100 ??
      0;

  double get proteinPer100g =>
      personalIngredient?.proteinPerReference ??
      openNutritionFood?.proteinPer100g ??
      openFoodFactsProduct?.protein100 ??
      0;

  double get carbsPer100g =>
      personalIngredient?.carbsPerReference ??
      openNutritionFood?.carbsPer100g ??
      openFoodFactsProduct?.carbs100 ??
      0;

  double get fatPer100g =>
      personalIngredient?.fatPerReference ??
      openNutritionFood?.fatPer100g ??
      openFoodFactsProduct?.fat100 ??
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
  static const int openFoodFactsPageSize = 20;
  static const int openNutritionRemotePageSize = 20;
  static const int initialLocalLimit = 50;

  static int remainingAfterPersonal(int personalCount) {
    if (personalCount <= 0) return pageSize;
    if (personalCount >= pageSize) return 0;
    return pageSize - personalCount;
  }

  static int externalOffsetForCombinedPage({
    required int page,
    required int externalAlreadyShown,
  }) {
    final int safePage = page < 1 ? 1 : page;
    final int safeAlreadyShown =
        externalAlreadyShown < 0 ? 0 : externalAlreadyShown;
    return ((safePage - 1) * pageSize) + safeAlreadyShown;
  }

  static bool canSearchOpenNutrition(String query) => query.trim().length >= 2;

  static bool canSearchOpenFoodFacts(String query) => query.trim().length >= 3;
}

class UnifiedIngredientSearchService {
  UnifiedIngredientSearchService({
    required this.personalRepository,
    required this.openNutritionRepository,
    required this.openNutritionGatewayService,
    required this.openFoodFactsService,
  });

  final IngredientRepository personalRepository;
  final OpenNutritionCatalogRepository openNutritionRepository;
  final OpenNutritionGatewayService openNutritionGatewayService;
  final OpenFoodFactsService openFoodFactsService;

  Future<OpenNutritionSearchMode> openNutritionSearchMode() async {
    if (!await FoodServicePreferences.isOpenNutritionSearchEnabled()) {
      return OpenNutritionSearchMode.unavailable;
    }

    final state = await openNutritionRepository.getState();
    final bool localAvailable = state.activeBatchId.isNotEmpty &&
        state.importStatusCode == 'installed' &&
        await openNutritionRepository.countActive() > 0;
    if (localAvailable) return OpenNutritionSearchMode.local;

    if (await openNutritionGatewayService.isConfigured()) {
      return OpenNutritionSearchMode.remote;
    }
    return OpenNutritionSearchMode.unavailable;
  }

  Future<bool> isOpenNutritionAvailable() async {
    return await openNutritionSearchMode() !=
        OpenNutritionSearchMode.unavailable;
  }

  Future<bool> isOpenFoodFactsAvailable() {
    return FoodServicePreferences.isOpenFoodFactsEnabled();
  }

  Future<UnifiedIngredientSearchPage> searchPersonal({
    required String query,
    int page = 0,
  }) async {
    final int safePage = page < 0 ? 0 : page;
    if (query.trim().isEmpty) {
      final List<IngredientEntity> values = personalRepository.getRecentActive(
        limit: UnifiedIngredientSearchPolicy.initialLocalLimit,
      );
      return UnifiedIngredientSearchPage(
        items: values.map(UnifiedIngredientSearchItem.personal).toList(),
        page: 0,
        hasNext: false,
        hasPrevious: false,
      );
    }

    final List<IngredientEntity> values =
        personalRepository.searchByNameLimited(
      query,
      offset: safePage * UnifiedIngredientSearchPolicy.pageSize,
      limit: UnifiedIngredientSearchPolicy.pageSize + 1,
    );
    final bool hasNext = values.length > UnifiedIngredientSearchPolicy.pageSize;

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
    final int safePage = page < 0 ? 0 : page;
    if (!UnifiedIngredientSearchPolicy.canSearchOpenNutrition(query)) {
      return UnifiedIngredientSearchPage(
        items: const <UnifiedIngredientSearchItem>[],
        page: safePage,
        hasNext: false,
        hasPrevious: safePage > 0,
      );
    }

    final OpenNutritionSearchMode mode = await openNutritionSearchMode();
    if (mode == OpenNutritionSearchMode.unavailable) {
      return UnifiedIngredientSearchPage(
        items: const <UnifiedIngredientSearchItem>[],
        page: safePage,
        hasNext: false,
        hasPrevious: safePage > 0,
      );
    }

    if (mode == OpenNutritionSearchMode.remote) {
      final OpenNutritionGatewaySearchPage response =
          await openNutritionGatewayService.search(
        query: query,
        page: safePage,
        limit: UnifiedIngredientSearchPolicy.openNutritionRemotePageSize,
      );
      return UnifiedIngredientSearchPage(
        items: response.foods
            .map(UnifiedIngredientSearchItem.openNutrition)
            .toList(),
        page: response.page,
        hasNext: response.hasNext,
        hasPrevious: safePage > 0,
      );
    }

    final List<OpenNutritionFoodEntity> values =
        await openNutritionRepository.search(
      query: query,
      offset: safePage * UnifiedIngredientSearchPolicy.pageSize,
      limit: UnifiedIngredientSearchPolicy.pageSize + 1,
    );
    final bool hasNext = values.length > UnifiedIngredientSearchPolicy.pageSize;

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

  Future<UnifiedIngredientSearchPage> searchOpenFoodFacts({
    required String query,
    int page = 0,
  }) async {
    final int safePage = page < 0 ? 0 : page;
    if (!UnifiedIngredientSearchPolicy.canSearchOpenFoodFacts(query) ||
        !await isOpenFoodFactsAvailable()) {
      return UnifiedIngredientSearchPage(
        items: const <UnifiedIngredientSearchItem>[],
        page: safePage,
        hasNext: false,
        hasPrevious: safePage > 0,
      );
    }

    final OpenFoodFactsSearchResponse response =
        await openFoodFactsService.searchTextPage(
      query,
      page: safePage + 1,
      pageSize: UnifiedIngredientSearchPolicy.openFoodFactsPageSize,
    );

    return UnifiedIngredientSearchPage(
      items: response.products
          .map(UnifiedIngredientSearchItem.openFoodFacts)
          .toList(),
      page: safePage,
      hasNext: response.hasNext,
      hasPrevious: safePage > 0,
    );
  }

  Future<UnifiedIngredientSearchPage> search({
    required String query,
    required String scopeCode,
    int page = 0,
  }) {
    if (scopeCode == UnifiedIngredientSearchScopeCodes.openNutrition) {
      return searchOpenNutrition(query: query, page: page);
    }
    if (scopeCode == UnifiedIngredientSearchScopeCodes.openFoodFacts) {
      return searchOpenFoodFacts(query: query, page: page);
    }
    return searchPersonal(query: query, page: page);
  }

  IngredientEntity promote(OpenNutritionFoodEntity food) {
    final IngredientEntity? existing = personalRepository.findByExternalSource(
      IngredientSourceTypeCodes.openNutrition,
      food.externalFoodId,
    );
    if (existing != null) return existing;

    if (food.barcode.trim().isNotEmpty) {
      final IngredientEntity? byBarcode =
          personalRepository.findByBarcode(food.barcode);
      if (byBarcode != null) return byBarcode;
    }

    final String attribution = food.fromOpenFoodFacts
        ? 'OpenNutrition; © Open Food Facts contributors'
        : 'OpenNutrition';
    final bool remote = food.importBatchId.startsWith('remote:');

    return personalRepository.save(
      IngredientEntity(
        uuid: const Uuid().v4(),
        name: food.name,
        brand: food.brand,
        barcode: food.barcode,
        sourceTypeCode: IngredientSourceTypeCodes.openNutrition,
        sourceName: remote
            ? 'OpenNutrition tramite gateway verificato'
            : 'OpenNutrition',
        sourceUrl: 'https://www.opennutrition.app/search?search='
            '${Uri.encodeQueryComponent(food.name)}',
        sourceExternalId: food.externalFoodId,
        sourceDatasetVersion: food.datasetVersion,
        sourceLicenseCode: 'ODbL-1.0 / modified DbCL-1.0',
        sourceAttribution: attribution,
        wasModifiedByUser: false,
        imageUrl:
            food.imageSmallUrl.isNotEmpty ? food.imageSmallUrl : food.imageUrl,
        nutritionReferenceAmount: 100,
        kcalPerReference: food.kcalPer100g,
        proteinPerReference: food.proteinPer100g,
        carbsPerReference: food.carbsPer100g,
        fatPerReference: food.fatPer100g,
        fiberPerReference: food.fiberPer100g,
        sugarPerReference: food.sugarPer100g,
        saltPerReference: food.saltPer100g,
        notes: <String>[
          if (remote)
            'Record ottenuto singolarmente da un gateway OpenNutrition '
                'HTTPS con risposta firmata Ed25519.',
          if (food.hasEstimatedValues)
            'OpenNutrition segnala valori stimati o derivati.',
        ].join(' '),
        createdAtEpochMs: 0,
        updatedAtEpochMs: 0,
      ),
    );
  }
}
