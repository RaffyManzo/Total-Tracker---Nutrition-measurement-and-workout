import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nutrition pagination paths use bounded database-backed sources', () {
    final String ingredientRepository = File(
      'lib/features/nutrition/data/repositories/ingredient_repository.dart',
    ).readAsStringSync();
    final String measurementRepository = File(
      'lib/features/nutrition/data/repositories/measurement_repository.dart',
    ).readAsStringSync();
    final String mealRepository = File(
      'lib/features/nutrition/data/repositories/meal_repository.dart',
    ).readAsStringSync();
    final String foodScreens = File(
      'lib/features/nutrition/presentation/food_v01_screens.dart',
    ).readAsStringSync();
    final String measurementScreens = File(
      'lib/features/nutrition/presentation/measurement_screens.dart',
    ).readAsStringSync();
    final String mealPicker = File(
      'lib/features/nutrition/presentation/meal_ingredient_batch_picker_sheet.dart',
    ).readAsStringSync();

    expect(ingredientRepository, contains('loadIngredientPage({'));
    expect(ingredientRepository, contains('query.offset ='));
    expect(ingredientRepository, contains('query.limit = safePageSize'));

    expect(mealRepository, contains('loadIngredientUsagePage('));
    expect(mealRepository, contains('mealBuilder.backlink<MealItemEntity>'));
    expect(mealRepository, contains('mealQuery.limit = safePageSize'));
    expect(foodScreens, contains('store.runAsync<'));

    expect(measurementRepository, contains('loadScaleMeasurementPage({'));
    expect(measurementRepository, contains('loadTapeMeasurementPage({'));
    expect(measurementScreens, contains('scaleMeasurementPageProvider'));
    expect(measurementScreens, contains('tapeMeasurementPageProvider'));

    expect(foodScreens, contains('class _RecipeIngredientPickerSheet'));
    expect(foodScreens, contains('widget.repository.loadIngredientPage('));
    expect(foodScreens, isNot(contains('RECIPE_PICKER_MAX_10_SENTINEL')));

    expect(mealPicker, contains('DraggableScrollableSheet('));
    expect(mealPicker, isNot(contains('OverflowBox(')));
  });
}
