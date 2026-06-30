import '../domain/mock_ingredient.dart';

abstract final class MockIngredientCatalog {
  static final List<MockIngredient> items = <MockIngredient>[
    MockIngredient(
      id: 'yogurt-greco',
      name: 'Yogurt Greco',
      brand: 'Mila',
      unit: 'g',
      barcode: '8001234567890',
      quantity: '150 g',
      sourceType: 'open_food_facts_barcode',
      sourceName: 'Open Food Facts',
      sourceUrl: 'https://world.openfoodfacts.org/',
      imageUrl: '',
      kcal100: 62,
      protein100: 10,
      carbs100: 3.6,
      fat100: 0.2,
      fiber100: 0,
      sugar100: 3.6,
      salt100: 0.10,
      categories: <String>['Latticini', 'Yogurt'],
      notes: 'Esempio importato tramite barcode.',
      createdAt: DateTime(2026, 6, 28, 10, 30),
      updatedAt: DateTime(2026, 6, 28, 10, 30),
    ),
    MockIngredient(
      id: 'fiocchi-avena',
      name: 'Fiocchi di avena',
      brand: 'Total Tracker',
      unit: 'g',
      barcode: '',
      quantity: '500 g',
      sourceType: 'manuale',
      sourceName: 'Inserimento manuale',
      sourceUrl: '',
      imageUrl: '',
      kcal100: 372,
      protein100: 13.5,
      carbs100: 58.7,
      fat100: 7,
      fiber100: 10,
      sugar100: 1,
      salt100: 0.01,
      categories: <String>['Cereali', 'Colazione'],
      notes: 'Ingrediente creato manualmente.',
      createdAt: DateTime(2026, 6, 27, 8, 15),
      updatedAt: DateTime(2026, 6, 27, 8, 15),
    ),
    MockIngredient(
      id: 'petto-pollo',
      name: 'Petto di pollo',
      brand: 'Generico',
      unit: 'g',
      barcode: '',
      quantity: '100 g',
      sourceType: 'manuale',
      sourceName: 'Inserimento manuale',
      sourceUrl: '',
      imageUrl: '',
      kcal100: 110,
      protein100: 23.1,
      carbs100: 0,
      fat100: 1.2,
      fiber100: 0,
      sugar100: 0,
      salt100: 0.12,
      categories: <String>['Carne', 'Proteine'],
      notes: '',
      createdAt: DateTime(2026, 6, 26, 18),
      updatedAt: DateTime(2026, 6, 26, 18),
    ),
  ];

  static MockIngredient? byId(String id) {
    for (final MockIngredient ingredient in items) {
      if (ingredient.id == id) {
        return ingredient;
      }
    }
    return null;
  }
}
