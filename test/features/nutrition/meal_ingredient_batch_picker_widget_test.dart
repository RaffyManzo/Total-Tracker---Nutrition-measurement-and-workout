import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('selection survives collapse and confirms once', (
    WidgetTester tester,
  ) async {
    final MealIngredientBatchPickerController controller =
        MealIngredientBatchPickerController();
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
                  ingredients: <IngredientEntity>[
                    ingredient(1, 'Riso'),
                    ingredient(2, 'Pane'),
                  ],
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
    await tester.enterText(
      find.byType(TextField).first,
      'Riso',
    );
    await tester.pump();
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
    expect(find.text('Inserisci le quantità'), findsOneWidget);
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
      await tester.enterText(find.byType(TextField).first, 'Food');
      await tester.pump();
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
    await tester.enterText(find.byType(TextField).first, 'Riso');
    await tester.pump();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Riso'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('1 alimenti mantenuti'), findsOneWidget);
    expect(discards, 0);
  });
}
