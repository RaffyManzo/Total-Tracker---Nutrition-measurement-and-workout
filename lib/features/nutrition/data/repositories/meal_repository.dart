import 'package:objectbox/objectbox.dart';

import '../../../../core/identifiers/uuid_generator.dart';
import '../../../../core/time/clock.dart';
import '../entities/nutrition_tracking_entities.dart';
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
    return getAllActive().map((MealEntity meal) {
      return MealWithItems(meal: meal, items: getItemsForMeal(meal.id));
    }).toList();
  }

  List<MealEntity> getMealsForDate(String dateKey) {
    return getAllActive()
        .where((MealEntity meal) => meal.dateKey == dateKey)
        .toList()
      ..sort(_sortByDateAndSlot);
  }

  List<MealWithItems> getMealsWithItemsForDate(String dateKey) {
    return getMealsForDate(dateKey).map((MealEntity meal) {
      return MealWithItems(meal: meal, items: getItemsForMeal(meal.id));
    }).toList();
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
