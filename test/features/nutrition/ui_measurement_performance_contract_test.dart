import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('meal surfaces use the quick summary and persistent picker', () {
    final String food = File(
      'lib/features/nutrition/presentation/food_v01_screens.dart',
    ).readAsStringSync();
    final String picker = File(
      'lib/features/nutrition/presentation/'
      'meal_ingredient_batch_picker_sheet.dart',
    ).readAsStringSync();

    expect(food, contains('openMealQuickSummary(context, meal: meal)'));
    expect(
      food,
      isNot(contains("context.push('/food/meals/\${meal.meal.id}')")),
    );
    expect(food, contains('MealIngredientBatchPickerSheet('));
    expect(food, contains('_ingredientPickerOpen'));
    expect(
      food,
      isNot(
        contains(
          'showModalBottomSheet<List<MealIngredientBatchSelection>>',
        ),
      ),
    );
    expect(picker, isNot(contains('showBottomSheet(')));
    expect(picker, contains('class MealIngredientBatchPickerController'));
    expect(picker, contains('la pagina resta utilizzabile'));
    expect(picker, contains('_collapsedExtent = 0.18'));
    expect(picker, contains('_dragDeltaDy += details.primaryDelta ?? 0'));
  });

  test('measurement history is complete, filtered and paginated', () {
    final String source = File(
      'lib/features/nutrition/presentation/measurement_screens.dart',
    ).readAsStringSync();

    expect(source, contains('_historyPageSize = 15'));
    expect(source, contains('_mergeMeasurementHistory('));
    expect(source, contains('_MeasurementHistoryPager('));
    expect(source, contains('_MeasurementTrendCard('));
    expect(source, contains('_measurementDateLabel('));
    expect(source, isNot(contains('filteredScale.take(6)')));
    expect(source, isNot(contains('filteredTape.take(6)')));
    expect(source, isNot(contains('scaleMeasurements.take(12)')));
  });

  test('ingredient usage avoids the former N plus one meal scan', () {
    final String repository = File(
      'lib/features/nutrition/data/repositories/meal_repository.dart',
    ).readAsStringSync();
    final int methodStart = repository.indexOf(
      'List<IngredientMealUsage> getIngredientUsage(',
    );
    final int methodEnd = repository.indexOf(
      'List<MealEntity> getMealsForDate(',
      methodStart,
    );
    expect(methodStart, greaterThanOrEqualTo(0));
    expect(methodEnd, greaterThan(methodStart));
    final String method = repository.substring(methodStart, methodEnd);

    expect(
      method,
      contains('final Query<MealItemEntity> itemQuery = _itemBox'),
    );
    expect(method, contains('MealItemEntity_.sourceUuid.equals(cleanUuid)'));
    expect(method, contains('matchingItems = itemQuery.find()'));
    expect(method, contains('_mealBox.get(entry.key)'));
    expect(
      method,
      isNot(contains('for (final MealEntity meal in getAllActive())')),
    );
    expect(method, isNot(contains('getItemsForMeal(meal.id)')));
  });
}
