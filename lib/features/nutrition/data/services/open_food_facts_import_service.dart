import '../../domain/nutrition_codes.dart';
import '../entities/ingredient_entity.dart';
import '../repositories/ingredient_repository.dart';
import 'open_food_facts_service.dart';

class OpenFoodFactsImportService {
  const OpenFoodFactsImportService(this.repository);

  final IngredientRepository repository;

  IngredientEntity importProduct(OpenFoodFactsProduct product) {
    if (product.code.trim().isEmpty) {
      throw const FormatException(
        'Il prodotto Open Food Facts non contiene un barcode.',
      );
    }
    if (product.name.trim().isEmpty) {
      throw const FormatException(
        'Il prodotto Open Food Facts non contiene un nome.',
      );
    }

    final IngredientEntity? byBarcode = repository.findByBarcode(product.code);
    final IngredientEntity? bySource = repository.findByExternalSource(
      IngredientSourceTypeCodes.openFoodFacts,
      product.code,
    );
    final IngredientEntity? existing = byBarcode ?? bySource;

    if (existing == null) {
      return repository.save(product.toIngredientEntity());
    }

    final bool canRefreshAll =
        existing.sourceTypeCode == IngredientSourceTypeCodes.openFoodFacts &&
            !existing.wasModifiedByUser;

    if (canRefreshAll) {
      existing
        ..name = product.name
        ..brand = product.brand
        ..barcode = product.code
        ..packageQuantity = product.packageQuantity
        ..sourceName = 'Open Food Facts'
        ..sourceUrl = product.sourceUrl
        ..sourceExternalId = product.code
        ..sourceDatasetVersion = 'api-v2'
        ..sourceLicenseCode = 'ODbL-1.0'
        ..sourceAttribution = '© Open Food Facts contributors'
        ..imageUrl = product.preferredImageUrl
        ..categories = product.categories
        ..nutritionReferenceAmount = 100
        ..nutritionReferenceUnitCode = NutritionUnitCodes.grams
        ..kcalPerReference = product.kcal100
        ..proteinPerReference = product.protein100
        ..carbsPerReference = product.carbs100
        ..fatPerReference = product.fat100
        ..fiberPerReference = product.fiber100
        ..sugarPerReference = product.sugar100
        ..saltPerReference = product.salt100;
      return repository.save(existing);
    }

    bool changed = false;
    if (existing.imageUrl.trim().isEmpty &&
        product.preferredImageUrl.isNotEmpty) {
      existing.imageUrl = product.preferredImageUrl;
      changed = true;
    }
    if (existing.sourceUrl.trim().isEmpty && product.sourceUrl.isNotEmpty) {
      existing.sourceUrl = product.sourceUrl;
      changed = true;
    }
    return changed ? repository.save(existing) : existing;
  }
}
