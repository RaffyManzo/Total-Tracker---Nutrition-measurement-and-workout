import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/core/pagination/paged_result.dart';
import 'package:total_tracker/features/nutrition/data/entities/ingredient_entity.dart';
import 'package:total_tracker/features/nutrition/presentation/meal_ingredient_batch_picker_sheet.dart';

void main() {
  IngredientEntity ingredient(int id, String name) => IngredientEntity(
        id: id,
        uuid: 'ingredient-$id',
        name: name,
        kcalPerReference: 100,
        createdAtEpochMs: 1,
        updatedAtEpochMs: 1,
      );

  PagedResult<IngredientEntity> pageFrom(
    List<IngredientEntity> values, {
    required int page,
    required int pageSize,
    required String search,
    String brand = '',
  }) {
    final String clean = search.toLowerCase();
    final List<IngredientEntity> filtered = values
        .where(
          (IngredientEntity item) =>
              clean.isEmpty || item.name.toLowerCase().contains(clean),
        )
        .toList(growable: false);
    final int start = (page - 1) * pageSize;
    final int end = (start + pageSize).clamp(0, filtered.length).toInt();
    return PagedResult<IngredientEntity>(
      items: start >= filtered.length
          ? const <IngredientEntity>[]
          : filtered.sublist(start, end),
      page: page,
      pageSize: pageSize,
      totalCount: filtered.length,
    );
  }

  Future<void> waitForPickerSearch(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  testWidgets('selection survives collapse and confirms once', (
    WidgetTester tester,
  ) async {
    final MealIngredientBatchPickerController controller =
        MealIngredientBatchPickerController();
    final List<IngredientEntity> ingredients = <IngredientEntity>[
      ingredient(1, 'Riso'),
      ingredient(2, 'Pane'),
    ];
    var confirmations = 0;
    var discards = 0;
    var pageTaps = 0;
    var confirmed = <MealIngredientBatchSelection>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              Align(
                alignment: Alignment.topCenter,
                child: TextButton(
                  key: const ValueKey<String>('page-action'),
                  onPressed: () => pageTaps += 1,
                  child: const Text('Azione pagina'),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: MealIngredientBatchPickerSheet(
                  controller: controller,
                  loadPage: ({
                    required int page,
                    required int pageSize,
                    required String search,
                    String brand = '',
                  }) =>
                      pageFrom(
                    ingredients,
                    page: page,
                    pageSize: pageSize,
                    search: search,
                  ),
                  onConfirm: (List<MealIngredientBatchSelection> value) {
                    confirmations += 1;
                    confirmed = value;
                  },
                  onDiscard: () => discards += 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(controller.isAttached, isTrue);
    await waitForPickerSearch(tester);
    await tester.enterText(find.byType(TextField).first, 'Riso');
    await waitForPickerSearch(tester);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Riso'));
    await tester.pump();

    controller.collapse();
    await tester.pumpAndSettle();
    expect(find.text('1 alimenti mantenuti'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('page-action')));
    await tester.pump();
    expect(pageTaps, 1);

    controller.expand();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Inserisci le'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey<String>('grams-1')),
      '175,5',
    );
    await tester.tap(find.text('Conferma'));
    await tester.pump();

    expect(confirmations, 1);
    expect(confirmed, hasLength(1));
    expect(confirmed.single.ingredient.id, 1);
    expect(confirmed.single.grams, 175.5);
    expect(discards, 0);
  });

  testWidgets('requests ten-row pages and navigates to the next page', (
    WidgetTester tester,
  ) async {
    final List<IngredientEntity> ingredients = <IngredientEntity>[
      for (int index = 0; index < 35; index += 1)
        ingredient(index + 1, 'Food ${index.toString().padLeft(2, '0')}'),
    ];
    final List<int> requestedPages = <int>[];
    final List<int> requestedPageSizes = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MealIngredientBatchPickerSheet(
            loadPage: ({
              required int page,
              required int pageSize,
              required String search,
              String brand = '',
            }) {
              requestedPages.add(page);
              requestedPageSizes.add(pageSize);
              return pageFrom(
                ingredients,
                page: page,
                pageSize: pageSize,
                search: search,
              );
            },
            onConfirm: (_) {},
            onDiscard: () {},
          ),
        ),
      ),
    );

    await waitForPickerSearch(tester);
    expect(requestedPages, <int>[1]);
    expect(requestedPageSizes, <int>[10]);
    expect(find.text('Pagina 1 di 4'), findsOneWidget);
    expect(find.text('Food 10'), findsNothing);

    await tester.tap(find.byTooltip('Pagina successiva'));
    await waitForPickerSearch(tester);

    expect(requestedPages, <int>[1, 2]);
    expect(requestedPageSizes, <int>[10, 10]);
    expect(find.text('Pagina 2 di 4'), findsOneWidget);
    expect(find.text('Food 00'), findsNothing);
    expect(find.text('Food 10'), findsOneWidget);
  });

  testWidgets('ten mount/unmount cycles detach controller cleanly', (
    WidgetTester tester,
  ) async {
    for (var cycle = 0; cycle < 10; cycle += 1) {
      final MealIngredientBatchPickerController controller =
          MealIngredientBatchPickerController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MealIngredientBatchPickerSheet(
              controller: controller,
              ingredients: <IngredientEntity>[ingredient(cycle + 1, 'Food')],
              onConfirm: (_) {},
              onDiscard: () {},
            ),
          ),
        ),
      );
      expect(controller.isAttached, isTrue);
      await waitForPickerSearch(tester);
      await tester.enterText(find.byType(TextField).first, 'Food');
      await waitForPickerSearch(tester);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Food'));
      await tester.pump();
      controller.collapse();
      await tester.pumpAndSettle();
      expect(find.text('1 alimenti mantenuti'), findsOneWidget);
      controller.expand();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(controller.isAttached, isFalse);
      expect(tester.takeException(), isNull);
    }
  });

  test('meal screen prevents a second picker and re-expands the first', () {
    final String source = File(
      'lib/features/nutrition/presentation/food_v01_screens.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'if (_ingredientPickerOpen) {\n'
        '      _ingredientPickerController.expand();\n'
        '      return;',
      ),
    );
    expect(
      RegExp(r'MealIngredientBatchPickerSheet\(').allMatches(source),
      hasLength(1),
    );
  });

  testWidgets('route pop with an active selection compresses without discard', (
    WidgetTester tester,
  ) async {
    final MealIngredientBatchPickerController controller =
        MealIngredientBatchPickerController();
    var discards = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MealIngredientBatchPickerSheet(
            controller: controller,
            ingredients: <IngredientEntity>[ingredient(1, 'Riso')],
            onConfirm: (_) {},
            onDiscard: () => discards += 1,
          ),
        ),
      ),
    );
    await waitForPickerSearch(tester);
    await tester.enterText(find.byType(TextField).first, 'Riso');
    await waitForPickerSearch(tester);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Riso'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('1 alimenti mantenuti'), findsOneWidget);
    expect(discards, 0);
  });
}
