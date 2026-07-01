import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/entities/nutrition_tracking_entities.dart';
import 'package:total_tracker/features/nutrition/data/repositories/meal_repository.dart';

import '../../helpers/objectbox_test_helper.dart';

void main() {
  test('aggregates ingredient grams by meal and applies date filters',
      () async {
    final database = await openTestDatabase();
    final repository = MealRepository(database.store);

    repository.saveMealWithItems(
      _meal('2026-06-28', 'pranzo'),
      <MealItemEntity>[
        _item('ingredient-a', 80),
        _item('ingredient-a', 20),
        _item('ingredient-b', 50),
      ],
    );
    repository.saveMealWithItems(
      _meal('2026-06-30', 'cena'),
      <MealItemEntity>[_item('ingredient-a', 120)],
    );
    repository.saveMealWithItems(
      _meal('2026-07-02', 'colazione'),
      <MealItemEntity>[_item('ingredient-a', 60)],
    );

    final usage = repository.getIngredientUsage(
      'ingredient-a',
      fromDateKey: '2026-06-29',
      toDateKey: '2026-07-02',
    );

    expect(usage, hasLength(2));
    expect(usage.first.meal.dateKey, '2026-07-02');
    expect(usage.first.grams, 60);
    expect(usage.last.meal.dateKey, '2026-06-30');
    expect(usage.last.grams, 120);
    expect(usage.last.registrationCount, 1);
  });

  test('aggregates duplicate registrations and supports limit', () async {
    final database = await openTestDatabase();
    final repository = MealRepository(database.store);

    repository.saveMealWithItems(
      _meal('2026-07-01', 'pranzo'),
      <MealItemEntity>[
        _item('ingredient-a', 70),
        _item('ingredient-a', 30),
      ],
    );
    repository.saveMealWithItems(
      _meal('2026-07-02', 'cena'),
      <MealItemEntity>[_item('ingredient-a', 90)],
    );

    final usage = repository.getIngredientUsage('ingredient-a', limit: 1);

    expect(usage, hasLength(1));
    expect(usage.single.meal.dateKey, '2026-07-02');

    final allUsage = repository.getIngredientUsage('ingredient-a');
    expect(allUsage.last.grams, 100);
    expect(allUsage.last.registrationCount, 2);
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

MealItemEntity _item(String ingredientUuid, double grams) {
  return MealItemEntity(
    uuid: '',
    kindCode: 'ingredient',
    sourceUuid: ingredientUuid,
    itemNameSnapshot: ingredientUuid,
    grams: grams,
    createdAtEpochMs: 0,
    updatedAtEpochMs: 0,
  );
}
