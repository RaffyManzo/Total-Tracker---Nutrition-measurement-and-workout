import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/app/app.dart';
import 'package:total_tracker/app/router/app_router.dart';
import 'package:total_tracker/core/database/objectbox_database.dart';
import 'package:total_tracker/core/database/objectbox_providers.dart';
import 'package:total_tracker/features/nutrition/data/entities/nutrition_tracking_entities.dart';
import 'package:total_tracker/features/nutrition/data/import/obsidian_development_seed_service.dart';
import 'package:total_tracker/features/nutrition/data/import/obsidian_food_seed.dart';
import 'package:total_tracker/features/nutrition/data/import/obsidian_frontmatter_parser.dart';
import 'package:total_tracker/features/nutrition/data/repositories/daily_record_repository.dart';
import 'package:total_tracker/features/nutrition/data/repositories/meal_repository.dart';
import 'package:total_tracker/features/nutrition/data/repositories/measurement_repository.dart';
import 'package:total_tracker/features/nutrition/data/repositories/recipe_repository.dart';
import 'package:total_tracker/features/nutrition/data/services/food_analytics_service.dart';
import 'package:total_tracker/features/nutrition/data/services/food_planning_service.dart';
import 'package:total_tracker/features/nutrition/presentation/food_v01_screens.dart';
import 'package:total_tracker/features/workout/data/repositories/workout_session_repository.dart';

import '../helpers/objectbox_test_helper.dart';

