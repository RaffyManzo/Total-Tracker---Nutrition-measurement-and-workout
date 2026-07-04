import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../../core/background/background_tasks.dart';
import '../../../../core/network/open_nutrition_network_access.dart';
import '../../../../core/preferences/food_service_preferences.dart';
import '../../domain/nutrition_codes.dart';
import '../config/open_nutrition_rollout_config.dart';
import '../entities/ingredient_entity.dart';
import '../entities/open_nutrition_food_entity.dart';
import '../repositories/ingredient_repository.dart';
import '../repositories/open_nutrition_catalog_repository.dart';
import 'open_food_facts_service.dart';
import 'open_nutrition_gateway_service.dart';
import 'open_nutrition_static_index_service.dart';
import 'open_nutrition_translation_service.dart';

class UnifiedIngredientSearchScopeCodes {
  const UnifiedIngredientSearchScopeCodes._();

  static const String all = 'all';
  static const String personal = 'personal';
  static const String openNutrition = 'open_nutrition';
  static const String openFoodFacts = 'open_food_facts';
}

enum OpenNutritionSearchMode {
  unavailable,
  staticIndex,
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

  bool get isStaticOpenNutrition =>
      openNutritionFood?.importBatchId.startsWith('static:') ?? false;

  bool get requiresOpenNutritionImportConfirmation =>
      isRemoteOpenNutrition || isStaticOpenNutrition;

  bool get isMachineTranslatedOpenNutrition =>
      openNutritionFood?.additionalFieldsJson.contains(
        '"machineTranslated":true',
      ) ??
      false;

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

class ExternalSearchRetryException implements Exception {
  const ExternalSearchRetryException({
    required this.sourceName,
    required this.retryCount,
    required this.lastError,
  });

  final String sourceName;
  final int retryCount;
  final Object lastError;

  @override
  String toString() {
    return '$sourceName non disponibile dopo $retryCount tentativi '
        'automatici. Ultimo errore: $lastError';
  }
}

class UnifiedIngredientSearchService {
  UnifiedIngredientSearchService({
    required this.personalRepository,
    required this.openNutritionRepository,
    required this.openNutritionGatewayService,
    required this.openNutritionStaticIndexService,
    required this.openNutritionTranslationService,
    required this.openFoodFactsService,
  });

  final IngredientRepository personalRepository;
  final OpenNutritionCatalogRepository openNutritionRepository;
  final OpenNutritionGatewayService openNutritionGatewayService;
  final OpenNutritionStaticIndexService openNutritionStaticIndexService;
  final OpenNutritionTranslationService openNutritionTranslationService;
  final OpenFoodFactsService openFoodFactsService;

