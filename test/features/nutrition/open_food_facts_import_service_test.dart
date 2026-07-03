import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/repositories/ingredient_repository.dart';
import 'package:total_tracker/features/nutrition/data/services/open_food_facts_import_service.dart';
import 'package:total_tracker/features/nutrition/data/services/open_food_facts_service.dart';

import '../../helpers/objectbox_test_helper.dart';

void main() {
  test('imports and persists Open Food Facts image URL', () async {
    final database = await openTestDatabase();
    final IngredientRepository repository =
        IngredientRepository(database.store);
    final OpenFoodFactsImportService service =
        OpenFoodFactsImportService(repository);

    const OpenFoodFactsProduct product = OpenFoodFactsProduct(
      code: '8001234567890',
      name: 'Yogurt',
      brand: 'Marca',
      quantity: '125 g',
      imageUrl: 'https://images.openfoodfacts.org/yogurt.400.jpg',
      imageSmallUrl: 'https://images.openfoodfacts.org/yogurt.200.jpg',
      categories: 'Yogurt',
      sourceUrl: 'https://world.openfoodfacts.org/product/8001234567890',
      kcal100: 61,
      protein100: 3.5,
      carbs100: 4.7,
      fat100: 3.3,
      fiber100: 0,
      sugar100: 4.7,
      salt100: 0.1,
    );

    final imported = service.importProduct(product);
    final persisted = repository.findByBarcode(product.code);

    expect(imported.id, greaterThan(0));
    expect(
      persisted?.imageUrl,
      'https://images.openfoodfacts.org/yogurt.200.jpg',
    );
    expect(persisted?.sourceExternalId, product.code);
  });

  test('deduplicates the same barcode', () async {
    final database = await openTestDatabase();
    final IngredientRepository repository =
        IngredientRepository(database.store);
    final OpenFoodFactsImportService service =
        OpenFoodFactsImportService(repository);

    const OpenFoodFactsProduct product = OpenFoodFactsProduct(
      code: '12345678',
      name: 'Riso',
      brand: '',
      quantity: '',
      imageUrl: '',
      imageSmallUrl: '',
      categories: '',
      sourceUrl: 'https://world.openfoodfacts.org/product/12345678',
      kcal100: 350,
      protein100: 7,
      carbs100: 78,
      fat100: 1,
      fiber100: 2,
      sugar100: 0,
      salt100: 0,
    );

    final first = service.importProduct(product);
    final second = service.importProduct(product);

    expect(second.id, first.id);
    expect(repository.getAllActive(), hasLength(1));
  });
}
