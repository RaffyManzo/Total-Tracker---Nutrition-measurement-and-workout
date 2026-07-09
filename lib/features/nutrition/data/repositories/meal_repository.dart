import 'dart:math' as math;

import '../../../../objectbox.g.dart';

import '../../../../core/identifiers/uuid_generator.dart';
import '../../../../core/pagination/paged_result.dart';
import '../../../../core/time/clock.dart';
import '../entities/nutrition_tracking_entities.dart';
import '../entities/ingredient_entity.dart';
import '../import/obsidian_food_seed.dart';
import 'daily_record_repository.dart';
import '../services/target_input_change_bus.dart';
import '../services/target_input_mutation_service.dart';

class MealWithItems {
  const MealWithItems({
    required this.meal,
    required this.items,
  });

  final MealEntity meal;
  final List<MealItemEntity> items;

  MealNutritionTotals get totals {
    double kcal = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;
    double fiber = 0;
    double sugar = 0;
    for (final MealItemEntity item in items) {
      if (item.deletedAtEpochMs != null) {
        continue;
      }
      kcal += item.kcal;
      protein += item.proteinGrams;
      carbs += item.carbsGrams;
      fat += item.fatGrams;
      fiber += item.fiberGrams;
      sugar += item.sugarGrams;
    }
    return MealNutritionTotals(
      kcal: kcal,
      proteinGrams: protein,
      carbsGrams: carbs,
      fatGrams: fat,
      fiberGrams: fiber,
      sugarGrams: sugar,
    );
  }

  bool get isNutritionPartial {
    if (meal.mealModeCode != 'free') {
      return false;
    }
    if (meal.freeMealTrackingCode == 'untracked') {
      return true;
    }
    if (meal.freeMealTrackingCode == 'estimated') {
      return items.any(
        (MealItemEntity item) =>
            item.kindCode == 'manual_estimate' && item.kcal <= 0,
      );
    }
    return false;
  }
}

class IngredientMealUsage {
  const IngredientMealUsage({
    required this.meal,
    required this.grams,
    required this.registrationCount,
  });

  final MealEntity meal;
  final double grams;
  final int registrationCount;
}

class IngredientUsagePageRequest {
  const IngredientUsagePageRequest({
    required this.ingredientUuid,
    required this.page,
    required this.pageSize,
    this.fromDateKey,
    this.toDateKey,
  });

  final String ingredientUuid;
  final int page;
  final int pageSize;
  final String? fromDateKey;
  final String? toDateKey;
}

class IngredientMealUsageSnapshot {
  const IngredientMealUsageSnapshot({
    required this.mealId,
    required this.dateKey,
    required this.title,
    required this.mealTypeCode,
    required this.grams,
    required this.registrationCount,
  });

  final int mealId;
  final String dateKey;
  final String title;
  final String mealTypeCode;
  final double grams;
  final int registrationCount;
}

