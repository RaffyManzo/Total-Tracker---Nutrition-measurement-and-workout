import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adaptive target is resolved per day, not per ISO week', () {
    final String source = File(
      'lib/features/nutrition/data/services/food_analytics_service.dart',
    ).readAsStringSync();

    expect(source, contains('adaptiveSummaryForDay'));
    expect(source, contains('monday: normalizedDay'));
    expect(source, contains('now: normalizedDay'));
    expect(source, contains('referenceStartKey'));
    expect(source, contains('day.dateKey.compareTo(dayKey) <= 0'));
    expect(source, contains('allDays: scopedDays'));
    expect(source, isNot(contains('.takeLast(referenceLimit)')));
    expect(source, isNot(contains('extension _TakeLast')));
    expect(
      source,
      isNot(contains('final DateTime monday = date.subtract(')),
    );
  });

  test('dashboard and week load history and expose daily targets', () {
    final String source = File(
      'lib/features/nutrition/presentation/food_v01_screens.dart',
    ).readAsStringSync();

    expect(source, contains("'adaptiveHistoryMs'"));
    expect(source, contains('dailyRepository.listBetween'));
    expect(source, contains('sourceRevision'));
    expect(source, contains('weekTargetResults'));
    expect(source, contains("_Metric('Media target'"));
    expect(source, contains('analytics.targetForDay('));
    expect(source, isNot(contains('minimalDays')));
    expect(source, isNot(contains('Target adattivo settimanale')));
  });

  test('dashboard fixtures provide the cache source revision', () {
    final String appTest = File('test/app_test.dart').readAsStringSync();
    final String persistentTest = File(
      'test/features/persistent_minimal_app_test.dart',
    ).readAsStringSync();

    expect(appTest, contains('sourceRevision: 0'));
    expect(persistentTest, contains('sourceRevision: 0'));
  });

  test('meal entry waits for route disposal without lifecycle races', () {
    final String source = File(
      'lib/features/nutrition/presentation/safe_meal_ingredient_overlay.dart',
    ).readAsStringSync();

    expect(source, contains('await selectionRoute.completed'));
    expect(source, contains('await quantityRoute.completed'));
    expect(source, isNot(contains('Duration(milliseconds: 420)')));
    expect(source, isNot(contains('KeyedSubtree')));
    expect(source, isNot(contains('_mealRevision')));
    expect(source, isNot(contains('TextEditingController')));
  });

  test('day info exposes formula and adaptive inputs', () {
    final String source = File(
      'lib/features/nutrition/presentation/food_v01_screens.dart',
    ).readAsStringSync();

    expect(source, contains('Calcolo adattivo giornaliero'));
    expect(source, contains('Formula finale'));
    expect(source, contains('Attività di riferimento'));
    expect(source, contains('Componente osservata'));
    expect(source, contains('Modalità del giorno'));
    expect(source, contains('Finestra osservata e peso'));
    expect(source, contains('Media calorie usata'));
    expect(source, contains('Variazione peso usata'));
  });
}