  Future<OpenNutritionSearchMode> openNutritionSearchMode() async {
    if (!await FoodServicePreferences.isOpenNutritionSearchEnabled()) {
      return OpenNutritionSearchMode.unavailable;
    }

    if (OpenNutritionRolloutConfig.staticIndexConfigured &&
        openNutritionStaticIndexService.isConfigured) {
      return OpenNutritionSearchMode.staticIndex;
    }

    if (OpenNutritionRolloutConfig.legacyLocalCatalogEnabled) {
      final OpenNutritionBackgroundJobState backgroundJob =
          await OpenNutritionBackgroundJobs.readState();
      if (!backgroundJob.isRunning) {
        try {
          final state = await openNutritionRepository.getState();
          final bool localAvailable = state.activeBatchId.isNotEmpty &&
              state.importStatusCode == 'installed' &&
              await openNutritionRepository.countActive() > 0;
          if (localAvailable) return OpenNutritionSearchMode.local;
        } catch (_) {
          // Il catalogo può essere temporaneamente esclusivo del worker.
          // In questo caso si tenta la sorgente successiva.
        }
      }
    }

    if (OpenNutritionRolloutConfig.legacyGatewayEnabled &&
        await openNutritionGatewayService.isConfigured()) {
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

    if (mode == OpenNutritionSearchMode.staticIndex ||
        mode == OpenNutritionSearchMode.remote) {
      final OpenNutritionNetworkPolicy policy =
          await FoodServicePreferences.getOpenNutritionNetworkPolicy();
      final OpenNutritionNetworkDecision decision =
          await OpenNutritionNetworkAccess.evaluate(policy);
      if (!decision.allowed) {
        throw OpenNutritionNetworkPolicyException(decision.message);
      }
    }

    if (mode == OpenNutritionSearchMode.staticIndex) {
      return _withNetworkRetries<UnifiedIngredientSearchPage>(
        sourceName: 'OpenNutrition',
        action: () async {
          final String canonicalQuery =
              await openNutritionTranslationService.translateQueryToEnglish(
            query,
          );
          final OpenNutritionStaticSearchPage response =
              await openNutritionStaticIndexService.search(
            query: canonicalQuery,
            page: safePage,
            limit: UnifiedIngredientSearchPolicy.openNutritionRemotePageSize,
          );
          final List<OpenNutritionFoodEntity> translatedFoods =
              await openNutritionTranslationService.translateFoodsFromEnglish(
            response.foods,
          );
          return UnifiedIngredientSearchPage(
            items: translatedFoods
                .map(UnifiedIngredientSearchItem.openNutrition)
                .toList(growable: false),
            page: response.page,
            hasNext: response.hasNext,
            hasPrevious: safePage > 0,
          );
        },
      );
    }

    if (mode == OpenNutritionSearchMode.remote) {
      return _withNetworkRetries<UnifiedIngredientSearchPage>(
        sourceName: 'OpenNutrition',
        action: () async {
          final OpenNutritionGatewaySearchPage response =
              await openNutritionGatewayService.search(
            query: query,
            page: safePage,
            limit: UnifiedIngredientSearchPolicy.openNutritionRemotePageSize,
          );
          return UnifiedIngredientSearchPage(
            items: response.foods
                .map(UnifiedIngredientSearchItem.openNutrition)
                .toList(growable: false),
            page: response.page,
            hasNext: response.hasNext,
            hasPrevious: safePage > 0,
          );
        },
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
          .toList(growable: false),
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

    return _withNetworkRetries<UnifiedIngredientSearchPage>(
      sourceName: 'Open Food Facts',
      action: () async {
        final OpenFoodFactsSearchResponse response =
            await openFoodFactsService.searchTextPage(
          query,
          page: safePage + 1,
          pageSize: UnifiedIngredientSearchPolicy.openFoodFactsPageSize,
        );
        return UnifiedIngredientSearchPage(
          items: response.products
              .map(UnifiedIngredientSearchItem.openFoodFacts)
              .toList(growable: false),
          page: safePage,
          hasNext: response.hasNext,
          hasPrevious: safePage > 0,
        );
      },
    );
  }

  static const int _networkRetryCount = 20;
  static const Duration _networkRetryBaseDelay = Duration(milliseconds: 250);
  static const Duration _networkRetryMaximumDelay = Duration(seconds: 2);

  Future<T> _withNetworkRetries<T>({
    required String sourceName,
    required Future<T> Function() action,
  }) async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (int attempt = 0; attempt <= _networkRetryCount; attempt++) {
      try {
        return await action();
      } catch (error, stackTrace) {
        if (!_isTransientNetworkError(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }

        lastError = error;
        lastStackTrace = stackTrace;
        if (attempt >= _networkRetryCount) break;
        await Future<void>.delayed(_retryDelay(attempt + 1));
      }
    }

    final ExternalSearchRetryException exhausted = ExternalSearchRetryException(
      sourceName: sourceName,
      retryCount: _networkRetryCount,
      lastError: lastError ?? StateError('Errore di rete non specificato.'),
    );
    if (lastStackTrace != null) {
      Error.throwWithStackTrace(exhausted, lastStackTrace);
    }
    throw exhausted;
  }

  Duration _retryDelay(int retryNumber) {
    final int linearMilliseconds =
        _networkRetryBaseDelay.inMilliseconds * retryNumber;
    final int cappedMilliseconds = linearMilliseconds
        .clamp(
          _networkRetryBaseDelay.inMilliseconds,
          _networkRetryMaximumDelay.inMilliseconds,
        )
        .toInt();
    final int deterministicJitter = (retryNumber * 73) % 200;
    return Duration(milliseconds: cappedMilliseconds + deterministicJitter);
  }

  bool _isTransientNetworkError(Object error) {
    if (error is TimeoutException ||
        error is SocketException ||
        error is HttpException ||
        error is http.ClientException) {
      return true;
    }
    if (error is OpenNutritionNetworkPolicyException) return false;

    final String message = error.toString().toLowerCase();
    const List<String> permanentMarkers = <String>[
      'non configurato',
      'hash manifest',
      'hash o dimensione shard',
      'schema manifest',
      'schema shard',
      'manifest incompatibile',
      'descrittore shard',
      'redirect opennutrition',
      'url opennutrition non sicuro',
      'shard opennutrition non valido o danneggiato',
      'dimensione risposta opennutrition non consentita',
      'risposta opennutrition oltre il limite consentito',
    ];
    if (permanentMarkers.any(message.contains)) return false;

    final RegExpMatch? statusMatch =
        RegExp(r'http[^0-9]*(\d{3})').firstMatch(message);
    if (statusMatch != null) {
      final int? statusCode = int.tryParse(statusMatch.group(1)!);
      if (statusCode != null) {
        return statusCode == 408 ||
            statusCode == 425 ||
            statusCode == 429 ||
            statusCode >= 500;
      }
    }

    const List<String> transientMarkers = <String>[
      'client is already closed',
      'connection reset',
      'connection refused',
      'connection aborted',
      'connection closed',
      'closed before full header',
      'failed host lookup',
      'network is unreachable',
      'network unreachable',
      'temporary failure',
      'timed out',
      'timeout',
      'handshakeexception',
      'socketexception',
      'clientexception',
      'http request failed',
      'risposta opennutrition vuota',
    ];
    return transientMarkers.any(message.contains);
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
    final bool staticIndex = food.importBatchId.startsWith('static:');

    return personalRepository.save(
      IngredientEntity(
        uuid: const Uuid().v4(),
        name: food.name,
        brand: food.brand,
        barcode: food.barcode,
        sourceTypeCode: IngredientSourceTypeCodes.openNutrition,
        sourceName: staticIndex
            ? 'OpenNutrition tramite indice statico verificato'
            : remote
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
          if (staticIndex)
            'Record ottenuto da uno shard OpenNutrition HTTPS verificato '
                'tramite SHA-256 e selezionato localmente.',
          if (food.additionalFieldsJson.contains(
            '"machineTranslated":true',
          ))
            'Nome tradotto automaticamente sul dispositivo tramite '
                'Google Translate.',
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
