import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/entities/nutrition_tracking_entities.dart';
import 'package:total_tracker/features/nutrition/data/repositories/meal_repository.dart';

import '../../helpers/objectbox_test_helper.dart';

void main() {
  test('clears all active items for one day while preserving meal slots',
      () async {
    final database = await openTestDatabase();
    final repository = MealRepository(database.store);

    final breakfast = repository.saveMealWithItems(
      _meal('2026-07-02', 'colazione'),
      <MealItemEntity>[_item('yogurt', 150), _item('cereals', 40)],
    );
    final lunch = repository.saveMealWithItems(
      _meal('2026-07-02', 'pranzo'),
      <MealItemEntity>[_item('pasta', 120)],
    );
    repository.saveMealWithItems(
      _meal('2026-07-01', 'cena'),
      <MealItemEntity>[_item('fish', 180)],
    );

    final removed = repository.clearItemsForDate('2026-07-02');

    expect(removed, 3);
    expect(repository.getMealsForDate('2026-07-02'), hasLength(2));
    expect(repository.getItemsForMeal(breakfast.meal.id), isEmpty);
    expect(repository.getItemsForMeal(lunch.meal.id), isEmpty);
    expect(repository.getMealsWithItemsForDate('2026-07-01').single.items,
        hasLength(1));
  });

  test('returns zero when the selected day has no active entries', () async {
    final database = await openTestDatabase();
    final repository = MealRepository(database.store);

    repository.saveMealWithItems(
      _meal('2026-07-02', 'colazione'),
      const <MealItemEntity>[],
    );

    expect(repository.clearItemsForDate('2026-07-02'), 0);
  });
}

MealEntity _meal(String dateKey, String slot) {
  return MealEntity(
    uuid: '',
    dateKey: dateKey,
    mealTypeCode: slot,
    title: '$slot - $dateKey',
    createdAtEpochMs: 0,
    updatedAtEpochMs: 0,
  );
}

MealItemEntity _item(String name, double grams) {
  return MealItemEntity(
    uuid: '',
    kindCode: 'ingredient',
    sourceUuid: name,
    itemNameSnapshot: name,
    grams: grams,
    createdAtEpochMs: 0,
    updatedAtEpochMs: 0,
  );
}