void main() {
  group('Obsidian parser e mapping', () {
    const ObsidianFrontmatterParser parser = ObsidianFrontmatterParser();
    const ObsidianFoodSeedMapper mapper = ObsidianFoodSeedMapper();

    test('parser YAML frontmatter legge solo il primo blocco', () {
      final result = parser.parse(
        '''
---
date: 2026-06-22
target_kcal: "2.295"
foods:
  - kind: ingredient
    item_name: Riso
---
```dataviewjs
---
ignored: true
```
''',
        relativePath: 'days/2026-06-22.md',
      );

      expect(result.data['date'].toString(), '2026-06-22');
      expect(result.data['ignored'], isNull);
      expect(result.data['foods'], isA<List<dynamic>>());
    });

    test('filtro intervallo date inclusivo', () {
      expect(mapper.isWithinInclusive('2026-06-22', '2026-06-22', '2026-06-30'),
          isTrue);
      expect(mapper.isWithinInclusive('2026-06-30', '2026-06-22', '2026-06-30'),
          isTrue);
      expect(mapper.isWithinInclusive('2026-07-01', '2026-06-22', '2026-06-30'),
          isFalse);
    });

    test('mapping DailyRecord mantiene i campi principali', () {
      final day = mapper.normalizeDay(
        <String, dynamic>{
          'date': '2026-06-22',
          'week': '2026-W26',
          'target_kcal': '2295',
          'peso': '63,1',
          'steps': 8400,
        },
        relativePath: 'days/2026-06-22.md',
      );

      expect(day['uuid'], 'obsidian-day:2026-06-22');
      expect(day['weight_kg'], 63.1);
      expect(day['steps'], 8400);
    });

    test('mapping Meal normalizza pasto e item', () {
      final meal = mapper.normalizeMeal(_standardMealFrontmatter(),
          relativePath: 'meals/2026-W26-2026-06-22-pranzo.md');

      expect(meal['meal_type'], 'pranzo');
      expect(meal['meal_mode'], 'standard');
      expect(meal['items'], hasLength(1));
    });

    test('mapping MealItem preserva snapshot storico', () {
      final item = mapper.normalizeMealItem(
        <String, dynamic>{
          'kind': 'ingredient',
          'source': '[[Food planning and monitoring/ingredients/Riso]]',
          'item_name': 'Riso',
          'grams': '100',
          'kcal': '130',
          'protein_g': '2,7',
        },
        mealUuid: 'meal-1',
        position: 0,
      );

      expect(item['source'], 'ingredients/Riso');
      expect(item['item_name'], 'Riso');
      expect(item['protein_g'], 2.7);
    });

    test('pasto standard non e parziale', () {
      final meal = mapper.normalizeMeal(_standardMealFrontmatter(),
          relativePath: 'meals/standard.md');
      expect(meal['isNutritionPartial'], isFalse);
    });

    test('pasto free tracked non e parziale', () {
      final meal = mapper.normalizeMeal(
        <String, dynamic>{
          ..._standardMealFrontmatter(),
          'meal_mode': 'free',
          'free_meal_tracking': 'tracked',
        },
        relativePath: 'meals/free-tracked.md',
      );
      expect(meal['isNutritionPartial'], isFalse);
    });

    test('pasto free estimated con stima manuale valida non e parziale', () {
      final meal = mapper.normalizeMeal(
        <String, dynamic>{
          ..._standardMealFrontmatter(),
          'meal_mode': 'free',
          'free_meal_tracking': 'estimated',
          'foods': <Map<String, dynamic>>[
            <String, dynamic>{
              'kind': 'manual_estimate',
              'item_name': 'Pizza stimata',
              'kcal': 800,
            },
          ],
        },
        relativePath: 'meals/free-estimated.md',
      );
      expect(meal['isNutritionPartial'], isFalse);
    });

    test('pasto free untracked e nutrizione parziale', () {
      final meal = mapper.normalizeMeal(
        <String, dynamic>{
          ..._standardMealFrontmatter(),
          'meal_mode': 'free',
          'free_meal_tracking': 'untracked',
          'foods': <Map<String, dynamic>>[],
        },
        relativePath: 'meals/free-untracked.md',
      );
      expect(meal['isNutritionPartial'], isTrue);
    });

    test('calcolo totale pasto somma gli item', () {
      final totals = mapper.totalItems(<Map<String, dynamic>>[
        <String, dynamic>{'kcal': 100, 'protein_g': 5},
        <String, dynamic>{'kcal': '50', 'protein_g': '2,5'},
      ]);

      expect(totals.kcal, 150);
      expect(totals.proteinGrams, 7.5);
    });

    test('nutrizione parziale per estimated senza calorie', () {
      expect(
        mapper.isMealNutritionPartial(
          'free',
          'estimated',
          <Map<String, dynamic>>[
            <String, dynamic>{'kind': 'manual_estimate', 'kcal': 0},
          ],
        ),
        isTrue,
      );
    });
  });

  group('Repository e import ObjectBox', () {
    test('import idempotente e relazioni DailyRecord -> Meal -> MealItem',
        () async {
      final database = await openTestDatabase();
      final service = ObsidianDevelopmentSeedService(database.store);

      final first = service.importFromJson(_seedJson());
      final second = service.importFromJson(_seedJson());

      final dailyRecords = DailyRecordRepository(database.store);
      final meals = MealRepository(database.store);
      expect(first.days, 1);
      expect(second.meals, 1);
      expect(dailyRecords.getAllActive(), hasLength(1));
      expect(meals.getAllActive(), hasLength(1));
      final meal = meals.getAllActive().single;
      expect(meal.dailyRecord.target?.dateKey, '2026-06-22');
      expect(meals.getItemsForMeal(meal.id), hasLength(1));
      expect(meals.getItemsForMeal(meal.id).single.itemNameSnapshot, 'Riso');
    });

    test('relazioni DailyRecord -> Meal -> MealItem sono navigabili', () async {
      final database = await openTestDatabase();
      ObsidianDevelopmentSeedService(database.store)
          .importFromJson(_seedJson());
      final dailyRecords = DailyRecordRepository(database.store);
      final meals = MealRepository(database.store);

      final DailyRecordEntity day = dailyRecords.findByDate('2026-06-22')!;
      final MealEntity meal = meals.getMealsForDate(day.dateKey).single;
      final MealItemEntity item = meals.getItemsForMeal(meal.id).single;

      expect(meal.dailyRecord.targetId, day.id);
      expect(item.meal.targetId, meal.id);
    });

    test('repository giorno crea e aggiorna record', () async {
      final database = await openTestDatabase();
      final repository = DailyRecordRepository(database.store);

      final record = repository.createEmpty('2026-06-22');
      record.targetKcal = 2200;
      repository.save(record);
      record.targetKcal = 2300;
      repository.save(record);

      expect(repository.findByDate('2026-06-22')?.targetKcal, 2300);
    });

    test('repository pasto salva padre e figli', () async {
      final database = await openTestDatabase();
      final dailyRecords = DailyRecordRepository(database.store);
      dailyRecords.save(dailyRecords.createEmpty('2026-06-22'));
      final repository = MealRepository(database.store);

      final meal = repository.createEmpty(
        dateKey: '2026-06-22',
        mealTypeCode: 'pranzo',
      );
      repository.saveMealWithItems(
        meal,
        <MealItemEntity>[
          MealItemEntity(
            uuid: '',
            kindCode: 'manual_estimate',
            itemNameSnapshot: 'Stima',
            kcal: 500,
            createdAtEpochMs: 0,
            updatedAtEpochMs: 0,
          ),
        ],
      );

      expect(repository.getMealsForDate('2026-06-22'), hasLength(1));
      expect(repository.getAllWithItems().single.totals.kcal, 500);
    });

    test('servizio food auto-crea giorno e slot pasto in modo idempotente',
        () async {
      final database = await openTestDatabase();
      final service = FoodPlanningService(
        dailyRecords: DailyRecordRepository(database.store),
        meals: MealRepository(database.store),
        recipes: RecipeRepository(database.store),
      );

      final first = service.ensureDay('2026-06-22');
      final second = service.ensureDay('2026-06-22');

      expect(first.day.uuid, 'auto-day:2026-06-22');
      expect(second.meals, hasLength(4));
      expect(
          DailyRecordRepository(database.store).getAllActive(), hasLength(1));
      expect(MealRepository(database.store).getAllActive(), hasLength(4));
    });

    test('peso del giorno viene letto dalla misurazione bilancia', () async {
      final database = await openTestDatabase();
      final dailyRecords = DailyRecordRepository(database.store);
      final day = dailyRecords.createEmpty('2026-06-22');
      day.weightKg = 61;
      dailyRecords.save(day);
      MeasurementRepository(database.store).saveScale(
        ScaleMeasurementEntity(
          uuid: '',
          dateKey: '2026-06-22',
          title: '',
          weightKg: 62.4,
          createdAtEpochMs: 0,
          updatedAtEpochMs: 0,
        ),
      );

      final analytics = _analytics(database);

      expect(analytics.weightForDay(day), 62.4);
    });
  });

  group('Widget persistenti', () {
    testWidgets(
      'Food Hub con database vuoto mostra dashboard pronta',
      (tester) async {
        final database = (await tester.runAsync(() => openTestDatabase()))!;
        await tester.pumpWidget(
          _withProviderOverrides(
            foodHubData: _foodHubData(
              database,
              latest: null,
              latestMeals: const [],
              days: const [],
            ),
            child: const MaterialAppForTest(child: FoodHubScreen()),
          ),
        );
        await _pumpAsync(tester);

        expect(find.text('Riepilogo giornaliero'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets('Food Hub con dati mostra il giorno', (tester) async {
      final database = (await tester.runAsync(() => openTestDatabase()))!;
      await tester.pumpWidget(
        _withProviderOverrides(
          foodHubData: _foodHubData(database),
          child: const MaterialAppForTest(child: FoodHubScreen()),
        ),
      );
      await _pumpAsync(tester);

      expect(find.textContaining('2026-06-22'), findsWidgets);
      expect(find.text('Riepilogo giornaliero'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('navigazione Home -> Food Hub', (tester) async {
      final database = (await tester.runAsync(() => openTestDatabase()))!;
      appRouter.go('/food');

      await tester.pumpWidget(
        _withProviderOverrides(
          database: database,
          foodHubData: _foodHubData(
            database,
            latest: null,
            latestMeals: const [],
            days: const [],
          ),
          child: const TotalTrackerApp(),
        ),
      );
      await _pumpAsync(tester);

      expect(find.text('Riepilogo giornaliero'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('navigazione Home -> Workout Hub', (tester) async {
      appRouter.go('/workout');

      await tester.pumpWidget(
        _withProviderOverrides(child: const TotalTrackerApp()),
      );
      await _pumpAsync(tester);

      expect(find.text('Allenamento in preparazione'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
  test('source manifest invariato prima e dopo lettura', () async {
    final Directory directory =
        await Directory.systemTemp.createTemp('tt_manifest_test_');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final File markdown = File('${directory.path}/day.md');
    await markdown.writeAsString('---\ndate: 2026-06-22\n---\n');

    final before = await _manifest(markdown);
    await markdown.readAsString();
    final after = await _manifest(markdown);

    expect(after, before);
  });
}

Map<String, dynamic> _standardMealFrontmatter() {
  return <String, dynamic>{
    'week': '2026-W26',
    'date': '2026-06-22',
    'meal_type': 'pranzo',
    'title': 'Pranzo',
    'meal_mode': 'standard',
    'foods': <Map<String, dynamic>>[
      <String, dynamic>{
        'kind': 'ingredient',
        'source': '[[Food planning and monitoring/ingredients/Riso]]',
        'item_name': 'Riso',
        'grams': 100,
        'kcal': 130,
        'protein_g': 2.7,
        'carbs_g': 28,
        'fat_g': 0.3,
      },
    ],
  };
}

String _seedJson() {
  return jsonEncode(<String, dynamic>{
    'schemaVersion': ObsidianFoodSeedConstants.schemaVersion,
    'dateFrom': '2026-06-22',
    'dateTo': '2026-06-30',
    'generatedAt': '2026-06-30T00:00:00.000Z',
    'days': <Map<String, dynamic>>[
      <String, dynamic>{
        'uuid': 'obsidian-day:2026-06-22',
        'date': '2026-06-22',
        'week': '2026-W26',
        'weekday_key': 'lunedi',
        'weekday_label': 'Lunedi',
        'weekday_index': 1,
        'target_kcal': 2200,
        'steps': 8000,
      },
    ],
    'meals': <Map<String, dynamic>>[
      <String, dynamic>{
        'uuid': 'obsidian-meal:test-pranzo',
        'date': '2026-06-22',
        'week': '2026-W26',
        'weekday_key': 'lunedi',
        'weekday_label': 'Lunedi',
        'meal_type': 'pranzo',
        'title': 'Pranzo',
        'meal_mode': 'standard',
      },
    ],
    'mealItems': <Map<String, dynamic>>[
      <String, dynamic>{
        'uuid': 'obsidian-meal-item:obsidian-meal:test-pranzo:0',
        'mealUuid': 'obsidian-meal:test-pranzo',
        'position': 0,
        'kind': 'ingredient',
        'source': 'ingredients/Riso',
        'item_name': 'Riso',
        'quantity_mode': 'grams',
        'grams': 100,
        'kcal': 130,
        'protein_g': 2.7,
        'carbs_g': 28,
        'fat_g': 0.3,
        'fiber_g': 0,
        'sugar_g': 0,
      },
    ],
    'warnings': <Map<String, dynamic>>[],
    'counts': <String, dynamic>{
      'skipped': 0,
    },
  });
}

Widget _withProviderOverrides({
  required Widget child,
  ObjectBoxDatabase? database,
  FoodHubV01Data? foodHubData,
}) {
  return ProviderScope(
    overrides: [
      if (database != null)
        objectBoxDatabaseProvider.overrideWithValue(database),
      if (database != null)
        databaseInitializationStatusProvider.overrideWithValue(
          const DatabaseInitializationStatus.ready(),
        ),
      if (foodHubData != null)
        foodHubV01Provider.overrideWith((ref) async => foodHubData),
    ],
    child: child,
  );
}

FoodHubV01Data _foodHubData(
  ObjectBoxDatabase database, {
  DailyRecordEntity? latest,
  List<MealWithItems>? latestMeals,
  List<DailyRecordEntity>? days,
}) {
  final DailyRecordEntity fallbackDay = _dayEntity();
  final List<DailyRecordEntity> resolvedDays =
      days ?? <DailyRecordEntity>[fallbackDay];
  final DailyRecordEntity? resolvedLatest =
      days == null && latest == null ? fallbackDay : latest;
  final FoodAnalyticsService analytics = _analytics(database);
  return FoodHubV01Data(
    latest: resolvedLatest,
    latestMeals: latestMeals ?? <MealWithItems>[_mealWithItems()],
    allMeals: latestMeals ?? <MealWithItems>[_mealWithItems()],
    days: resolvedDays,
    ingredients: const [],
    recipes: const [],
    scaleMeasurements: const [],
    tapeMeasurements: const [],
    analytics: analytics,
    adaptiveSummary: analytics.adaptiveSummaryForWeek(
      monday: DateTime(2026, 6, 22),
      allDays: resolvedDays,
    ),
    profile: null,
    sourceRevision: 0,
  );
}

FoodAnalyticsService _analytics(ObjectBoxDatabase database) {
  return FoodAnalyticsService(
    meals: MealRepository(database.store),
    measurements: MeasurementRepository(database.store),
    workoutSessions: WorkoutSessionRepository(database.store),
  );
}

DailyRecordEntity _dayEntity() {
  return DailyRecordEntity(
    uuid: 'day',
    dateKey: '2026-06-22',
    weekCode: '2026-W26',
    weekdayLabel: 'Lunedi',
    targetKcal: 2200,
    steps: 8000,
    createdAtEpochMs: 0,
    updatedAtEpochMs: 0,
  );
}

MealWithItems _mealWithItems() {
  return MealWithItems(
    meal: MealEntity(
      uuid: 'meal',
      dateKey: '2026-06-22',
      mealTypeCode: 'pranzo',
      title: 'Pranzo',
      createdAtEpochMs: 0,
      updatedAtEpochMs: 0,
    ),
    items: <MealItemEntity>[
      MealItemEntity(
        uuid: 'item',
        kindCode: 'ingredient',
        itemNameSnapshot: 'Riso',
        kcal: 130,
        createdAtEpochMs: 0,
        updatedAtEpochMs: 0,
      ),
    ],
  );
}

Future<Map<String, Object>> _manifest(File file) async {
  final FileStat stat = await file.stat();
  return <String, Object>{
    'path': file.uri.pathSegments.last,
    'size': stat.size,
    'modified': stat.modified.toUtc().toIso8601String(),
    'content': base64Encode(await file.readAsBytes()),
  };
}

class MaterialAppForTest extends StatelessWidget {
  const MaterialAppForTest({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: child);
  }
}

Future<void> _pumpAsync(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}
