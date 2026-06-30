class IngredientSourceTypeCodes {
  const IngredientSourceTypeCodes._();

  static const String manual = 'manual';
  static const String obsidianImport = 'obsidian_import';
  static const String openFoodFacts = 'open_food_facts';

  static const Set<String> values = <String>{
    manual,
    obsidianImport,
    openFoodFacts,
  };
}

class NutritionUnitCodes {
  const NutritionUnitCodes._();

  static const String grams = 'g';
  static const String milliliters = 'ml';

  static const Set<String> values = <String>{
    grams,
    milliliters,
  };
}
