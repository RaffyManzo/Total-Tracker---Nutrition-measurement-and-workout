import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void _expectContains(String source, Pattern pattern, String description) {
  expect(
    source.contains(pattern),
    isTrue,
    reason: 'Contract marker missing: $description',
  );
}

void _expectNotContains(String source, Pattern pattern, String description) {
  expect(
    source.contains(pattern),
    isFalse,
    reason: 'Forbidden contract marker found: $description',
  );
}

void main() {
  test('adaptive target is resolved per day, not per ISO week', () {
    final String source = File(
      'lib/features/nutrition/data/services/food_analytics_service.dart',
    ).readAsStringSync();

    _expectContains(source, 'adaptiveSummaryForDay', 'daily adaptive summary');
    _expectContains(source, 'monday: normalizedDay', 'normalized daily anchor');
    _expectContains(source, 'now: normalizedDay', 'normalized current day');
    _expectContains(source, 'referenceStartKey', 'reference window start');
    _expectContains(
      source,
      'day.dateKey.compareTo(dayKey) <= 0',
      'causal history boundary',
    );
    _expectContains(source, 'allDays: scopedDays', 'scoped daily history');
    _expectNotContains(
      source,
      '.takeLast(referenceLimit)',
      'legacy trailing history truncation',
    );
    _expectNotContains(
        source, 'extension _TakeLast', 'legacy take-last extension');
    _expectNotContains(
      source,
      'final DateTime monday = date.subtract(',
      'weekly target anchor',
    );
  });

  test('dashboard and lazy week hub load history and expose daily targets', () {
    final String source = File(
      'lib/features/nutrition/presentation/food_v01_screens.dart',
    ).readAsStringSync();

    _expectContains(source, "'adaptiveHistoryMs'", 'dashboard history timing');
    _expectContains(
      source,
      'dailyRepository.listBetween',
      'bounded history query',
    );
    _expectContains(source, 'sourceRevision', 'cache source revision');
    _expectContains(
      source,
      'class _FoodWeekLoadRequest',
      'lazy week request model',
    );
    _expectContains(
      source,
      'class _FoodWeekSnapshot',
      'lazy week snapshot model',
    );
    _expectContains(
      source,
      'analytics.targetResultForDay(',
      'per-day adaptive target calculation',
    );
    _expectContains(
      source,
      'final bool hasPersistedTarget',
      'persisted target reuse marker',
    );
    _expectContains(
      source,
      "phases['dailyTargetsMs']",
      'daily target timing',
    );
    _expectNotContains(
      source,
      'weekTargetResults',
      'removed eager weekly target map',
    );
    _expectNotContains(source, 'minimalDays', 'legacy minimal-day fixture');
    _expectNotContains(
      source,
      'Target adattivo settimanale',
      'legacy weekly adaptive target label',
    );
  });

  test('dashboard fixtures provide the cache source revision', () {
    final String appTest = File('test/app_test.dart').readAsStringSync();
    final String persistentTest = File(
      'test/features/persistent_minimal_app_test.dart',
    ).readAsStringSync();

    _expectContains(appTest, 'sourceRevision: 0', 'app fixture revision');
    _expectContains(
      persistentTest,
      'sourceRevision: 0',
      'persistent fixture revision',
    );
  });

  test('meal entry waits for route disposal without lifecycle races', () {
    final String source = File(
      'lib/features/nutrition/presentation/safe_meal_ingredient_overlay.dart',
    ).readAsStringSync();

    _expectContains(
      source,
      'await selectionRoute.completed',
      'selection route disposal wait',
    );
    _expectContains(
      source,
      'await quantityRoute.completed',
      'quantity route disposal wait',
    );
    _expectNotContains(
      source,
      'Duration(milliseconds: 420)',
      'fixed lifecycle delay',
    );
    _expectContains(source, 'KeyedSubtree', 'meal detail reload boundary');
    _expectContains(source, '_childRevision', 'meal detail reload revision');
    _expectNotContains(
      source,
      'TextEditingController',
      'controller retained by overlay',
    );
  });

  test('day info exposes formula and adaptive inputs', () {
    final String source = File(
      'lib/features/nutrition/presentation/food_v01_screens.dart',
    ).readAsStringSync();

    _expectContains(
      source,
      'Calcolo adattivo giornaliero',
      'daily adaptive title',
    );
    _expectContains(source, 'Formula finale', 'final formula');
    _expectContains(
      source,
      'Attività di riferimento',
      'reference activity',
    );
    _expectContains(source, 'Componente osservata', 'observed component');
    _expectContains(source, 'Modalità del giorno', 'daily mode');
    _expectContains(
      source,
      'Finestra osservata e peso',
      'observed window and weight',
    );
    _expectContains(source, 'Media calorie usata', 'used calorie average');
    _expectContains(source, 'Variazione peso usata', 'used weight variation');
  });
}
