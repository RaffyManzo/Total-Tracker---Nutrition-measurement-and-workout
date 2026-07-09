import '../../../../core/pagination/paged_result.dart';
import '../../../../core/identifiers/uuid_generator.dart';
import '../../../../core/time/clock.dart';
import '../../../../objectbox.g.dart';
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
    final Query<IngredientEntity> query = _box
        .query(
          IngredientEntity_.uuid
              .equals(uuid.trim())
              .and(IngredientEntity_.deletedAtEpochMs.isNull()),
        )
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  IngredientEntity? findByBarcode(String barcode) {
    final String normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty) {
      return null;
    }
    final Query<IngredientEntity> query = _box
        .query(
          IngredientEntity_.barcode
              .equals(normalizedBarcode)
              .and(IngredientEntity_.deletedAtEpochMs.isNull()),
        )
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  IngredientEntity? getById(int id) {
    final IngredientEntity? ingredient = _box.get(id);
    if (ingredient == null || ingredient.deletedAtEpochMs != null) {
      return null;
    }
    return ingredient;
  }

  List<IngredientEntity> searchByName(String query) {
    return loadIngredientPage(
      page: 1,
      pageSize: _countActive(),
      search: query,
    ).items;
  }

  List<IngredientEntity> getAllActive() {
    return loadIngredientPage(
      page: 1,
      pageSize: _countActive(),
    ).items;
  }

  List<IngredientEntity> getRecentActive({int limit = 50}) {
    final int safeLimit = limit < 0 ? 0 : limit;
    if (safeLimit == 0) {
      return const <IngredientEntity>[];
    }
    final Query<IngredientEntity> query = _box
        .query(
          IngredientEntity_.deletedAtEpochMs
              .isNull()
              .and(IngredientEntity_.isArchived.equals(false)),
        )
        .order(IngredientEntity_.createdAtEpochMs, flags: Order.descending)
        .order(IngredientEntity_.id, flags: Order.descending)
        .build();
    query.limit = safeLimit;
    try {
      return query.find();
    } finally {
      query.close();
    }
  }

  List<IngredientEntity> searchByNameLimited(
    String query, {
    int offset = 0,
    int limit = 25,
  }) {
    final int safeOffset = offset < 0 ? 0 : offset;
    final int safeLimit = PagedResult.normalizePageSize(limit);
    final Query<IngredientEntity> ingredientQuery = _box
        .query(
          _ingredientPageCondition(
            search: query,
            brand: '',
            activeOnly: true,
          ),
        )
        .order(IngredientEntity_.name)
        .order(IngredientEntity_.id)
        .build();
    ingredientQuery.offset = safeOffset;
    ingredientQuery.limit = safeLimit;
    try {
      return ingredientQuery.find();
    } finally {
      ingredientQuery.close();
    }
  }

  PagedResult<IngredientEntity> loadIngredientPage({
    required int page,
    int pageSize = 10,
    String search = '',
    String brand = '',
    bool activeOnly = true,
  }) {
    final int safePage = PagedResult.normalizePage(page);
    final int safePageSize = PagedResult.normalizePageSize(pageSize);
    final Query<IngredientEntity> query = _box
        .query(
          _ingredientPageCondition(
            search: search,
            brand: brand,
            activeOnly: activeOnly,
          ),
        )
        .order(IngredientEntity_.name)
        .order(IngredientEntity_.id)
        .build();
    try {
      final int totalCount = query.count();
      query.offset = (safePage - 1) * safePageSize;
      query.limit = safePageSize;
      return PagedResult<IngredientEntity>(
        items: query.find(),
        page: safePage,
        pageSize: safePageSize,
        totalCount: totalCount,
      );
    } finally {
      query.close();
    }
  }

  IngredientEntity? findByExternalSource(
    String sourceTypeCode,
    String sourceExternalId,
  ) {
    final normalizedId = sourceExternalId.trim();
    if (normalizedId.isEmpty) return null;
    final Query<IngredientEntity> query = _box
        .query(
          IngredientEntity_.deletedAtEpochMs
              .isNull()
              .and(IngredientEntity_.sourceTypeCode.equals(sourceTypeCode))
              .and(IngredientEntity_.sourceExternalId.equals(normalizedId)),
        )
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
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
    ingredient.sourceExternalId = ingredient.sourceExternalId.trim();
    ingredient.sourceDatasetVersion = ingredient.sourceDatasetVersion.trim();
    ingredient.sourceLicenseCode = ingredient.sourceLicenseCode.trim();
    ingredient.sourceAttribution = ingredient.sourceAttribution.trim();
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

  Condition<IngredientEntity> _ingredientPageCondition({
    required String search,
    required String brand,
    required bool activeOnly,
  }) {
    Condition<IngredientEntity> condition =
        IngredientEntity_.deletedAtEpochMs.isNull();
    if (activeOnly) {
      condition = condition.and(IngredientEntity_.isArchived.equals(false));
    }
    final String cleanSearch = search.trim();
    if (cleanSearch.isNotEmpty) {
      condition = condition.and(
        IngredientEntity_.name
            .contains(cleanSearch, caseSensitive: false)
            .or(
              IngredientEntity_.brand.contains(
                cleanSearch,
                caseSensitive: false,
              ),
            )
            .or(
              IngredientEntity_.barcode.contains(
                cleanSearch,
                caseSensitive: false,
              ),
            ),
      );
    }
    final String cleanBrand = brand.trim();
    if (cleanBrand.isNotEmpty) {
      condition = condition.and(
        IngredientEntity_.brand.contains(cleanBrand, caseSensitive: false),
      );
    }
    return condition;
  }

  int _countActive() {
    final Query<IngredientEntity> query = _box
        .query(
          IngredientEntity_.deletedAtEpochMs
              .isNull()
              .and(IngredientEntity_.isArchived.equals(false)),
        )
        .build();
    try {
      return query.count();
    } finally {
      query.close();
    }
  }
}
