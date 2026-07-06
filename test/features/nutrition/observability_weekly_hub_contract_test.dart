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
  test('weekly hub is lazy, navigable and hides stale week content', () {
    final String source = File(
      'lib/features/nutrition/presentation/food_v01_screens.dart',
    ).readAsStringSync();

    _expectContains(source, 'class _FoodWeekScreenState', 'weekly state');
    _expectContains(
      source,
      'FutureBuilder<_FoodWeekSnapshot>',
      'lazy FutureBuilder',
    );
    _expectContains(
      source,
      'onHorizontalDragEnd: _handleSwipe',
      'horizontal swipe navigation',
    );
    _expectContains(
      source,
      'const _WeekHubLoadingState()',
      'central loading state',
    );
    _expectContains(
      source,
      RegExp(
        r'store\s*\.\s*runAsync\s*<\s*_FoodWeekLoadRequest\s*,\s*_FoodWeekSnapshot\s*>',
      ),
      'ObjectBox worker isolate call',
    );
    _expectContains(
      source,
      '_loadFoodWeekInBackground',
      'ObjectBox background loader callback',
    );
    _expectContains(
      source,
      '_FoodWeekLoadRequest',
      'ObjectBox background loader request',
    );
    _expectContains(
        source, "'workerIsolate': true", 'worker isolate trace flag');
    _expectContains(
        source, 'diagnosticsEnabled: false', 'worker diagnostics flag');
    _expectContains(source, "'weekly_hub.load'", 'weekly load trace');
    _expectContains(
      source,
      '// ignore: unused_element\nclass _WeekCalendarStrip extends StatelessWidget',
      'documented legacy calendar widget',
    );
    _expectNotContains(source, '..add(meal);', 'single-use cascade');
  });

  test('recipe filters use a saved bottom sheet and clear action', () {
    final String source = File(
      'lib/features/nutrition/presentation/recipe_archive_screen.dart',
    ).readAsStringSync();

    _expectContains(
        source, 'Future<void> _openRecipeFilters', 'filter sheet method');
    _expectContains(
        source, "const Text('Salva filtri')", 'save filters action');
    _expectContains(
        source, "const Text('Pulisci filtri')", 'clear filters action');
    final int sheetMethodIndex = source.indexOf(
      'Future<void> _openRecipeFilters',
    );
    expect(
      sheetMethodIndex,
      greaterThan(0),
      reason: 'Filter sheet method boundary missing',
    );
    final String archiveToolbar = source.substring(0, sheetMethodIndex);
    _expectContains(
      archiveToolbar,
      '_openRecipeFilters(',
      'filter sheet toolbar action',
    );
    _expectNotContains(
      archiveToolbar,
      'value: _difficulty,',
      'old inline difficulty binding',
    );
    _expectNotContains(
      archiveToolbar,
      'value: _course,',
      'old inline course binding',
    );
    _expectNotContains(
      archiveToolbar,
      'value: _cuisine,',
      'old inline cuisine binding',
    );
    _expectNotContains(
      archiveToolbar,
      'value: _imageFilter,',
      'old inline image binding',
    );
  });

  test('reliability model and privacy-safe trace are installed', () {
    final String reliability = File(
      'lib/features/nutrition/data/services/tdee_reliability_score.dart',
    ).readAsStringSync();
    final String trace = File(
      'lib/core/diagnostics/interaction_trace.dart',
    ).readAsStringSync();
    final String analytics = File(
      'lib/features/nutrition/data/services/food_analytics_service.dart',
    ).readAsStringSync();
    final String overlay = File(
      'lib/features/nutrition/presentation/safe_meal_ingredient_overlay.dart',
    ).readAsStringSync();

    _expectContains(
        reliability, 'class TdeeReliabilityScore', 'reliability score');
    _expectContains(
      reliability,
      RegExp(r"code:\s*'intake_days'[\s\S]*?maximum:\s*25,"),
      '25-point usable intake component',
    );
    _expectContains(trace, 'sampleEvery', 'sampled trace support');
    _expectContains(
      analytics,
      "'tdee.adaptive_summary.breakdown'",
      'adaptive summary breakdown trace',
    );
    _expectContains(
      overlay,
      "'meal_add_flow.selection_route_disposed'",
      'selection route disposal trace',
    );
    _expectNotContains(overlay, "'ingredientName'", 'ingredient name logging');
    _expectNotContains(overlay, "'grams'", 'ingredient quantity logging');
  });

  test('ingredient search diagnostics cover lifecycle and route pop', () {
    final String source = File(
      'lib/features/nutrition/presentation/unified_ingredient_search_screen.dart',
    ).readAsStringSync();

    _expectContains(
      source,
      "import '../../../core/diagnostics/interaction_trace.dart';",
      'interaction trace import',
    );
    _expectNotContains(
      source,
      "import '../../../core/diagnostics/app_diagnostics.dart';",
      'obsolete diagnostics import',
    );
    _expectContains(
        source, 'late final String _diagnosticScreenId;', 'screen id');
    _expectContains(
      source,
      "'ingredient_search.lifecycle_initialized'",
      'lifecycle initialization trace',
    );
    _expectContains(
      source,
      "'ingredient_search.lifecycle_dispose_started'",
      'lifecycle disposal trace',
    );
    _expectContains(
      source,
      "'ingredient_search.lifecycle_first_build'",
      'first build trace',
    );
    _expectContains(
      source,
      "'ingredient_search.selection_pop_requested'",
      'selection pop trace',
    );
    _expectContains(
      source,
      'navigator.pop<IngredientEntity>(ingredient);',
      'typed route result',
    );
  });

  test('calendar calorie value has an explicit semantic unit', () {
    final String source = File(
      'lib/features/nutrition/presentation/widgets/month_meal_calendar_card.dart',
    ).readAsStringSync();

    _expectContains(
      source,
      'Icons.local_fire_department_rounded',
      'calorie icon',
    );
    _expectContains(source, r"'${info.kcal.round()} kcal'", 'kcal unit');
  });
}
