import 'package:objectbox/objectbox.dart';

import '../../../../core/identifiers/uuid_generator.dart';
import '../../../../core/time/clock.dart';
import '../../domain/nutrition_codes.dart';
import '../entities/ingredient_entity.dart';

class IngredientRepository {
  IngredientRepository(
    Store store, {
    Clock clock = const Clock(),
    UuidGenerator? uuidGenerator,
  })  : _store = store,
        _clock = clock,
        _uuidGenerator = uuidGenerator ?? UuidGenerator();

  final Store _store;
  final Clock _clock;
  final UuidGenerator _uuidGenerator;

  Box<IngredientEntity> get _box => _store.box<IngredientEntity>();

  IngredientEntity save(IngredientEntity ingredient) {
    _normalize(ingredient);
    _validate(ingredient);
    _ensureBarcodeIsUnique(ingredient);
    _prepareForSave(ingredient);
    ingredient.id = _box.put(ingredient);
    return ingredient;
  }

  IngredientEntity? findByUuid(String uuid) {
    for (final IngredientEntity ingredient in _box.getAll()) {
      if (ingredient.uuid == uuid && ingredient.deletedAtEpochMs == null) {
        return ingredient;
      }
    }
    return null;
  }

  IngredientEntity? findByBarcode(String barcode) {
    final String normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty) {
      return null;
    }
    for (final IngredientEntity ingredient in _box.getAll()) {
      if (ingredient.barcode == normalizedBarcode &&
          ingredient.deletedAtEpochMs == null) {
        return ingredient;
      }
    }
    return null;
  }

  List<IngredientEntity> searchByName(String query) {
    final String normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return getAllActive();
    }

    return getAllActive()
        .where(
          (IngredientEntity ingredient) =>
              ingredient.name.toLowerCase().contains(normalizedQuery),
        )
        .toList()
      ..sort(_sortByName);
  }

  List<IngredientEntity> getAllActive() {
    return _box
        .getAll()
        .where(
          (IngredientEntity ingredient) =>
              !ingredient.isArchived && ingredient.deletedAtEpochMs == null,
        )
        .toList()
      ..sort(_sortByName);
  }

  IngredientEntity archive(IngredientEntity ingredient) {
    _ensureExists(ingredient);
    ingredient.isArchived = true;
    ingredient.updatedAtEpochMs = _clock.nowEpochMs();
    ingredient.id = _box.put(ingredient);
    return ingredient;
  }

  IngredientEntity softDelete(IngredientEntity ingredient) {
    _ensureExists(ingredient);
    final int nowEpochMs = _clock.nowEpochMs();
    ingredient.isArchived = true;
    ingredient.deletedAtEpochMs ??= nowEpochMs;
    ingredient.updatedAtEpochMs = nowEpochMs;
    ingredient.id = _box.put(ingredient);
    return ingredient;
  }

  void _ensureExists(IngredientEntity ingredient) {
    if (ingredient.id == 0 || _box.get(ingredient.id) == null) {
      throw ArgumentError.value(
          ingredient.id, 'id', 'Ingredient does not exist.');
    }
  }

  void _prepareForSave(IngredientEntity ingredient) {
    final int nowEpochMs = _clock.nowEpochMs();
    if (ingredient.uuid.trim().isEmpty) {
      ingredient.uuid = _uuidGenerator.generate();
    }
    if (ingredient.createdAtEpochMs == 0) {
      ingredient.createdAtEpochMs = nowEpochMs;
    }
    ingredient.updatedAtEpochMs = nowEpochMs;
  }

  void _normalize(IngredientEntity ingredient) {
    ingredient.name = ingredient.name.trim();
    ingredient.brand = ingredient.brand.trim();
    ingredient.baseUnit = ingredient.baseUnit.trim();
    ingredient.barcode = ingredient.barcode.trim();
    ingredient.sourceTypeCode = ingredient.sourceTypeCode.trim();
    ingredient.nutritionReferenceUnitCode =
        ingredient.nutritionReferenceUnitCode.trim();
  }

  void _validate(IngredientEntity ingredient) {
    if (ingredient.name.isEmpty) {
      throw ArgumentError.value(ingredient.name, 'name', 'Name is required.');
    }
    if (ingredient.baseUnit.isEmpty) {
      throw ArgumentError.value(
        ingredient.baseUnit,
        'baseUnit',
        'Base unit is required.',
      );
    }
    if (!IngredientSourceTypeCodes.values.contains(ingredient.sourceTypeCode)) {
      throw ArgumentError.value(
        ingredient.sourceTypeCode,
        'sourceTypeCode',
        'Unsupported ingredient source type.',
      );
    }
    if (!NutritionUnitCodes.values.contains(
      ingredient.nutritionReferenceUnitCode,
    )) {
      throw ArgumentError.value(
        ingredient.nutritionReferenceUnitCode,
        'nutritionReferenceUnitCode',
        'Unsupported nutrition reference unit.',
      );
    }
    if (ingredient.nutritionReferenceAmount <= 0) {
      throw ArgumentError.value(
        ingredient.nutritionReferenceAmount,
        'nutritionReferenceAmount',
        'Reference amount must be greater than zero.',
      );
    }

    final Map<String, double> nonNegativeValues = <String, double>{
      'kcalPerReference': ingredient.kcalPerReference,
      'proteinPerReference': ingredient.proteinPerReference,
      'carbsPerReference': ingredient.carbsPerReference,
      'fatPerReference': ingredient.fatPerReference,
      'fiberPerReference': ingredient.fiberPerReference,
      'sugarPerReference': ingredient.sugarPerReference,
      'saltPerReference': ingredient.saltPerReference,
    };

    for (final MapEntry<String, double> entry in nonNegativeValues.entries) {
      if (entry.value < 0) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Nutrition values cannot be negative.',
        );
      }
    }
  }

  void _ensureBarcodeIsUnique(IngredientEntity ingredient) {
    if (ingredient.barcode.isEmpty) {
      return;
    }
    final IngredientEntity? existingIngredient =
        findByBarcode(ingredient.barcode);
    if (existingIngredient != null && existingIngredient.id != ingredient.id) {
      throw StateError('Barcode already belongs to another ingredient.');
    }
  }

  int _sortByName(IngredientEntity a, IngredientEntity b) {
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
}
