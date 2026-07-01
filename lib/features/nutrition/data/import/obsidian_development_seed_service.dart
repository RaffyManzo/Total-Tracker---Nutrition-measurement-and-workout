import 'package:flutter/services.dart';
import 'package:objectbox/objectbox.dart';

import '../../domain/nutrition_codes.dart';
import '../entities/ingredient_entity.dart';
import '../entities/nutrition_tracking_entities.dart';
import '../repositories/daily_record_repository.dart';
import '../repositories/ingredient_repository.dart';
import '../repositories/meal_repository.dart';
import 'obsidian_food_seed.dart';

class ObsidianDevelopmentSeedReport {
  const ObsidianDevelopmentSeedReport({
    required this.seedFound,
    required this.days,
    required this.meals,
    required this.mealItems,
    required this.ingredients,
    required this.skipped,
    required this.warnings,
  });

  final bool seedFound;
  final int days;
  final int meals;
  final int mealItems;
  final int ingredients;
  final int skipped;
  final List<Map<String, dynamic>> warnings;

  bool get hasWarnings => warnings.isNotEmpty;

  @override
  String toString() {
    return 'ObsidianDevelopmentSeedReport('
        'seedFound: $seedFound, days: $days, meals: $meals, '
        'mealItems: $mealItems, ingredients: $ingredients, '
        'skipped: $skipped, warnings: ${warnings.length})';
  }
}

class ObsidianDevelopmentSeedService {
  ObsidianDevelopmentSeedService(
    Store store, {
    this.assetPath = ObsidianFoodSeedConstants.defaultAssetPath,
    AssetBundle? assetBundle,
  })  : _store = store,
        _assetBundle = assetBundle ?? rootBundle,
        _mapper = const ObsidianFoodSeedMapper(),
        _dailyRecords = DailyRecordRepository(store),
        _meals = MealRepository(store),
        _ingredients = IngredientRepository(store);

  final Store _store;
  final String assetPath;
  final AssetBundle _assetBundle;
  final ObsidianFoodSeedMapper _mapper;
  final DailyRecordRepository _dailyRecords;
  final MealRepository _meals;
  final IngredientRepository _ingredients;

  Future<ObsidianDevelopmentSeedReport> importFromAssetIfPresent() async {
    String seedJson;
    try {
      seedJson = await _assetBundle.loadString(assetPath);
    } on Object {
      return const ObsidianDevelopmentSeedReport(
        seedFound: false,
        days: 0,
        meals: 0,
        mealItems: 0,
        ingredients: 0,
        skipped: 0,
        warnings: <Map<String, dynamic>>[],
      );
    }
    return importFromJson(seedJson);
  }

  ObsidianDevelopmentSeedReport importFromJson(String seedJson) {
    final Map<String, dynamic> seed = _mapper.decodeSeed(seedJson);
    if (seed['schemaVersion'] != ObsidianFoodSeedConstants.schemaVersion) {
      throw FormatException('Unsupported Obsidian seed schema.');
    }

    final List<Map<String, dynamic>> days = _listOfMaps(seed['days'], 'days');
    final List<Map<String, dynamic>> meals =
        _listOfMaps(seed['meals'], 'meals');
    final List<Map<String, dynamic>> mealItems =
        _listOfMaps(seed['mealItems'], 'mealItems');
    final List<Map<String, dynamic>> warnings =
        _listOfMaps(seed['warnings'], 'warnings');
    final Set<String> dayUuids = <String>{
      for (final Map<String, dynamic> day in days)
        _mapper.readString(day['uuid'])
    };
    final Set<String> mealUuids = <String>{
      for (final Map<String, dynamic> meal in meals)
        _mapper.readString(meal['uuid'])
    };
    final Set<String> mealItemUuids = <String>{
      for (final Map<String, dynamic> item in mealItems)
        _mapper.readString(item['uuid'])
    };
    final Set<String> ingredientUuids = <String>{};
    final Map<String, List<Map<String, dynamic>>> itemsByMealUuid =
        <String, List<Map<String, dynamic>>>{};

    for (final Map<String, dynamic> item in mealItems) {
      final String mealUuid = _mapper.readString(item['mealUuid']);
      itemsByMealUuid
          .putIfAbsent(mealUuid, () => <Map<String, dynamic>>[])
          .add(item);
      if (_mapper.readString(item['kind']) == 'ingredient') {
        final IngredientEntity? ingredient = _ingredientFromItem(item);
        if (ingredient != null) {
          ingredientUuids.add(ingredient.uuid);
        }
      }
    }

    _removeStaleImportedFoodData(
      dayUuids: dayUuids,
      mealUuids: mealUuids,
      mealItemUuids: mealItemUuids,
      ingredientUuids: ingredientUuids,
    );

    _store.runInTransaction(TxMode.write, () {
      for (final Map<String, dynamic> rawDay in days) {
        _dailyRecords.upsertImported(_dayFromSeed(rawDay));
      }
    });

    for (final Map<String, dynamic> rawMeal in meals) {
      final String mealUuid = _mapper.readString(rawMeal['uuid']);
      final MealEntity meal = _mealFromSeed(rawMeal);
      final List<MealItemEntity> items =
          (itemsByMealUuid[mealUuid] ?? const <Map<String, dynamic>>[])
              .map(_mealItemFromSeed)
              .toList();
      _meals.upsertImported(meal, items);
    }

    final Set<String> importedIngredientUuids = <String>{};
    _store.runInTransaction(TxMode.write, () {
      for (final Map<String, dynamic> rawItem in mealItems) {
        if (_mapper.readString(rawItem['kind']) != 'ingredient') {
          continue;
        }
        final IngredientEntity? ingredient = _ingredientFromItem(rawItem);
        if (ingredient == null) {
          continue;
        }
        final IngredientEntity? existing =
            _ingredients.findByUuid(ingredient.uuid);
        if (existing != null) {
          ingredient.id = existing.id;
          ingredient.createdAtEpochMs = existing.createdAtEpochMs;
        }
        _ingredients.save(ingredient);
        importedIngredientUuids.add(ingredient.uuid);
      }
    });

    return ObsidianDevelopmentSeedReport(
      seedFound: true,
      days: days.length,
      meals: meals.length,
      mealItems: mealItems.length,
      ingredients: importedIngredientUuids.length,
      skipped: _readCount(seed, 'skipped'),
      warnings: warnings,
    );
  }

