import '../../../../objectbox.g.dart';

import '../../../../core/identifiers/uuid_generator.dart';
import '../../../../core/time/clock.dart';
import '../entities/nutrition_tracking_entities.dart';
import '../entities/ingredient_entity.dart';
import '../import/obsidian_food_seed.dart';
import 'daily_record_repository.dart';

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
    meal.id = _mealBox.put(meal);
    return meal;
  }

  MealWithItems saveMealWithItems(
    MealEntity meal,
    List<MealItemEntity> items, {
    bool replaceItems = true,
  }) {
    return _store.runInTransaction(TxMode.write, () {
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
        if (oldItemIds.isNotEmpty) {
          _itemBox.removeMany(oldItemIds);
        }
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
      return MealWithItems(meal: meal, items: savedItems);
    });
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

    final List<IngredientMealUsage> usage = <IngredientMealUsage>[];
    for (final MealEntity meal in getAllActive()) {
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

      final List<MealItemEntity> matchingItems = getItemsForMeal(meal.id)
          .where(
            (MealItemEntity item) =>
                item.kindCode == 'ingredient' &&
                item.sourceUuid == cleanUuid &&
                item.deletedAtEpochMs == null,
          )
          .toList();
      if (matchingItems.isEmpty) {
        continue;
      }

      usage.add(
        IngredientMealUsage(
          meal: meal,
          grams: matchingItems.fold<double>(
            0,
            (double sum, MealItemEntity item) => sum + (item.grams ?? 0),
          ),
          registrationCount: matchingItems.length,
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

  List<MealEntity> getMealsForDate(String dateKey) {
    return getAllActive()
        .where((MealEntity meal) => meal.dateKey == dateKey)
        .toList()
      ..sort(_sortByDateAndSlot);
  }

  List<MealWithItems> getMealsWithItemsForDate(String dateKey) {
    return _attachItems(getMealsForDate(dateKey));
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
    return _store.runInTransaction(TxMode.write, () {
      final meal = getById(mealId);
      if (meal == null) {
        throw StateError('Meal not found: $mealId');
      }
      final items = getItemsForMeal(mealId);
      final reference = ingredient.nutritionReferenceAmount <= 0
          ? 100.0
          : ingredient.nutritionReferenceAmount;
      final factor = grams / reference;
      final item = MealItemEntity(
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
      return MealWithItems(meal: meal, items: <MealItemEntity>[...items, item]);
    });
  }

  MealEntity softDelete(MealEntity meal) {
    if (meal.id == 0 || _mealBox.get(meal.id) == null) {
      throw ArgumentError.value(meal.id, 'id', 'Meal not found.');
    }
    return _store.runInTransaction(TxMode.write, () {
      final int now = _clock.nowEpochMs();
      meal.deletedAtEpochMs ??= now;
      meal.updatedAtEpochMs = now;
      meal.id = _mealBox.put(meal);
      final List<MealItemEntity> items = getItemsForMeal(meal.id);
      for (final MealItemEntity item in items) {
        item.deletedAtEpochMs ??= now;
        item.updatedAtEpochMs = now;
      }
      if (items.isNotEmpty) {
        _itemBox.putMany(items);
      }
      return meal;
    });
  }

  int clearItemsForDate(String dateKey) {
    final String cleanDateKey = dateKey.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(cleanDateKey)) {
      throw ArgumentError.value(dateKey, 'dateKey', 'Use YYYY-MM-DD.');
    }
    return _store.runInTransaction(TxMode.write, () {
      final int now = _clock.nowEpochMs();
      final List<MealItemEntity> itemsToDelete = <MealItemEntity>[];
      for (final MealEntity meal in getMealsForDate(cleanDateKey)) {
        final List<MealItemEntity> activeItems = getItemsForMeal(meal.id);
        if (activeItems.isEmpty) {
          continue;
        }
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
      }
      return itemsToDelete.length;
    });
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
