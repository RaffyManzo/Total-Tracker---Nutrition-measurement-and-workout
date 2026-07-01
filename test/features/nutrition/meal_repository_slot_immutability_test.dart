import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/entities/nutrition_tracking_entities.dart';
import 'package:total_tracker/features/nutrition/data/repositories/meal_repository.dart';

import '../../helpers/objectbox_test_helper.dart';

void main() {
  test('preserves the original slot when an existing meal is saved', () async {
    final database = await openTestDatabase();
    final repository = MealRepository(database.store);

    final saved = repository.saveMealWithItems(
      MealEntity(
        uuid: '',
        dateKey: '2026-07-02',
        mealTypeCode: 'colazione',
        title: 'Colazione',
        createdAtEpochMs: 0,
        updatedAtEpochMs: 0,
      ),
      const <MealItemEntity>[],
    );

    saved.meal.mealTypeCode = 'cena';
    repository.saveMealWithItems(saved.meal, saved.items);

    final reloaded = repository.getMealWithItemsById(saved.meal.id);
    expect(reloaded, isNotNull);
    expect(reloaded!.meal.mealTypeCode, 'colazione');
  });
}
