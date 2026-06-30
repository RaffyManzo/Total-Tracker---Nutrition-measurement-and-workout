import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/tracking/mock/data/mock_tracking_catalog.dart';

void main() {
  test('catalogo mock copre tutte le nuove aree', () {
    expect(MockTrackingCatalog.days, isNotEmpty);
    expect(MockTrackingCatalog.meals, isNotEmpty);
    expect(MockTrackingCatalog.recipes, isNotEmpty);
    expect(MockTrackingCatalog.scaleMeasurements, isNotEmpty);
    expect(MockTrackingCatalog.tapeMeasurements, isNotEmpty);
    expect(MockTrackingCatalog.routines, isNotEmpty);
    expect(MockTrackingCatalog.plans, isNotEmpty);
    expect(MockTrackingCatalog.sessions, isNotEmpty);
  });

  test('lookup per id restituisce gli elementi attesi', () {
    expect(MockTrackingCatalog.dayById('2026-06-29'), isNotNull);
    expect(MockTrackingCatalog.mealById('meal-breakfast'), isNotNull);
    expect(MockTrackingCatalog.recipeById('recipe-rice-chicken'), isNotNull);
    expect(MockTrackingCatalog.routineById('routine-upper'), isNotNull);
    expect(MockTrackingCatalog.planById('plan-main'), isNotNull);
    expect(MockTrackingCatalog.sessionById('session-2026-06-27'), isNotNull);
  });
}
