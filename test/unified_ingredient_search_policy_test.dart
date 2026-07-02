import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/services/unified_ingredient_search_service.dart';

void main() {
  test('visible page size is fixed at 25', () {
    expect(UnifiedIngredientSearchPolicy.pageSize, 25);
    expect(UnifiedIngredientSearchPolicy.remainingAfterPersonal(0), 25);
    expect(UnifiedIngredientSearchPolicy.remainingAfterPersonal(20), 5);
    expect(UnifiedIngredientSearchPolicy.remainingAfterPersonal(30), 0);
  });

  test('combined pagination continues after external rows already shown', () {
    expect(
      UnifiedIngredientSearchPolicy.externalOffsetForCombinedPage(
        page: 1,
        externalAlreadyShown: 5,
      ),
      5,
    );
    expect(
      UnifiedIngredientSearchPolicy.externalOffsetForCombinedPage(
        page: 2,
        externalAlreadyShown: 5,
      ),
      30,
    );
  });

  test('external search requires at least two characters', () {
    expect(UnifiedIngredientSearchPolicy.canSearchOpenNutrition(''), isFalse);
    expect(UnifiedIngredientSearchPolicy.canSearchOpenNutrition('a'), isFalse);
    expect(UnifiedIngredientSearchPolicy.canSearchOpenNutrition('ab'), isTrue);
  });
}
