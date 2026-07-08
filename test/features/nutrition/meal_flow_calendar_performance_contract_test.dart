import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void expectSource(bool condition, String message) {
  expect(condition, isTrue, reason: message);
}

void main() {
  test('batch ingredient picker owns persistent safe state', () {
    final String source = File(
      'lib/features/nutrition/presentation/'
      'meal_ingredient_batch_picker_sheet.dart',
    ).readAsStringSync();

    expectSource(
      source.contains(
        'class MealIngredientBatchPickerSheet extends StatefulWidget',
      ),
      'Missing standalone stateful batch picker',
    );
    expectSource(
      source.contains('final Map<int, String> _gramsById'),
      'Batch picker must keep plain gram strings',
    );
    expectSource(
      !source.contains('Map<int, TextEditingController>'),
      'Batch picker must not own one controller per ingredient row',
    );
    expectSource(
      source.contains('showBottomSheet('),
      'Batch picker must be persistent and non-modal',
    );
    expectSource(
      source.contains('controller.closed.whenComplete'),
      'Persistent picker must complete safely when its scaffold closes',
    );
    expectSource(
      source.contains('widget.onConfirm(result)'),
      'Batch picker must return data before caller persists it',
    );
    expectSource(
      source.contains('la pagina resta utilizzabile'),
      'Collapsed state must explain that the page remains usable',
    );
  });

  test('meal detail uses the persistent batch picker', () {
    final String source = File(
      'lib/features/nutrition/presentation/food_v01_screens.dart',
    ).readAsStringSync();

    expectSource(
      source.contains('showPersistentMealIngredientBatchPicker('),
      'Meal detail must use the persistent batch picker',
    );
    expectSource(
      !source.contains(
        'showModalBottomSheet<List<MealIngredientBatchSelection>>',
      ),
      'Legacy modal batch picker is still present',
    );
    expectSource(
      !source.contains('_pendingIngredientGrams'),
      'Legacy pending controller map is still present',
    );
    expectSource(
      !source.contains('_confirmPendingIngredients'),
      'Legacy confirmation method is still present',
    );
  });

  test('overlay reloads the meal detail after a successful save', () {
    final String source = File(
      'lib/features/nutrition/presentation/safe_meal_ingredient_overlay.dart',
    ).readAsStringSync();
    expectSource(
      source.contains('int _childRevision = 0;'),
      'Missing meal-detail revision',
    );
    expectSource(
      source.contains(r"'meal-detail-${widget.targetId}-$_childRevision'"),
      'Meal detail subtree is not keyed by revision',
    );
    expectSource(
      source.contains("'meal_add_flow.detail_reloaded'"),
      'Missing explicit detail reload trace',
    );
  });

  test('month calendar implements semantic colors and load deduplication', () {
    final String source = File(
      'lib/features/nutrition/presentation/widgets/month_meal_calendar_card.dart',
    ).readAsStringSync();
    for (final String marker in <String>[
      'trackedFreeMeals',
      'estimatedFreeMeals',
      'untrackedFreeMeals',
      'filledMealSlots',
      'Pasti futuri pianificati',
      'Giorno passato incompleto',
      'const Color(0xFF228B22)',
      '_inFlight',
      'dashboard.month_calendar_load.deduplicated',
    ]) {
      expectSource(source.contains(marker), 'Missing calendar marker: $marker');
    }
    expectSource(
      RegExp(
        r'if\s*\(\s*!isFuture\s*&&\s*info\s*!=\s*null\s*&&\s*'
        r'info\.itemCount\s*>\s*0\s*\)',
      ).hasMatch(source),
      'Future days must not display consumed calories',
    );
  });

  test('weekly hub uses one live target calculation and horizontal meal rows',
      () {
    final String source = File(
      'lib/features/nutrition/presentation/food_v01_screens.dart',
    ).readAsStringSync();
    for (final String utf8Marker in <String>[
      'Libero · non tracciato',
      'Libero · stimato',
      'Libero · tracciato',
      'Affidabilità media TDEE:',
      'Caricamento completo della settimana…',
    ]) {
      expectSource(
        source.contains(utf8Marker),
        'Missing or corrupted V24 UTF-8 marker: $utf8Marker',
      );
    }
    expectSource(
      source.contains("phases['liveTargetCalculations']"),
      'Missing weekly live-target counter',
    );
    expectSource(
      source.contains('class _WeekHubMealRow extends StatelessWidget'),
      'Missing horizontal weekly meal rows',
    );
    expectSource(
      source.contains('Libero · non tracciato'),
      'Missing untracked free-meal status',
    );
    expectSource(
      source.contains('final bool hasPersistedTarget'),
      'Weekly loader does not reuse persisted daily targets',
    );
  });

  test('dashboard computes today target once in provider', () {
    final String source = File(
      'lib/features/nutrition/presentation/food_v01_screens.dart',
    ).readAsStringSync();
    expectSource(
      source.contains("'dailyTargetResultMs'"),
      'Dashboard provider does not expose the single target phase',
    );
    expectSource(
      source.contains('final TargetDayResult? latestTargetResult;'),
      'Dashboard data does not carry the precomputed target',
    );
    expectSource(
      source.contains('final WeekAdaptiveSummary adaptiveSummary;'),
      'Dashboard must preserve the non-null legacy summary contract',
    );
    expectSource(
      source.contains("activeRefSourceCode: 'daily_target_result'"),
      'Dashboard summary must be derived from the single target result',
    );
    expectSource(
      RegExp(
        r'latest\s*==\s*null\s*\?\s*null\s*:\s*data\.latestTargetResult',
      ).hasMatch(source),
      'Dashboard body still recomputes its target',
    );
    expectSource(
      !source.contains("'dailyAdaptiveSummaryMs'"),
      'Legacy duplicate adaptive summary phase is still present',
    );
  });
}