  void _removeStaleImportedFoodData({
    required Set<String> dayUuids,
    required Set<String> mealUuids,
    required Set<String> mealItemUuids,
    required Set<String> ingredientUuids,
  }) {
    _store.runInTransaction(TxMode.write, () {
      final Box<MealItemEntity> itemBox = _store.box<MealItemEntity>();
      final Box<MealEntity> mealBox = _store.box<MealEntity>();
      final Box<DailyRecordEntity> dayBox = _store.box<DailyRecordEntity>();
      final Box<IngredientEntity> ingredientBox =
          _store.box<IngredientEntity>();

      final List<int> staleItemIds = itemBox
          .getAll()
          .where(
            (MealItemEntity item) =>
                item.uuid.startsWith('obsidian-meal-item:') &&
                !mealItemUuids.contains(item.uuid),
          )
          .map((MealItemEntity item) => item.id)
          .toList();
      if (staleItemIds.isNotEmpty) {
        itemBox.removeMany(staleItemIds);
      }

      final List<int> staleMealIds = mealBox
          .getAll()
          .where(
            (MealEntity meal) =>
                meal.uuid.startsWith('obsidian-meal:') &&
                !mealUuids.contains(meal.uuid),
          )
          .map((MealEntity meal) => meal.id)
          .toList();
      if (staleMealIds.isNotEmpty) {
        mealBox.removeMany(staleMealIds);
      }

      final List<int> staleDayIds = dayBox
          .getAll()
          .where(
            (DailyRecordEntity day) =>
                day.uuid.startsWith('obsidian-day:') &&
                !dayUuids.contains(day.uuid),
          )
          .map((DailyRecordEntity day) => day.id)
          .toList();
      if (staleDayIds.isNotEmpty) {
        dayBox.removeMany(staleDayIds);
      }

      final List<int> staleIngredientIds = ingredientBox
          .getAll()
          .where(
            (IngredientEntity ingredient) =>
                ingredient.uuid.startsWith('obsidian-ingredient:') &&
                !ingredientUuids.contains(ingredient.uuid),
          )
          .map((IngredientEntity ingredient) => ingredient.id)
          .toList();
      if (staleIngredientIds.isNotEmpty) {
        ingredientBox.removeMany(staleIngredientIds);
      }
    });
  }

