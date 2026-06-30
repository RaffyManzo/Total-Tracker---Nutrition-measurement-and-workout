import '../entities/ingredient_entity.dart';
import '../entities/nutrition_tracking_entities.dart';
import '../repositories/daily_record_repository.dart';
import '../repositories/meal_repository.dart';
import '../repositories/recipe_repository.dart';

class FoodDayBundle {
  const FoodDayBundle({
    required this.day,
    required this.meals,
  });

  final DailyRecordEntity day;
  final List<MealWithItems> meals;
}

class FoodPlanningService {
  FoodPlanningService({
    required DailyRecordRepository dailyRecords,
    required MealRepository meals,
    required RecipeRepository recipes,
  })  : _dailyRecords = dailyRecords,
        _meals = meals,
        _recipes = recipes;

  final DailyRecordRepository _dailyRecords;
  final MealRepository _meals;
  final RecipeRepository _recipes;

  FoodDayBundle ensureDay(String dateKey) {
    final DailyRecordEntity day = _dailyRecords.ensureForDate(dateKey);
    final List<MealWithItems> meals = _meals.ensureMealSlotsForDate(dateKey);
    return FoodDayBundle(day: day, meals: meals);
  }

  MealWithItems ensureMealSlot({
    required String dateKey,
    required String mealTypeCode,
  }) {
    _dailyRecords.ensureForDate(dateKey);
    return _meals.ensureMealSlot(
      dateKey: dateKey,
      mealTypeCode: mealTypeCode,
    );
  }

  MealWithItems addIngredientToMeal({
    required MealWithItems meal,
    required IngredientEntity ingredient,
    required double grams,
    String notes = '',
  }) {
    final double factor = grams / ingredient.nutritionReferenceAmount;
    final MealItemEntity item = MealItemEntity(
      uuid: '',
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
      notes: notes,
      createdAtEpochMs: 0,
      updatedAtEpochMs: 0,
    );
    return _appendItem(meal, item);
  }

  MealWithItems addRecipeToMeal({
    required MealWithItems meal,
    required RecipeEntity recipe,
    required double portions,
    String notes = '',
  }) {
    final int safeServings = recipe.servings <= 0 ? 1 : recipe.servings;
    final double kcal = recipe.kcalPerServing ?? 0;
    final double protein = recipe.proteinTotalGrams == null
        ? 0
        : recipe.proteinTotalGrams! / safeServings;
    final double carbs = recipe.carbsTotalGrams == null
        ? 0
        : recipe.carbsTotalGrams! / safeServings;
    final double fat =
        recipe.fatTotalGrams == null ? 0 : recipe.fatTotalGrams! / safeServings;
    final double fiber = recipe.fiberTotalGrams == null
        ? 0
        : recipe.fiberTotalGrams! / safeServings;
    final double sugar = recipe.sugarTotalGrams == null
        ? 0
        : recipe.sugarTotalGrams! / safeServings;
    final MealItemEntity item = MealItemEntity(
      uuid: '',
      kindCode: 'recipe',
      sourceUuid: recipe.uuid,
      itemNameSnapshot: recipe.title,
      quantityModeCode: 'portions',
      portions: portions,
      kcal: kcal * portions,
      proteinGrams: protein * portions,
      carbsGrams: carbs * portions,
      fatGrams: fat * portions,
      fiberGrams: fiber * portions,
      sugarGrams: sugar * portions,
      notes: notes,
      createdAtEpochMs: 0,
      updatedAtEpochMs: 0,
    );
    return _appendItem(meal, item);
  }

  MealWithItems addManualEstimateToMeal({
    required MealWithItems meal,
    required String name,
    required double kcal,
    double proteinGrams = 0,
    double carbsGrams = 0,
    double fatGrams = 0,
    double fiberGrams = 0,
    double sugarGrams = 0,
    String notes = '',
  }) {
    final MealItemEntity item = MealItemEntity(
      uuid: '',
      kindCode: 'manual_estimate',
      itemNameSnapshot: name.trim().isEmpty ? 'Stima manuale' : name.trim(),
      quantityModeCode: 'portions',
      portions: 1,
      kcal: kcal,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
      fiberGrams: fiberGrams,
      sugarGrams: sugarGrams,
      notes: notes,
      createdAtEpochMs: 0,
      updatedAtEpochMs: 0,
    );
    return _appendItem(meal, item);
  }

  MealWithItems removeItemAt(MealWithItems meal, int position) {
    final List<MealItemEntity> nextItems = List<MealItemEntity>.from(meal.items)
      ..removeWhere((MealItemEntity item) => item.position == position);
    return _meals.saveMealWithItems(meal.meal, nextItems);
  }

  RecipeDetails? getRecipeDetails(int id) {
    return _recipes.getDetails(id);
  }

  MealWithItems _appendItem(MealWithItems meal, MealItemEntity item) {
    final List<MealItemEntity> nextItems = List<MealItemEntity>.from(meal.items)
      ..add(item);
    return _meals.saveMealWithItems(meal.meal, nextItems);
  }
}
