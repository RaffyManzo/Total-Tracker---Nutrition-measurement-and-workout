import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/services/open_food_facts_service.dart';

void main() {
  test('selects HTTPS image URL and maps nutrition', () {
    final OpenFoodFactsProduct product = OpenFoodFactsProduct.fromJson(
      <String, dynamic>{
        'code': '8001234567890',
        'product_name_it': 'Yogurt',
        'brands': 'Marca',
        'image_front_small_url':
            'http://images.openfoodfacts.org/yogurt.200.jpg',
        'image_front_url': 'https://images.openfoodfacts.org/yogurt.400.jpg',
        'nutriments': <String, dynamic>{
          'energy-kcal_100g': 61,
          'proteins_100g': 3.5,
          'carbohydrates_100g': 4.7,
          'fat_100g': 3.3,
        },
      },
    );

    expect(
      product.preferredImageUrl,
      'https://images.openfoodfacts.org/yogurt.200.jpg',
    );
    expect(product.kcal100, 61);
    expect(product.protein100, 3.5);
    expect(
      product.toIngredientEntity().imageUrl,
      product.preferredImageUrl,
    );
  });

  test('extracts selected_images when direct URLs are absent', () {
    final OpenFoodFactsProduct product = OpenFoodFactsProduct.fromJson(
      <String, dynamic>{
        'code': '1',
        'product_name': 'Pane',
        'selected_images': <String, dynamic>{
          'front': <String, dynamic>{
            'small': <String, dynamic>{
              'it': 'https://images.openfoodfacts.org/pane.200.jpg',
            },
          },
        },
        'nutriments': <String, dynamic>{},
      },
    );

    expect(product.preferredImageUrl, contains('pane.200.jpg'));
  });
}
