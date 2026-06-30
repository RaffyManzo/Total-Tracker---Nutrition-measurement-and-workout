class MockIngredient {
  const MockIngredient({
    required this.id,
    required this.name,
    required this.brand,
    required this.unit,
    required this.barcode,
    required this.quantity,
    required this.sourceType,
    required this.sourceName,
    required this.sourceUrl,
    required this.imageUrl,
    required this.kcal100,
    required this.protein100,
    required this.carbs100,
    required this.fat100,
    required this.fiber100,
    required this.sugar100,
    required this.salt100,
    required this.categories,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String brand;
  final String unit;
  final String barcode;
  final String quantity;
  final String sourceType;
  final String sourceName;
  final String sourceUrl;
  final String imageUrl;
  final double kcal100;
  final double protein100;
  final double carbs100;
  final double fat100;
  final double fiber100;
  final double sugar100;
  final double salt100;
  final List<String> categories;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
}