  DailyRecordEntity _dayFromSeed(Map<String, dynamic> raw) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    return DailyRecordEntity(
      uuid: _mapper.readString(raw['uuid']),
      dateKey: _mapper.readString(raw['date']),
      weekCode: _mapper.readString(raw['week']),
      weekdayCode: _mapper.readString(raw['weekday_key']),
      weekdayLabel: _mapper.readString(raw['weekday_label']),
      weekdayIndex: _mapper.readInt(raw['weekday_index']) ?? 1,
      targetKcal: _mapper.readDouble(raw['target_kcal']),
      targetStatusCode: _mapper.readString(raw['target_status']).isEmpty
          ? 'provisional'
          : _mapper.readString(raw['target_status']),
      targetCalculatedAtEpochMs: _epochMs(raw['target_calculated_at']),
      targetSourceHash: _mapper.readString(raw['target_source_hash']),
      tdeeRefKcal: _mapper.readDouble(raw['tdee_ref_kcal']),
      tdeeTheoreticalKcal: _mapper.readDouble(raw['tdee_theoretical_kcal']),
      tdeeObservedKcal: _mapper.readDouble(raw['tdee_observed_kcal']),
      observedConfidence: _mapper.readDouble(raw['observed_confidence']),
      referenceDaysCount: _mapper.readInt(raw['reference_days_count']),
      validIntakeDays: _mapper.readInt(raw['valid_intake_days']),
      validWeightDays: _mapper.readInt(raw['valid_weight_days']),
      rmrKcal: _mapper.readDouble(raw['rmr_kcal']),
      weightRefKg: _mapper.readDouble(raw['weight_ref_kg']),
      activeRefKcal: _mapper.readDouble(raw['active_ref_kcal']),
      activeKcalSteps: _mapper.readDouble(raw['active_kcal_steps']),
      activeKcalWorkoutCompleted:
          _mapper.readDouble(raw['active_kcal_workout_completed']),
      activeKcalWorkoutInProgress:
          _mapper.readDouble(raw['active_kcal_workout_in_progress']),
      activeKcalWorkoutPlanned:
          _mapper.readDouble(raw['active_kcal_workout_planned']),
      activeKcalWorkoutSkipped:
          _mapper.readDouble(raw['active_kcal_workout_skipped']),
      activeKcalWorkoutUnknown:
          _mapper.readDouble(raw['active_kcal_workout_unknown']),
      activeKcalActual: _mapper.readDouble(raw['active_kcal_actual']),
      activeEffectiveKcal: _mapper.readDouble(raw['active_effective_kcal']),
      activityDeltaKcal: _mapper.readDouble(raw['activity_delta_kcal']),
      activeStatusCode: _mapper.readString(raw['active_status']).isEmpty
          ? 'unknown'
          : _mapper.readString(raw['active_status']),
      caloriesInKcal: _mapper.readDouble(raw['calories_in_kcal']),
      energyBalanceKcal: _mapper.readDouble(raw['energy_balance_kcal']),
      weightKg: _mapper.readDouble(raw['weight_kg']),
      weightReliabilityCode: _mapper.readString(raw['weight_reliability']),
      freeMealModeCode: _mapper.readString(raw['free_meal_mode']).isEmpty
          ? 'none'
          : _mapper.readString(raw['free_meal_mode']),
      freeMealKcal: _mapper.readDouble(raw['free_meal_kcal']),
      freeMealReliabilityCode: _mapper.readString(raw['free_meal_reliability']),
      dataCompletenessScore: _mapper.readDouble(raw['data_completeness_score']),
      waterLiters: _mapper.readDouble(raw['water_l']),
      waterGlasses: _mapper.readInt(raw['water_glasses']),
      sleepDeepHours: _mapper.readDouble(raw['sleep_deep_h']),
      sleepLightHours: _mapper.readDouble(raw['sleep_light_h']),
      sleepQualityCode: _mapper.readString(raw['sleep_quality']),
      steps: _mapper.readInt(raw['steps']) ?? 0,
      stepGoal: _mapper.readInt(raw['step_goal']) ?? 8000,
      notes: _mapper.readString(raw['notes']),
      activityBonusKcal: _mapper.readDouble(raw['activity_bonus_kcal']) ?? 0,
      createdAtEpochMs: now,
      updatedAtEpochMs: now,
    );
  }

  MealEntity _mealFromSeed(Map<String, dynamic> raw) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final MealEntity meal = MealEntity(
      uuid: _mapper.readString(raw['uuid']),
      dateKey: _mapper.readString(raw['date']),
      weekCode: _mapper.readString(raw['week']),
      weekdayCode: _mapper.readString(raw['weekday_key']),
      weekdayLabel: _mapper.readString(raw['weekday_label']),
      mealTypeCode: _mapper.readString(raw['meal_type']),
      title: _mapper.readString(raw['title']).isEmpty
          ? _mapper.readString(raw['meal_type'])
          : _mapper.readString(raw['title']),
      mealModeCode: _mapper.readString(raw['meal_mode']).isEmpty
          ? 'standard'
          : _mapper.readString(raw['meal_mode']),
      freeMealTrackingCode: _mapper.readString(raw['free_meal_tracking']),
      freeMealLabel: _mapper.readString(raw['free_meal_label']),
      freeMealNotes: _mapper.readString(raw['free_meal_notes']),
      createdAtEpochMs: now,
      updatedAtEpochMs: now,
    );
    meal.dailyRecord.target = _dailyRecords.findByDate(meal.dateKey);
    return meal;
  }

  MealItemEntity _mealItemFromSeed(Map<String, dynamic> raw) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    return MealItemEntity(
      uuid: _mapper.readString(raw['uuid']),
      position: _mapper.readInt(raw['position']) ?? 0,
      kindCode: _mapper.readString(raw['kind']),
      sourceUuid: _mapper.readString(raw['source']),
      itemNameSnapshot: _mapper.readString(raw['item_name']),
      quantityModeCode: _mapper.readString(raw['quantity_mode']).isEmpty
          ? 'grams'
          : _mapper.readString(raw['quantity_mode']),
      grams: _mapper.readDouble(raw['grams']),
      portions: _mapper.readDouble(raw['portions']),
      kcal: _mapper.readDouble(raw['kcal']) ?? 0,
      proteinGrams: _mapper.readDouble(raw['protein_g']) ?? 0,
      carbsGrams: _mapper.readDouble(raw['carbs_g']) ?? 0,
      fatGrams: _mapper.readDouble(raw['fat_g']) ?? 0,
      fiberGrams: _mapper.readDouble(raw['fiber_g']) ?? 0,
      sugarGrams: _mapper.readDouble(raw['sugar_g']) ?? 0,
      notes: _mapper.readString(raw['notes']),
      createdAtEpochMs: now,
      updatedAtEpochMs: now,
    );
  }

  IngredientEntity? _ingredientFromItem(Map<String, dynamic> raw) {
    final String name = _mapper.readString(raw['item_name']);
    if (name.isEmpty) {
      return null;
    }
    final String source = _mapper.readString(raw['source']);
    final String key = source.isEmpty ? name : source;
    final double? grams = _mapper.readDouble(raw['grams']);
    final double factor = grams == null || grams <= 0 ? 1 : 100 / grams;
    final int now = DateTime.now().millisecondsSinceEpoch;
    return IngredientEntity(
      uuid: 'obsidian-ingredient:${_slug(key)}',
      name: name,
      baseUnit: NutritionUnitCodes.grams,
      sourceTypeCode: IngredientSourceTypeCodes.obsidianImport,
      sourceName: 'Obsidian snapshot',
      notes: source.isEmpty ? '' : 'Origine: $source',
      nutritionReferenceAmount: grams == null || grams <= 0 ? 1 : 100,
      nutritionReferenceUnitCode: NutritionUnitCodes.grams,
      kcalPerReference: (_mapper.readDouble(raw['kcal']) ?? 0) * factor,
      proteinPerReference: (_mapper.readDouble(raw['protein_g']) ?? 0) * factor,
      carbsPerReference: (_mapper.readDouble(raw['carbs_g']) ?? 0) * factor,
      fatPerReference: (_mapper.readDouble(raw['fat_g']) ?? 0) * factor,
      fiberPerReference: (_mapper.readDouble(raw['fiber_g']) ?? 0) * factor,
      sugarPerReference: (_mapper.readDouble(raw['sugar_g']) ?? 0) * factor,
      createdAtEpochMs: now,
      updatedAtEpochMs: now,
    );
  }

  int? _epochMs(dynamic value) {
    final String raw = _mapper.readString(value);
    if (raw.isEmpty) {
      return null;
    }
    final DateTime? parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    return parsed?.millisecondsSinceEpoch;
  }

  List<Map<String, dynamic>> _listOfMaps(dynamic value, String fieldName) {
    if (value == null) {
      return <Map<String, dynamic>>[];
    }
    if (value is! List<dynamic>) {
      throw FormatException('$fieldName must be a list.');
    }
    return value.map((dynamic item) {
      if (item is Map<String, dynamic>) {
        return item;
      }
      if (item is Map<dynamic, dynamic>) {
        return <String, dynamic>{
          for (final MapEntry<dynamic, dynamic> entry in item.entries)
            entry.key.toString(): entry.value,
        };
      }
      throw FormatException('$fieldName contains a non-object item.');
    }).toList();
  }

  int _readCount(Map<String, dynamic> seed, String key) {
    final dynamic counts = seed['counts'];
    if (counts is Map<String, dynamic>) {
      return _mapper.readInt(counts[key]) ?? 0;
    }
    return 0;
  }

  String _slug(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}