class IngredientUsagePageSnapshot {
  const IngredientUsagePageSnapshot({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  final List<IngredientMealUsageSnapshot> items;
  final int page;
  final int pageSize;
  final int totalCount;

  int get totalPages {
    if (totalCount <= 0) return 0;
    return (totalCount / pageSize).ceil();
  }
}

IngredientUsagePageSnapshot loadIngredientUsagePageInBackground(
  Store store,
  IngredientUsagePageRequest request,
) {
  final PagedResult<IngredientMealUsage> result =
      MealRepository(store).loadIngredientUsagePage(
    request.ingredientUuid,
    page: request.page,
    pageSize: request.pageSize,
    fromDateKey: request.fromDateKey,
    toDateKey: request.toDateKey,
  );
  return IngredientUsagePageSnapshot(
    items: <IngredientMealUsageSnapshot>[
      for (final IngredientMealUsage usage in result.items)
        IngredientMealUsageSnapshot(
          mealId: usage.meal.id,
          dateKey: usage.meal.dateKey,
          title: usage.meal.title,
          mealTypeCode: usage.meal.mealTypeCode,
          grams: usage.grams,
          registrationCount: usage.registrationCount,
        ),
    ],
    page: result.page,
    pageSize: result.pageSize,
    totalCount: result.totalCount,
  );
}

class MealRepository {
  MealRepository(
    Store store, {
    Clock clock = const Clock(),
    UuidGenerator? uuidGenerator,
    DailyRecordRepository? dailyRecordRepository,
  })  : _store = store,
        _clock = clock,
        _uuidGenerator = uuidGenerator ?? UuidGenerator(),
        _dailyRecordRepository =
            dailyRecordRepository ?? DailyRecordRepository(store);

  final Store _store;
  final Clock _clock;
  final UuidGenerator _uuidGenerator;
  final DailyRecordRepository _dailyRecordRepository;

  Box<MealEntity> get _mealBox => _store.box<MealEntity>();
  Box<MealItemEntity> get _itemBox => _store.box<MealItemEntity>();

  MealEntity save(MealEntity meal) {
    _preserveStoredSlot(meal);
    _normalizeMeal(meal);
    _validateMeal(meal);
    _prepareMealForSave(meal);
    _store.runInTransaction(TxMode.write, () {
      meal.id = _mealBox.put(meal);
      TargetInputMutationService.enqueueInCurrentTransaction(
        _store,
        kind: TargetInputChangeKind.meal,
        fromDateKey: meal.dateKey,
        reasonCode: 'meal_saved_incremental',
        sourceEntityUuid: meal.uuid,
        sourceRevision: meal.updatedAtEpochMs,
      );
    });
    TargetInputMutationService.publishAfterCommit(
      kind: TargetInputChangeKind.meal,
      fromDateKey: meal.dateKey,
      reasonCode: 'meal_saved_incremental',
      sourceEntityUuid: meal.uuid,
      sourceRevision: meal.updatedAtEpochMs,
    );
    return meal;
  }

  MealWithItems saveMealWithItems(
    MealEntity meal,
    List<MealItemEntity> items, {
    bool replaceItems = true,
  }) {
    final MealWithItems result = _store.runInTransaction(TxMode.write, () {
      _preserveStoredSlot(meal);
      _normalizeMeal(meal);
      _validateMeal(meal);
      _prepareMealForSave(meal);
      meal.dailyRecord.target ??=
          _dailyRecordRepository.findByDate(meal.dateKey);
      meal.id = _mealBox.put(meal);
      if (replaceItems) {
        final List<int> oldItemIds = getItemsForMeal(meal.id)
            .map((MealItemEntity item) => item.id)
            .toList();
        if (oldItemIds.isNotEmpty) _itemBox.removeMany(oldItemIds);
      }
      final List<MealItemEntity> savedItems = <MealItemEntity>[];
      for (int index = 0; index < items.length; index += 1) {
        final MealItemEntity item = items[index];
        item.position = index;
        _normalizeItem(item);
        _validateItem(item);
        _prepareItemForSave(item);
        item.meal.target = meal;
        item.id = _itemBox.put(item);
        savedItems.add(item);
      }
      TargetInputMutationService.enqueueInCurrentTransaction(
        _store,
        kind: TargetInputChangeKind.meal,
        fromDateKey: meal.dateKey,
        reasonCode: 'meal_items_saved_incremental',
        sourceEntityUuid: meal.uuid,
        sourceRevision: meal.updatedAtEpochMs,
      );
      return MealWithItems(meal: meal, items: savedItems);
    });
    TargetInputMutationService.publishAfterCommit(
      kind: TargetInputChangeKind.meal,
      fromDateKey: meal.dateKey,
      reasonCode: 'meal_items_saved_incremental',
      sourceEntityUuid: meal.uuid,
      sourceRevision: meal.updatedAtEpochMs,
    );
    return result;
  }

  MealWithItems upsertImported(
      MealEntity importedMeal, List<MealItemEntity> items) {
    final MealEntity? existing = findByUuid(importedMeal.uuid);
    if (existing != null) {
      importedMeal.id = existing.id;
      importedMeal.createdAtEpochMs = existing.createdAtEpochMs;
    }
    return saveMealWithItems(importedMeal, items);
  }

  MealEntity? findByUuid(String uuid) {
    for (final MealEntity meal in _mealBox.getAll()) {
      if (meal.uuid == uuid && meal.deletedAtEpochMs == null) {
        return meal;
      }
    }
    return null;
  }

  MealEntity? getById(int id) {
    final MealEntity? meal = _mealBox.get(id);
    if (meal == null || meal.deletedAtEpochMs != null) {
      return null;
    }
    return meal;
  }

  MealEntity? findByDateAndSlot(String dateKey, String mealTypeCode) {
    for (final MealEntity meal in _mealBox.getAll()) {
      if (meal.dateKey == dateKey &&
          meal.mealTypeCode == mealTypeCode &&
          meal.deletedAtEpochMs == null) {
        return meal;
      }
    }
    return null;
  }

  MealWithItems? getMealWithItemsById(int id) {
    final MealEntity? meal = getById(id);
    if (meal == null) {
      return null;
    }
    return MealWithItems(meal: meal, items: getItemsForMeal(meal.id));
  }

  MealWithItems? getMealWithItemsByUuid(String uuid) {
    final MealEntity? meal = findByUuid(uuid);
    if (meal == null) {
      return null;
    }
    return MealWithItems(meal: meal, items: getItemsForMeal(meal.id));
  }

  List<MealEntity> getAllActive() {
    return _mealBox
        .getAll()
        .where((MealEntity meal) => meal.deletedAtEpochMs == null)
        .toList()
      ..sort(_sortByDateAndSlot);
  }

  List<MealWithItems> getAllWithItems() {
    return _attachItems(getAllActive());
  }

  List<MealWithItems> getMealsWithItemsInRange({
    required String fromDateKey,
    required String toDateKey,
  }) {
    final Query<MealEntity> mealQuery = _mealBox
        .query(
          MealEntity_.deletedAtEpochMs
              .isNull()
              .and(MealEntity_.dateKey.greaterOrEqual(fromDateKey))
              .and(MealEntity_.dateKey.lessOrEqual(toDateKey)),
        )
        .order(MealEntity_.dateKey, flags: Order.descending)
        .build();
    late final List<MealEntity> meals;
    try {
      meals = mealQuery.find()..sort(_sortByDateAndSlot);
    } finally {
      mealQuery.close();
    }
    if (meals.isEmpty) return const <MealWithItems>[];

    final List<int> mealIds =
        meals.map((MealEntity meal) => meal.id).toList(growable: false);
    var mealRelationCondition = MealItemEntity_.meal.equals(mealIds.first);
    for (final int mealId in mealIds.skip(1)) {
      mealRelationCondition = mealRelationCondition.or(
        MealItemEntity_.meal.equals(mealId),
      );
    }

    final Query<MealItemEntity> itemQuery = _itemBox
        .query(
          MealItemEntity_.deletedAtEpochMs.isNull().and(mealRelationCondition),
        )
        .build();
    late final List<MealItemEntity> items;
    try {
      items = itemQuery.find();
    } finally {
      itemQuery.close();
    }

    final Map<int, List<MealItemEntity>> itemsByMealId =
        <int, List<MealItemEntity>>{};
    for (final MealItemEntity item in items) {
      (itemsByMealId[item.meal.targetId] ??= <MealItemEntity>[]).add(item);
    }
    for (final List<MealItemEntity> mealItems in itemsByMealId.values) {
      mealItems.sort(
        (MealItemEntity a, MealItemEntity b) =>
            a.position.compareTo(b.position),
      );
    }
    return <MealWithItems>[
      for (final MealEntity meal in meals)
        MealWithItems(
          meal: meal,
          items: itemsByMealId[meal.id] ?? const <MealItemEntity>[],
        ),
    ];
  }

  // ingredient_usage_single_item_query
  // Query the matching item rows once. The previous implementation iterated
  // every active meal and executed getItemsForMeal for each one (N+1 reads),
  // making the ingredient detail page progressively slower as history grew.
  List<IngredientMealUsage> getIngredientUsage(
    String ingredientUuid, {
    String? fromDateKey,
    String? toDateKey,
    int? limit,
  }) {
    final String cleanUuid = ingredientUuid.trim();
    if (cleanUuid.isEmpty) {
      return const <IngredientMealUsage>[];
    }

    final Query<MealItemEntity> itemQuery = _itemBox
        .query(
          MealItemEntity_.deletedAtEpochMs
              .isNull()
              .and(MealItemEntity_.kindCode.equals('ingredient'))
              .and(MealItemEntity_.sourceUuid.equals(cleanUuid)),
        )
        .build();
    final List<MealItemEntity> matchingItems;
    try {
      matchingItems = itemQuery.find();
    } finally {
      itemQuery.close();
    }
    if (matchingItems.isEmpty) {
      return const <IngredientMealUsage>[];
    }

    final Map<int, List<MealItemEntity>> itemsByMealId =
        <int, List<MealItemEntity>>{};
    for (final MealItemEntity item in matchingItems) {
      final int mealId = item.meal.targetId;
      if (mealId == 0) {
        continue;
      }
      (itemsByMealId[mealId] ??= <MealItemEntity>[]).add(item);
    }

    final List<IngredientMealUsage> usage = <IngredientMealUsage>[];
    for (final MapEntry<int, List<MealItemEntity>> entry
        in itemsByMealId.entries) {
      final MealEntity? meal = _mealBox.get(entry.key);
      if (meal == null || meal.deletedAtEpochMs != null) {
        continue;
      }
      if (fromDateKey != null &&
          fromDateKey.isNotEmpty &&
          meal.dateKey.compareTo(fromDateKey) < 0) {
        continue;
      }
      if (toDateKey != null &&
          toDateKey.isNotEmpty &&
          meal.dateKey.compareTo(toDateKey) > 0) {
        continue;
      }
      usage.add(
        IngredientMealUsage(
          meal: meal,
          grams: entry.value.fold<double>(
            0,
            (double sum, MealItemEntity item) => sum + (item.grams ?? 0),
          ),
          registrationCount: entry.value.length,
        ),
      );
    }

    usage.sort((IngredientMealUsage a, IngredientMealUsage b) {
      final int dateCompare = b.meal.dateKey.compareTo(a.meal.dateKey);
      if (dateCompare != 0) {
        return dateCompare;
      }
      return b.meal.updatedAtEpochMs.compareTo(a.meal.updatedAtEpochMs);
    });
    if (limit == null || limit < 0 || usage.length <= limit) {
      return usage;
    }
    return usage.take(limit).toList();
  }

  PagedResult<IngredientMealUsage> loadIngredientUsagePage(
    String ingredientUuid, {
    required int page,
    int pageSize = 10,
    String? fromDateKey,
    String? toDateKey,
  }) {
    final String cleanUuid = ingredientUuid.trim();
    final int safePage = PagedResult.normalizePage(page);
    final int safePageSize = PagedResult.normalizePageSize(pageSize);
    if (cleanUuid.isEmpty) {
      return PagedResult<IngredientMealUsage>(
        items: const <IngredientMealUsage>[],
        page: safePage,
        pageSize: safePageSize,
        totalCount: 0,
      );
    }

    final QueryBuilder<MealEntity> mealBuilder = _mealBox.query(
      _ingredientUsageMealCondition(
        fromDateKey: fromDateKey,
        toDateKey: toDateKey,
      ),
    );
    mealBuilder.backlink<MealItemEntity>(
      MealItemEntity_.meal,
      _ingredientUsageCondition(cleanUuid),
    );
    mealBuilder
      ..order(MealEntity_.dateKey, flags: Order.descending)
      ..order(MealEntity_.id, flags: Order.descending);
    final Query<MealEntity> mealQuery = mealBuilder.build();
    try {
      final int totalCount = mealQuery.count();
      mealQuery.offset = (safePage - 1) * safePageSize;
      mealQuery.limit = safePageSize;
      final List<MealEntity> pageMeals = mealQuery.find();
      return PagedResult<IngredientMealUsage>(
        items: _usageForMeals(pageMeals, cleanUuid),
        page: safePage,
        pageSize: safePageSize,
        totalCount: totalCount,
      );
    } finally {
      mealQuery.close();
    }
  }

  List<MealEntity> getMealsForDate(String dateKey) {
    return getAllActive()
        .where((MealEntity meal) => meal.dateKey == dateKey)
        .toList()
      ..sort(_sortByDateAndSlot);
  }

  List<MealWithItems> getMealsWithItemsForDate(String dateKey) {
    return _attachItems(getMealsForDate(dateKey));
  }

  int activeMealInputRevision() {
    final Query<MealEntity> mealQuery =
        _mealBox.query(MealEntity_.deletedAtEpochMs.isNull()).build();
    final PropertyQuery<int> mealRevisionQuery =
        mealQuery.property(MealEntity_.updatedAtEpochMs);
    final Query<MealItemEntity> itemQuery =
        _itemBox.query(MealItemEntity_.deletedAtEpochMs.isNull()).build();
    final PropertyQuery<int> itemRevisionQuery =
        itemQuery.property(MealItemEntity_.updatedAtEpochMs);
    try {
      final int mealRevision =
          mealRevisionQuery.count() == 0 ? 0 : mealRevisionQuery.max();
      final int itemRevision =
          itemRevisionQuery.count() == 0 ? 0 : itemRevisionQuery.max();
      return math.max(mealRevision, itemRevision);
    } finally {
      itemRevisionQuery.close();
      itemQuery.close();
      mealRevisionQuery.close();
      mealQuery.close();
    }
  }

  Condition<MealItemEntity> _ingredientUsageCondition(String ingredientUuid) {
    return MealItemEntity_.deletedAtEpochMs
        .isNull()
        .and(MealItemEntity_.kindCode.equals('ingredient'))
        .and(MealItemEntity_.sourceUuid.equals(ingredientUuid));
  }

  Condition<MealEntity> _ingredientUsageMealCondition({
    String? fromDateKey,
    String? toDateKey,
  }) {
    Condition<MealEntity> condition = MealEntity_.deletedAtEpochMs.isNull();
    final String cleanFrom = fromDateKey?.trim() ?? '';
    if (cleanFrom.isNotEmpty) {
      condition = condition.and(MealEntity_.dateKey.greaterOrEqual(cleanFrom));
    }
    final String cleanTo = toDateKey?.trim() ?? '';
    if (cleanTo.isNotEmpty) {
      condition = condition.and(MealEntity_.dateKey.lessOrEqual(cleanTo));
    }
    return condition;
  }

  List<IngredientMealUsage> _usageForMeals(
    List<MealEntity> meals,
    String ingredientUuid,
  ) {
    if (meals.isEmpty) {
      return const <IngredientMealUsage>[];
    }

    Condition<MealItemEntity> mealCondition =
        MealItemEntity_.meal.equals(meals.first.id);
    for (final MealEntity meal in meals.skip(1)) {
      mealCondition = mealCondition.or(MealItemEntity_.meal.equals(meal.id));
    }
    final Query<MealItemEntity> itemQuery = _itemBox
        .query(_ingredientUsageCondition(ingredientUuid).and(mealCondition))
        .order(MealItemEntity_.id)
        .build();
    final List<MealItemEntity> rows;
    try {
      rows = itemQuery.find();
    } finally {
      itemQuery.close();
    }

    final Map<int, double> gramsByMealId = <int, double>{};
    final Map<int, int> countByMealId = <int, int>{};
    for (final MealItemEntity row in rows) {
      final int mealId = row.meal.targetId;
      gramsByMealId.update(
        mealId,
        (double current) => current + (row.grams ?? 0),
        ifAbsent: () => row.grams ?? 0,
      );
      countByMealId.update(
        mealId,
        (int current) => current + 1,
        ifAbsent: () => 1,
      );
    }

    return <IngredientMealUsage>[
      for (final MealEntity meal in meals)
        if (countByMealId.containsKey(meal.id))
          IngredientMealUsage(
            meal: meal,
            grams: gramsByMealId[meal.id] ?? 0,
            registrationCount: countByMealId[meal.id] ?? 0,
          ),
    ];
  }

  List<MealWithItems> _attachItems(List<MealEntity> meals) {
    if (meals.isEmpty) {
      return const <MealWithItems>[];
    }

    final Set<int> mealIds = meals.map((MealEntity meal) => meal.id).toSet();
    final Map<int, List<MealItemEntity>> itemsByMealId =
        <int, List<MealItemEntity>>{};

    for (final MealItemEntity item in _itemBox.getAll()) {
      if (item.deletedAtEpochMs != null) {
        continue;
      }

      final int mealId = item.meal.targetId;
      if (!mealIds.contains(mealId)) {
        continue;
      }

      (itemsByMealId[mealId] ??= <MealItemEntity>[]).add(item);
    }

    for (final List<MealItemEntity> items in itemsByMealId.values) {
      items.sort(
        (MealItemEntity a, MealItemEntity b) =>
            a.position.compareTo(b.position),
      );
    }

    return <MealWithItems>[
      for (final MealEntity meal in meals)
        MealWithItems(
          meal: meal,
          items: itemsByMealId[meal.id] ?? const <MealItemEntity>[],
        ),
    ];
  }

  MealWithItems ensureMealSlot({
    required String dateKey,
    required String mealTypeCode,
  }) {
    final MealEntity? existing = findByDateAndSlot(dateKey, mealTypeCode);
    if (existing != null) {
      return MealWithItems(meal: existing, items: getItemsForMeal(existing.id));
    }
    final MealEntity meal = createEmpty(
      dateKey: dateKey,
      mealTypeCode: mealTypeCode,
    );
    meal.uuid = 'auto-meal:$dateKey:$mealTypeCode';
    return saveMealWithItems(meal, const <MealItemEntity>[]);
  }

  List<MealWithItems> ensureMealSlotsForDate(String dateKey) {
    return <MealWithItems>[
      for (final String slot in ObsidianFoodSeedConstants.mealSlots)
        ensureMealSlot(dateKey: dateKey, mealTypeCode: slot),
    ];
  }

  List<MealItemEntity> getItemsForMeal(int mealId) {
    return _itemBox
        .getAll()
        .where(
          (MealItemEntity item) =>
              item.meal.targetId == mealId && item.deletedAtEpochMs == null,
        )
        .toList()
      ..sort((MealItemEntity a, MealItemEntity b) {
        return a.position.compareTo(b.position);
      });
  }

  MealEntity createEmpty({
    required String dateKey,
    required String mealTypeCode,
  }) {
    final DailyRecordEntity? day = _dailyRecordRepository.findByDate(dateKey);
    final int now = _clock.nowEpochMs();
    final MealEntity meal = MealEntity(
      uuid: '',
      dateKey: dateKey,
      weekCode: day?.weekCode ?? '',
      weekdayCode: day?.weekdayCode ?? '',
      weekdayLabel: day?.weekdayLabel ?? '',
      mealTypeCode: mealTypeCode,
      title: _defaultTitle(mealTypeCode, dateKey),
      createdAtEpochMs: now,
      updatedAtEpochMs: now,
    );
    meal.dailyRecord.target = day;
    return meal;
  }

  MealWithItems addIngredientItem({
    required int mealId,
    required IngredientEntity ingredient,
    required double grams,
  }) {
    if (grams <= 0) {
      throw ArgumentError.value(grams, 'grams', 'Must be greater than zero.');
    }
    late MealEntity meal;
    final MealWithItems result = _store.runInTransaction(TxMode.write, () {
      final MealEntity? storedMeal = getById(mealId);
      if (storedMeal == null) throw StateError('Meal not found: $mealId');
      meal = storedMeal;
      final List<MealItemEntity> items = getItemsForMeal(mealId);
      final double reference = ingredient.nutritionReferenceAmount <= 0
          ? 100.0
          : ingredient.nutritionReferenceAmount;
      final double factor = grams / reference;
      final MealItemEntity item = MealItemEntity(
        uuid: '',
        position: items.length,
        kindCode: 'ingredient',
        sourceUuid: ingredient.uuid,
        itemNameSnapshot: ingredient.name,
        quantityModeCode: 'grams',
        grams: grams,
        kcal: ingredient.kcalPerReference * factor,
        proteinGrams: ingredient.proteinPerReference * factor,
        carbsGrams: ingredient.carbsPerReference * factor,
        fatGrams: ingredient.fatPerReference * factor,
        fiberGrams: ingredient.fiberPerReference * factor,
        sugarGrams: ingredient.sugarPerReference * factor,
        notes: ingredient.sourceAttribution,
        createdAtEpochMs: 0,
        updatedAtEpochMs: 0,
      );
      _normalizeItem(item);
      _validateItem(item);
      _prepareItemForSave(item);
      item.meal.target = meal;
      item.id = _itemBox.put(item);
      meal.updatedAtEpochMs = _clock.nowEpochMs();
      _mealBox.put(meal);
      TargetInputMutationService.enqueueInCurrentTransaction(
        _store,
        kind: TargetInputChangeKind.meal,
        fromDateKey: meal.dateKey,
        reasonCode: 'meal_item_added_incremental',
        sourceEntityUuid: meal.uuid,
        sourceRevision: meal.updatedAtEpochMs,
      );
      return MealWithItems(meal: meal, items: <MealItemEntity>[...items, item]);
    });
    TargetInputMutationService.publishAfterCommit(
      kind: TargetInputChangeKind.meal,
      fromDateKey: meal.dateKey,
      reasonCode: 'meal_item_added_incremental',
      sourceEntityUuid: meal.uuid,
      sourceRevision: meal.updatedAtEpochMs,
    );
    return result;
  }

  MealEntity softDelete(MealEntity meal) {
    if (meal.id == 0 || _mealBox.get(meal.id) == null) {
      throw ArgumentError.value(meal.id, 'id', 'Meal not found.');
    }
    final MealEntity result = _store.runInTransaction(TxMode.write, () {
      final int now = _clock.nowEpochMs();
      meal.deletedAtEpochMs ??= now;
      meal.updatedAtEpochMs = now;
      meal.id = _mealBox.put(meal);
      final List<MealItemEntity> items = getItemsForMeal(meal.id);
      for (final MealItemEntity item in items) {
        item.deletedAtEpochMs ??= now;
        item.updatedAtEpochMs = now;
      }
      if (items.isNotEmpty) _itemBox.putMany(items);
      TargetInputMutationService.enqueueInCurrentTransaction(
        _store,
        kind: TargetInputChangeKind.meal,
        fromDateKey: meal.dateKey,
        reasonCode: 'meal_deleted_incremental',
        sourceEntityUuid: meal.uuid,
        sourceRevision: now,
      );
      return meal;
    });
    TargetInputMutationService.publishAfterCommit(
      kind: TargetInputChangeKind.meal,
      fromDateKey: meal.dateKey,
      reasonCode: 'meal_deleted_incremental',
      sourceEntityUuid: meal.uuid,
      sourceRevision: meal.updatedAtEpochMs,
    );
    return result;
  }

  int clearItemsForDate(String dateKey) {
    final String cleanDateKey = dateKey.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(cleanDateKey)) {
      throw ArgumentError.value(dateKey, 'dateKey', 'Use YYYY-MM-DD.');
    }
    final int deleted = _store.runInTransaction(TxMode.write, () {
      final int now = _clock.nowEpochMs();
      final List<MealItemEntity> itemsToDelete = <MealItemEntity>[];
      for (final MealEntity meal in getMealsForDate(cleanDateKey)) {
        final List<MealItemEntity> activeItems = getItemsForMeal(meal.id);
        if (activeItems.isEmpty) continue;
        for (final MealItemEntity item in activeItems) {
          item.deletedAtEpochMs = now;
          item.updatedAtEpochMs = now;
          itemsToDelete.add(item);
        }
        meal.updatedAtEpochMs = now;
        _mealBox.put(meal);
      }
      if (itemsToDelete.isNotEmpty) {
        _itemBox.putMany(itemsToDelete);
        TargetInputMutationService.enqueueInCurrentTransaction(
          _store,
          kind: TargetInputChangeKind.meal,
          fromDateKey: cleanDateKey,
          reasonCode: 'meal_items_cleared_incremental',
          sourceRevision: now,
        );
      }
      return itemsToDelete.length;
    });
    if (deleted > 0) {
      TargetInputMutationService.publishAfterCommit(
        kind: TargetInputChangeKind.meal,
        fromDateKey: cleanDateKey,
        reasonCode: 'meal_items_cleared_incremental',
      );
    }
    return deleted;
  }

  void _preserveStoredSlot(MealEntity meal) {
    if (meal.id == 0) {
      return;
    }
    final MealEntity? stored = _mealBox.get(meal.id);
    if (stored != null) {
      meal.mealTypeCode = stored.mealTypeCode;
    }
  }

  void _prepareMealForSave(MealEntity meal) {
    final int now = _clock.nowEpochMs();
    if (meal.uuid.trim().isEmpty) {
      meal.uuid = _uuidGenerator.generate();
    }
    if (meal.createdAtEpochMs == 0) {
      meal.createdAtEpochMs = now;
    }
    meal.updatedAtEpochMs = now;
  }

  void _prepareItemForSave(MealItemEntity item) {
    final int now = _clock.nowEpochMs();
    if (item.uuid.trim().isEmpty) {
      item.uuid = _uuidGenerator.generate();
    }
    if (item.createdAtEpochMs == 0) {
      item.createdAtEpochMs = now;
    }
    item.updatedAtEpochMs = now;
  }

  void _normalizeMeal(MealEntity meal) {
    meal.uuid = meal.uuid.trim();
    meal.dateKey = meal.dateKey.trim();
    meal.weekCode = meal.weekCode.trim();
    meal.weekdayCode = meal.weekdayCode.trim();
    meal.weekdayLabel = meal.weekdayLabel.trim();
    meal.mealTypeCode = meal.mealTypeCode.trim();
    meal.title = meal.title.trim();
    meal.mealModeCode = meal.mealModeCode.trim().isEmpty
        ? 'standard'
        : meal.mealModeCode.trim();
    meal.freeMealTrackingCode = meal.freeMealTrackingCode.trim();
    meal.freeMealLabel = meal.freeMealLabel.trim();
    meal.freeMealNotes = meal.freeMealNotes.trim();
  }

  void _normalizeItem(MealItemEntity item) {
    item.uuid = item.uuid.trim();
    item.kindCode = item.kindCode.trim();
    item.sourceUuid = item.sourceUuid.trim();
    item.itemNameSnapshot = item.itemNameSnapshot.trim();
    item.quantityModeCode = item.quantityModeCode.trim();
    item.notes = item.notes.trim();
  }

  void _validateMeal(MealEntity meal) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(meal.dateKey)) {
      throw ArgumentError.value(meal.dateKey, 'dateKey', 'Use YYYY-MM-DD.');
    }
    if (!ObsidianFoodSeedConstants.mealSlots.contains(meal.mealTypeCode)) {
      throw ArgumentError.value(
        meal.mealTypeCode,
        'mealTypeCode',
        'Unsupported meal slot.',
      );
    }
    if (meal.title.isEmpty) {
      throw ArgumentError.value(meal.title, 'title', 'Title is required.');
    }
    if (meal.mealModeCode != 'standard' && meal.mealModeCode != 'free') {
      throw ArgumentError.value(
        meal.mealModeCode,
        'mealModeCode',
        'Use standard or free.',
      );
    }
    if (meal.freeMealTrackingCode.isNotEmpty &&
        !<String>['tracked', 'estimated', 'untracked']
            .contains(meal.freeMealTrackingCode)) {
      throw ArgumentError.value(
        meal.freeMealTrackingCode,
        'freeMealTrackingCode',
        'Unsupported free meal tracking code.',
      );
    }
  }

  void _validateItem(MealItemEntity item) {
    if (!<String>['ingredient', 'recipe', 'manual_estimate']
        .contains(item.kindCode)) {
      throw ArgumentError.value(item.kindCode, 'kindCode', 'Unsupported kind.');
    }
    if (!<String>['grams', 'portions'].contains(item.quantityModeCode)) {
      throw ArgumentError.value(
        item.quantityModeCode,
        'quantityModeCode',
        'Unsupported quantity mode.',
      );
    }
    if (item.itemNameSnapshot.isEmpty) {
      throw ArgumentError.value(
        item.itemNameSnapshot,
        'itemNameSnapshot',
        'Item name is required.',
      );
    }
  }

  int _sortByDateAndSlot(MealEntity a, MealEntity b) {
    final int dateCompare = b.dateKey.compareTo(a.dateKey);
    if (dateCompare != 0) {
      return dateCompare;
    }
    return _slotIndex(a.mealTypeCode).compareTo(_slotIndex(b.mealTypeCode));
  }

  int _slotIndex(String slot) {
    final int index = ObsidianFoodSeedConstants.mealSlots.indexOf(slot);
    return index == -1 ? 99 : index;
  }

  String _defaultTitle(String mealTypeCode, String dateKey) {
    final String label = <String, String>{
          'colazione': 'Colazione',
          'spuntino': 'Spuntino',
          'pranzo': 'Pranzo',
          'cena': 'Cena',
        }[mealTypeCode] ??
        'Pasto';
    return '$label - $dateKey';
  }
}
