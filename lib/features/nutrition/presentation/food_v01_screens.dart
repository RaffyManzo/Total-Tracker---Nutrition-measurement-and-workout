import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/objectbox_providers.dart';
import '../../../shared/widgets/tt_app_card.dart';
import '../../../shared/widgets/tt_global_nav_fab.dart';
import '../../../shared/widgets/tt_mini_charts.dart';
import '../../../shared/widgets/tt_primary_button.dart';
import '../../../shared/widgets/tt_section_header.dart';
import '../../profile/data/entities/user_profile_entity.dart';
import '../data/entities/ingredient_entity.dart';
import '../data/entities/nutrition_tracking_entities.dart';
import '../data/import/obsidian_food_seed.dart';
import '../data/repositories/meal_repository.dart';
import '../data/repositories/recipe_repository.dart';
import '../data/services/food_analytics_service.dart';
import '../data/services/food_planning_service.dart';
import '../data/services/open_food_facts_service.dart';
import 'measurement_screens.dart' show measurementHubProvider;

final FutureProvider<FoodHubV01Data> foodHubV01Provider =
    FutureProvider<FoodHubV01Data>((Ref ref) async {
  final dailyRepository = ref.watch(dailyRecordRepositoryProvider);
  final mealRepository = ref.watch(mealRepositoryProvider);
  final ingredientRepository = ref.watch(ingredientRepositoryProvider);
  final recipeRepository = ref.watch(recipeRepositoryProvider);
  final measurementRepository = ref.watch(measurementRepositoryProvider);
  final planning = ref.watch(foodPlanningServiceProvider);
  final analytics = ref.watch(foodAnalyticsServiceProvider);
  final UserProfileEntity? profile =
      ref.watch(userProfileRepositoryProvider).getActiveProfile();

  planning.ensureDay(_dateKey(DateTime.now()));

  final List<DailyRecordEntity> days = dailyRepository.getAllActive();
  final DailyRecordEntity? latest = days.isEmpty ? null : days.first;
  final List<MealWithItems> latestMeals = latest == null
      ? const <MealWithItems>[]
      : mealRepository.getMealsWithItemsForDate(latest.dateKey);
  final DateTime reference =
      latest == null ? DateTime.now() : DateTime.parse(latest.dateKey);
  final DateTime monday =
      reference.subtract(Duration(days: reference.weekday - 1));

  return FoodHubV01Data(
    latest: latest,
    latestMeals: latestMeals,
    days: days,
    ingredients: ingredientRepository.getAllActive(),
    recipes: recipeRepository.getAllActive(),
    scaleMeasurements: measurementRepository.getScaleMeasurements(),
    tapeMeasurements: measurementRepository.getTapeMeasurements(),
    analytics: analytics,
    adaptiveSummary: analytics.adaptiveSummaryForWeek(
      monday: monday,
      allDays: days,
      profile: profile,
    ),
  );
});

final FutureProvider<List<DailyRecordEntity>> foodDaysV01Provider =
    FutureProvider<List<DailyRecordEntity>>((Ref ref) async {
  return ref.watch(dailyRecordRepositoryProvider).getAllActive();
});

final FutureProvider<List<MealWithItems>> foodMealsV01Provider =
    FutureProvider<List<MealWithItems>>((Ref ref) async {
  return ref.watch(mealRepositoryProvider).getAllWithItems();
});

final FutureProvider<List<IngredientEntity>> ingredientArchiveProvider =
    FutureProvider<List<IngredientEntity>>((Ref ref) async {
  return ref.watch(ingredientRepositoryProvider).getAllActive();
});

final FutureProvider<List<RecipeEntity>> recipeArchiveProvider =
    FutureProvider<List<RecipeEntity>>((Ref ref) async {
  return ref.watch(recipeRepositoryProvider).getAllActive();
});

class FoodHubV01Data {
  const FoodHubV01Data({
    required this.latest,
    required this.latestMeals,
    required this.days,
    required this.ingredients,
    required this.recipes,
    required this.scaleMeasurements,
    required this.tapeMeasurements,
    required this.analytics,
    required this.adaptiveSummary,
  });

  final DailyRecordEntity? latest;
  final List<MealWithItems> latestMeals;
  final List<DailyRecordEntity> days;
  final List<IngredientEntity> ingredients;
  final List<RecipeEntity> recipes;
  final List<ScaleMeasurementEntity> scaleMeasurements;
  final List<TapeMeasurementEntity> tapeMeasurements;
  final FoodAnalyticsService analytics;
  final WeekAdaptiveSummary adaptiveSummary;

  MealNutritionTotals get latestTotals => _totalsForMeals(latestMeals);

  bool get hasPartialNutrition {
    return latestMeals.any((MealWithItems meal) => meal.isNutritionPartial);
  }

  List<TtChartPoint> get recentCalories {
    final List<DailyRecordEntity> recent =
        days.take(7).toList().reversed.toList();
    return <TtChartPoint>[
      for (final DailyRecordEntity day in recent)
        TtChartPoint(
          label: day.dateKey.substring(5),
          value: analytics.caloriesForDate(day.dateKey),
        ),
    ];
  }

  List<TtChartPoint> get recentSteps {
    final List<DailyRecordEntity> recent =
        days.take(7).toList().reversed.toList();
    return <TtChartPoint>[
      for (final DailyRecordEntity day in recent)
        TtChartPoint(
            label: day.dateKey.substring(5), value: day.steps.toDouble()),
    ];
  }
}

class FoodHubScreen extends ConsumerWidget {
  const FoodHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<FoodHubV01Data> data = ref.watch(foodHubV01Provider);
    return Scaffold(
      appBar: AppBar(title: const Text('Alimentazione')),
      floatingActionButton: const TtGlobalNavFab(),
      body: data.when(
        loading: () => const _LoadingState(),
        error: (Object error, StackTrace stackTrace) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(foodHubV01Provider),
        ),
        data: (FoodHubV01Data data) => _FoodHubV01Body(data: data),
      ),
    );
  }
}

class _FoodHubV01Body extends StatelessWidget {
  const _FoodHubV01Body({required this.data});

  final FoodHubV01Data data;

  @override
  Widget build(BuildContext context) {
    final DailyRecordEntity? latest = data.latest;
    final MealNutritionTotals totals = data.latestTotals;
    final ScaleMeasurementEntity? latestScale =
        data.scaleMeasurements.isEmpty ? null : data.scaleMeasurements.first;
    return ListView(
      padding: _screenPadding,
      children: <Widget>[
        Text('Food Plan', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          latest == null
              ? 'Diario pronto. Apri oggi dal pulsante rapido per iniziare.'
              : 'Ultimo giorno: ${latest.weekdayLabel} ${latest.dateKey}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        TtAppCard(
          onTap: latest == null
              ? null
              : () => context.push('/food/days/${latest.dateKey}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Riepilogo recente',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  _StatusPill(
                    label: data.hasPartialNutrition ? 'Parziale' : 'Completo',
                    isWarning: data.hasPartialNutrition,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _MetricGrid(
                metrics: <_Metric>[
                  _Metric('Calorie', _fmtKcal(totals.kcal)),
                  _Metric('Target adattivo',
                      _fmtKcal(data.adaptiveSummary.targetKcal)),
                  _Metric('Passi', latest?.steps.toString() ?? 'n/d'),
                  _Metric('Peso', _fmtNullable(latestScale?.weightKg, 'kg')),
                  _Metric('Acqua', _fmtNullable(latest?.waterLiters, 'l')),
                  _Metric('Sonno', latest == null ? 'n/d' : _sleepText(latest)),
                  _Metric('Pasti', data.latestMeals.length.toString()),
                  _Metric('Misure',
                      '${data.scaleMeasurements.length} + ${data.tapeMeasurements.length}'),
                ],
              ),
            ],
          ),
        ),
        if (data.hasPartialNutrition) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          const TtAppCard(
            child: Text(
              'C’è almeno un pasto libero non quantificato: i grafici usano i totali disponibili, ma il bilancio resta parziale.',
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sectionGap),
        Row(
          children: <Widget>[
            Expanded(
              child: _ChartCard(
                title: 'Calorie',
                subtitle: 'Ultimi giorni',
                child: TtMiniBarChart(points: data.recentCalories),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _ChartCard(
          title: 'Passi',
          subtitle: 'Trend recente',
          child: TtMiniLineChart(points: data.recentSteps),
        ),
        const SizedBox(height: AppSpacing.md),
        TtAppCard(
          onTap: () => _showInsights(context, data),
          child: Row(
            children: <Widget>[
              Icon(Icons.insights_rounded,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Insight generale',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Text(
                        'Macro, peso, misure, calendario e alimenti più usati.'),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        const TtSectionHeader(title: 'Sezioni'),
        const SizedBox(height: AppSpacing.md),
        _SectionLink(
          title: 'Settimana corrente',
          subtitle:
              '${_dateKey(data.adaptiveSummary.monday)} - ${_dateKey(data.adaptiveSummary.sunday)}',
          icon: Icons.calendar_view_week_rounded,
          route: '/food/week',
        ),
        const SizedBox(height: AppSpacing.md),
        _SectionLink(
          title: 'Giorni',
          subtitle: '${data.days.length} giorni',
          icon: Icons.calendar_today_rounded,
          route: '/food/days',
        ),
        const SizedBox(height: AppSpacing.md),
        _SectionLink(
          title: 'Pasti',
          subtitle: 'Slot automatici colazione, spuntino, pranzo, cena',
          icon: Icons.lunch_dining_rounded,
          route: '/food/meals',
        ),
        const SizedBox(height: AppSpacing.md),
        _SectionLink(
          title: 'Ingredienti',
          subtitle: '${data.ingredients.length} salvati',
          icon: Icons.inventory_2_outlined,
          route: '/food/ingredients',
        ),
        const SizedBox(height: AppSpacing.md),
        _SectionLink(
          title: 'Ricette',
          subtitle: '${data.recipes.length} ricette',
          icon: Icons.menu_book_rounded,
          route: '/food/recipes',
        ),
        const SizedBox(height: AppSpacing.md),
        const _SectionLink(
          title: 'Misurazioni',
          subtitle: 'Bilancia e metro',
          icon: Icons.monitor_weight_outlined,
          route: '/measurements',
        ),
      ],
    );
  }
}

class FoodWeekScreen extends ConsumerWidget {
  const FoodWeekScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<DailyRecordEntity>> daysValue =
        ref.watch(foodDaysV01Provider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settimana')),
      floatingActionButton: const TtGlobalNavFab(),
      body: daysValue.when(
        loading: () => const _LoadingState(),
        error: (Object error, StackTrace stackTrace) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(foodDaysV01Provider),
        ),
        data: (List<DailyRecordEntity> days) {
          final DateTime reference = days.isEmpty
              ? DateTime.now()
              : DateTime.parse(days.first.dateKey);
          final DateTime monday =
              reference.subtract(Duration(days: reference.weekday - 1));
          final FoodPlanningService planning =
              ref.read(foodPlanningServiceProvider);
          for (int index = 0; index < 7; index += 1) {
            planning.ensureDay(_dateKey(monday.add(Duration(days: index))));
          }
          final List<DailyRecordEntity> refreshed =
              ref.read(dailyRecordRepositoryProvider).getAllActive();
          final Map<String, DailyRecordEntity> byDate =
              <String, DailyRecordEntity>{
            for (final DailyRecordEntity day in refreshed) day.dateKey: day,
          };
          final MealRepository mealRepository =
              ref.watch(mealRepositoryProvider);
          final FoodAnalyticsService analytics =
              ref.watch(foodAnalyticsServiceProvider);
          final UserProfileEntity? profile =
              ref.watch(userProfileRepositoryProvider).getActiveProfile();
          final WeekAdaptiveSummary adaptive = analytics.adaptiveSummaryForWeek(
            monday: monday,
            allDays: refreshed,
            profile: profile,
          );
          final List<DailyRecordEntity> weekDays = <DailyRecordEntity>[
            for (int index = 0; index < 7; index += 1)
              if (byDate[_dateKey(monday.add(Duration(days: index)))] != null)
                byDate[_dateKey(monday.add(Duration(days: index)))]!,
          ];
          final double avgCalories = weekDays.isEmpty
              ? 0
              : weekDays.fold<double>(
                    0,
                    (double sum, DailyRecordEntity day) =>
                        sum + analytics.caloriesForDate(day.dateKey),
                  ) /
                  weekDays.length;
          final double avgSteps = weekDays.isEmpty
              ? 0
              : weekDays.fold<double>(
                    0,
                    (double sum, DailyRecordEntity day) => sum + day.steps,
                  ) /
                  weekDays.length;
          return ListView(
            padding: _screenPadding,
            children: <Widget>[
              Text(
                '${_dateKey(monday)} - ${_dateKey(monday.add(const Duration(days: 6)))}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              TtAppCard(
                onTap: () => _showAdaptiveDetails(context, adaptive),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text('Target adattivo settimanale',
                              style: Theme.of(context).textTheme.titleLarge),
                        ),
                        _StatusPill(
                          label: adaptive.targetStatusCode,
                          isWarning: adaptive.targetStatusCode == 'provisional',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MetricGrid(
                      metrics: <_Metric>[
                        _Metric('Target', _fmtKcal(adaptive.targetKcal)),
                        _Metric('TDEE ref', _fmtKcal(adaptive.tdeeRefKcal)),
                        _Metric('Confidenza',
                            '${(adaptive.observedConfidence * 100).round()}%'),
                        _Metric('Giorni ref',
                            adaptive.referenceDaysCount.toString()),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _MetricGrid(
                metrics: <_Metric>[
                  _Metric('Media calorie', _fmtKcal(avgCalories)),
                  _Metric('Media passi', avgSteps.round().toString()),
                  _Metric('Giorni', '${weekDays.length}/7'),
                  _Metric(
                      'Delta attività', _fmtKcal(adaptive.activityDeltaKcal)),
                ],
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              for (int index = 0; index < 7; index += 1) ...<Widget>[
                Builder(
                  builder: (BuildContext context) {
                    final DateTime date = monday.add(Duration(days: index));
                    final String key = _dateKey(date);
                    return _WeekDayCard(
                      date: date,
                      day: byDate[key],
                      meals: mealRepository.getMealsWithItemsForDate(key),
                      analytics: analytics,
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      ),
    );
  }
}

class FoodDaysScreen extends ConsumerWidget {
  const FoodDaysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<DailyRecordEntity>> days =
        ref.watch(foodDaysV01Provider);
    return Scaffold(
      appBar: AppBar(title: const Text('Giorni')),
      floatingActionButton: const TtGlobalNavFab(),
      body: days.when(
        loading: () => const _LoadingState(),
        error: (Object error, StackTrace stackTrace) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(foodDaysV01Provider),
        ),
        data: (List<DailyRecordEntity> days) {
          if (days.isEmpty) {
            return const _EmptyState(
              title: 'Nessun giorno',
              message:
                  'Aprendo oggi o una settimana il giorno viene creato automaticamente.',
            );
          }
          final FoodAnalyticsService analytics =
              ref.watch(foodAnalyticsServiceProvider);
          return ListView.separated(
            padding: _screenPadding,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              final DailyRecordEntity day = days[index];
              return TtAppCard(
                onTap: () => context.push('/food/days/${day.dateKey}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('${day.weekdayLabel} ${day.dateKey}',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.md),
                    _MetricGrid(
                      metrics: <_Metric>[
                        _Metric('Calorie',
                            _fmtKcal(analytics.caloriesForDate(day.dateKey))),
                        _Metric('Target', _fmtNullableKcal(day.targetKcal)),
                        _Metric('Passi', day.steps.toString()),
                        _Metric('Peso',
                            _fmtNullable(analytics.weightForDay(day), 'kg')),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class FoodDayDetailScreen extends ConsumerStatefulWidget {
  const FoodDayDetailScreen({
    required this.date,
    super.key,
  });

  final String date;

  @override
  ConsumerState<FoodDayDetailScreen> createState() =>
      _FoodDayDetailScreenState();
}

class _FoodDayDetailScreenState extends ConsumerState<FoodDayDetailScreen> {
  late FoodDayBundle _bundle;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final String dateKey = widget.date == 'today' || widget.date == 'new'
        ? _dateKey(DateTime.now())
        : widget.date;
    _bundle = ref.read(foodPlanningServiceProvider).ensureDay(dateKey);
    _loaded = true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: _LoadingState());
    }
    final DailyRecordEntity day = _bundle.day;
    final MealRepository mealRepository = ref.watch(mealRepositoryProvider);
    final FoodAnalyticsService analytics =
        ref.watch(foodAnalyticsServiceProvider);
    final List<MealWithItems> meals =
        mealRepository.getMealsWithItemsForDate(day.dateKey);
    final double caloriesIn = analytics.caloriesForDate(day.dateKey);
    final ActivityBreakdown activity = analytics.activityForDay(day);
    final double? target = day.targetKcal;
    final double? balance = target == null ? null : caloriesIn - target;
    final double? weight = analytics.weightForDay(day);
    final bool partial = analytics.hasPartialNutrition(day.dateKey);

    return Scaffold(
      appBar: AppBar(
        title: Text('${day.weekdayLabel} ${day.dateKey}'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Aggiorna monitoraggio',
            onPressed: () => _showDayTrackingDialog(day, weight),
            icon: const Icon(Icons.edit_note_rounded),
          ),
        ],
      ),
      floatingActionButton: const TtGlobalNavFab(),
      body: ListView(
        padding: _screenPadding,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  day.weekCode,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              _StatusPill(
                  label: partial ? 'Parziale' : 'Completo', isWarning: partial),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TtPrimaryButton(
            label: 'Aggiorna dati giornalieri',
            icon: Icons.edit_note_rounded,
            onPressed: () => _showDayTrackingDialog(day, weight),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          _MetricGrid(
            metrics: <_Metric>[
              _Metric('Target kcal', _fmtNullableKcal(target)),
              _Metric('Assunte', _fmtKcal(caloriesIn)),
              _Metric(
                  'Bilancio', balance == null ? 'n/d' : _signedKcal(balance)),
              _Metric('Passi kcal', _fmtKcal(activity.stepKcal)),
              _Metric(
                  'Workout completed', _fmtKcal(activity.completedWorkoutKcal)),
              _Metric('Attive effettive', _fmtKcal(activity.actualTotalKcal)),
              _Metric('Peso', _fmtNullable(weight, 'kg')),
              _Metric('Acqua', _fmtNullable(day.waterLiters, 'l')),
              _Metric('Bicchieri', day.waterGlasses?.toString() ?? 'n/d'),
              _Metric('Sonno profondo', _fmtNullable(day.sleepDeepHours, 'h')),
              _Metric('Sonno leggero', _fmtNullable(day.sleepLightHours, 'h')),
              _Metric('Qualità sonno',
                  day.sleepQualityCode.isEmpty ? 'n/d' : day.sleepQualityCode),
              _Metric('Passi', day.steps.toString()),
              _Metric('Obiettivo passi', day.stepGoal.toString()),
            ],
          ),
          if (partial) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const TtAppCard(
              child: Text(
                'Questo giorno contiene un pasto libero non completamente quantificato. Il bilancio è mostrato come indicazione parziale.',
              ),
            ),
          ],
          if (day.notes.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sectionGap),
            const TtSectionHeader(title: 'Note'),
            const SizedBox(height: AppSpacing.md),
            TtAppCard(child: Text(day.notes)),
          ],
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Pasti'),
          const SizedBox(height: AppSpacing.md),
          for (final String slot in ObsidianFoodSeedConstants.mealSlots)
            _MealSlotTile(
              slot: slot,
              dateKey: day.dateKey,
              meal: meals.where((MealWithItems item) {
                return item.meal.mealTypeCode == slot;
              }).firstOrNull,
            ),
        ],
      ),
    );
  }

  Future<void> _showDayTrackingDialog(
    DailyRecordEntity day,
    double? measuredWeight,
  ) async {
    final TextEditingController target =
        TextEditingController(text: day.targetKcal?.toStringAsFixed(0) ?? '');
    final TextEditingController weight =
        TextEditingController(text: measuredWeight?.toString() ?? '');
    final TextEditingController water =
        TextEditingController(text: day.waterLiters?.toString() ?? '');
    final TextEditingController glasses =
        TextEditingController(text: day.waterGlasses?.toString() ?? '');
    final TextEditingController deep =
        TextEditingController(text: day.sleepDeepHours?.toString() ?? '');
    final TextEditingController light =
        TextEditingController(text: day.sleepLightHours?.toString() ?? '');
    final TextEditingController quality =
        TextEditingController(text: day.sleepQualityCode);
    final TextEditingController steps =
        TextEditingController(text: day.steps.toString());
    final TextEditingController stepGoal =
        TextEditingController(text: day.stepGoal.toString());
    final TextEditingController notes = TextEditingController(text: day.notes);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Monitoraggio giornaliero'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _field(target, 'Target kcal',
                      keyboardType: TextInputType.number),
                  _field(weight, 'Peso bilancia kg',
                      keyboardType: TextInputType.number),
                  _field(water, 'Acqua litri',
                      keyboardType: TextInputType.number),
                  _field(glasses, 'Bicchieri',
                      keyboardType: TextInputType.number),
                  _field(deep, 'Sonno profondo ore',
                      keyboardType: TextInputType.number),
                  _field(light, 'Sonno leggero ore',
                      keyboardType: TextInputType.number),
                  _field(quality, 'Qualità sonno'),
                  _field(steps, 'Passi', keyboardType: TextInputType.number),
                  _field(stepGoal, 'Obiettivo passi',
                      keyboardType: TextInputType.number),
                  _field(notes, 'Note', maxLines: 4),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );
    if (saved != true) {
      return;
    }
    day.targetKcal = _toDouble(target.text);
    day.waterLiters = _toDouble(water.text);
    day.waterGlasses = _toInt(glasses.text);
    day.sleepDeepHours = _toDouble(deep.text);
    day.sleepLightHours = _toDouble(light.text);
    day.sleepQualityCode = quality.text.trim();
    day.steps = _toInt(steps.text) ?? 0;
    day.stepGoal = _toInt(stepGoal.text) ?? 8000;
    day.notes = notes.text.trim();
    ref.read(dailyRecordRepositoryProvider).save(day);
    final double? nextWeight = _toDouble(weight.text);
    if (nextWeight != null) {
      final measurementRepository = ref.read(measurementRepositoryProvider);
      final ScaleMeasurementEntity measurement =
          measurementRepository.findScaleByDate(day.dateKey) ??
              ScaleMeasurementEntity(
                uuid: '',
                dateKey: day.dateKey,
                title: 'Bilancia - ${day.dateKey}',
                createdAtEpochMs: 0,
                updatedAtEpochMs: 0,
              );
      measurement.weightKg = nextWeight;
      measurementRepository.saveScale(measurement);
      ref.invalidate(measurementHubProvider);
    }
    ref.invalidate(foodDaysV01Provider);
    ref.invalidate(foodHubV01Provider);
    setState(() =>
        _bundle = ref.read(foodPlanningServiceProvider).ensureDay(day.dateKey));
  }
}

class FoodMealsScreen extends ConsumerWidget {
  const FoodMealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MealWithItems>> meals =
        ref.watch(foodMealsV01Provider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pasti')),
      floatingActionButton: const TtGlobalNavFab(),
      body: meals.when(
        loading: () => const _LoadingState(),
        error: (Object error, StackTrace stackTrace) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(foodMealsV01Provider),
        ),
        data: (List<MealWithItems> meals) {
          if (meals.isEmpty) {
            return const _EmptyState(
              title: 'Nessun pasto',
              message:
                  'I pasti vengono creati automaticamente quando apri un giorno.',
            );
          }
          return ListView.separated(
            padding: _screenPadding,
            itemCount: meals.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              final MealWithItems meal = meals[index];
              return _MealListCard(meal: meal);
            },
          );
        },
      ),
    );
  }
}

class FoodMealDetailScreen extends ConsumerStatefulWidget {
  const FoodMealDetailScreen({
    required this.id,
    this.initialDate,
    this.initialSlot,
    super.key,
  });

  final String id;
  final String? initialDate;
  final String? initialSlot;

  @override
  ConsumerState<FoodMealDetailScreen> createState() =>
      _FoodMealDetailScreenState();
}

class _FoodMealDetailScreenState extends ConsumerState<FoodMealDetailScreen> {
  late MealWithItems _details;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final MealRepository repository = ref.read(mealRepositoryProvider);
    final int? id = int.tryParse(widget.id);
    MealWithItems? details = id == null
        ? repository.getMealWithItemsByUuid(widget.id)
        : repository.getMealWithItemsById(id);
    details ??= ref.read(foodPlanningServiceProvider).ensureMealSlot(
          dateKey: widget.initialDate ?? _dateKey(DateTime.now()),
          mealTypeCode: widget.initialSlot ?? 'colazione',
        );
    _details = details;
  }

  @override
  Widget build(BuildContext context) {
    final MealEntity meal = _details.meal;
    final MealNutritionTotals totals = _details.totals;
    return Scaffold(
      appBar: AppBar(
        title: Text('${_slotEmoji(meal.mealTypeCode)} ${meal.title}'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Modifica pasto',
            onPressed: _showMealSettingsDialog,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      floatingActionButton: const TtGlobalNavFab(),
      body: ListView(
        padding: _screenPadding,
        children: <Widget>[
          _MetricGrid(
            metrics: <_Metric>[
              _Metric(
                  'Settimana', meal.weekCode.isEmpty ? 'n/d' : meal.weekCode),
              _Metric('Calorie', _fmtKcal(totals.kcal)),
              _Metric('Proteine', '${_fmt(totals.proteinGrams)} g'),
              _Metric('Carboidrati', '${_fmt(totals.carbsGrams)} g'),
              _Metric('Grassi', '${_fmt(totals.fatGrams)} g'),
              _Metric('Fibre', '${_fmt(totals.fiberGrams)} g'),
              _Metric('Zuccheri', '${_fmt(totals.sugarGrams)} g'),
              _Metric('Modalità', meal.mealModeCode),
            ],
          ),
          if (_details.isNutritionPartial) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const TtAppCard(
              child: Text(
                'Pasto libero non completamente tracciato: i totali sono parziali.',
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Aggiungi voce'),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              ActionChip(
                avatar: const Icon(Icons.inventory_2_outlined),
                label: const Text('Ingrediente'),
                onPressed: _showAddIngredientDialog,
              ),
              ActionChip(
                avatar: const Icon(Icons.menu_book_rounded),
                label: const Text('Ricetta'),
                onPressed: _showAddRecipeDialog,
              ),
              ActionChip(
                avatar: const Icon(Icons.edit_rounded),
                label: const Text('Stima manuale'),
                onPressed: _showManualEstimateDialog,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Voci'),
          const SizedBox(height: AppSpacing.md),
          if (_details.items.isEmpty)
            const _EmptyInline(message: 'Nessuna voce nel pasto.')
          else
            for (final MealItemEntity item in _details.items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _MealItemCard(
                  item: item,
                  imageUrl: _imageForItem(item),
                  onDelete: () {
                    setState(() {
                      _details = ref
                          .read(foodPlanningServiceProvider)
                          .removeItemAt(_details, item.position);
                    });
                    _invalidateFood(ref);
                  },
                ),
              ),
        ],
      ),
    );
  }

  String _imageForItem(MealItemEntity item) {
    if (item.kindCode != 'ingredient') {
      return '';
    }
    return ref
            .read(ingredientRepositoryProvider)
            .findByUuid(item.sourceUuid)
            ?.imageUrl ??
        '';
  }

  Future<void> _showMealSettingsDialog() async {
    final TextEditingController title =
        TextEditingController(text: _details.meal.title);
    String slot = _details.meal.mealTypeCode;
    String mode = _details.meal.mealModeCode;
    String freeTracking = _details.meal.freeMealTrackingCode.isEmpty
        ? 'tracked'
        : _details.meal.freeMealTrackingCode;
    final TextEditingController freeLabel =
        TextEditingController(text: _details.meal.freeMealLabel);
    final TextEditingController freeNotes =
        TextEditingController(text: _details.meal.freeMealNotes);
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Modifica pasto'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _field(title, 'Titolo', isRequired: true),
                    DropdownButtonFormField<String>(
                      initialValue: slot,
                      decoration: const InputDecoration(labelText: 'Slot'),
                      items: ObsidianFoodSeedConstants.mealSlots
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child:
                              Text('${_slotEmoji(value)} ${_slotLabel(value)}'),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        if (value != null) {
                          setDialogState(() => slot = value);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SegmentedButton<String>(
                      segments: const <ButtonSegment<String>>[
                        ButtonSegment<String>(
                          value: 'standard',
                          label: Text('Standard'),
                        ),
                        ButtonSegment<String>(
                          value: 'free',
                          label: Text('Libero'),
                        ),
                      ],
                      selected: <String>{mode},
                      onSelectionChanged: (Set<String> value) {
                        setDialogState(() => mode = value.first);
                      },
                    ),
                    if (mode == 'free') ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        initialValue: freeTracking,
                        decoration: const InputDecoration(
                          labelText: 'Tracking pasto libero',
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: 'tracked',
                            child: Text('Tracciato'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'estimated',
                            child: Text('Stimato'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'untracked',
                            child: Text('Non tracciato'),
                          ),
                        ],
                        onChanged: (String? value) {
                          if (value != null) {
                            setDialogState(() => freeTracking = value);
                          }
                        },
                      ),
                      _field(freeLabel, 'Etichetta'),
                      _field(freeNotes, 'Note pasto libero', maxLines: 3),
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved != true) {
      return;
    }
    final MealEntity meal = _details.meal;
    meal.title = title.text.trim();
    meal.mealTypeCode = slot;
    meal.mealModeCode = mode;
    meal.freeMealTrackingCode = mode == 'free' ? freeTracking : '';
    meal.freeMealLabel = mode == 'free' ? freeLabel.text.trim() : '';
    meal.freeMealNotes = mode == 'free' ? freeNotes.text.trim() : '';
    setState(() {
      _details = ref.read(mealRepositoryProvider).saveMealWithItems(
            meal,
            _details.items,
          );
    });
    _invalidateFood(ref);
  }

  Future<void> _showAddIngredientDialog() async {
    final List<IngredientEntity> ingredients =
        ref.read(ingredientRepositoryProvider).getAllActive();
    if (ingredients.isEmpty) {
      _snack('Nessun ingrediente salvato.');
      return;
    }
    IngredientEntity selected = ingredients.first;
    final TextEditingController grams = TextEditingController(text: '100');
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Aggiungi ingrediente'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<IngredientEntity>(
                    initialValue: selected,
                    decoration: const InputDecoration(labelText: 'Ingrediente'),
                    items: ingredients.map((IngredientEntity ingredient) {
                      return DropdownMenuItem<IngredientEntity>(
                        value: ingredient,
                        child: Text(ingredient.name),
                      );
                    }).toList(),
                    onChanged: (IngredientEntity? value) {
                      if (value != null) {
                        setDialogState(() => selected = value);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _field(grams, 'Grammi', keyboardType: TextInputType.number),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Aggiungi'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved == true) {
      setState(() {
        _details = ref.read(foodPlanningServiceProvider).addIngredientToMeal(
              meal: _details,
              ingredient: selected,
              grams: _toDouble(grams.text) ?? 100,
            );
      });
      _invalidateFood(ref);
    }
  }

  Future<void> _showAddRecipeDialog() async {
    final List<RecipeEntity> recipes =
        ref.read(recipeRepositoryProvider).getAllActive();
    if (recipes.isEmpty) {
      _snack('Nessuna ricetta salvata.');
      return;
    }
    RecipeEntity selected = recipes.first;
    final TextEditingController portions = TextEditingController(text: '1');
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Aggiungi ricetta'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<RecipeEntity>(
                    initialValue: selected,
                    decoration: const InputDecoration(labelText: 'Ricetta'),
                    items: recipes.map((RecipeEntity recipe) {
                      return DropdownMenuItem<RecipeEntity>(
                        value: recipe,
                        child: Text(recipe.title),
                      );
                    }).toList(),
                    onChanged: (RecipeEntity? value) {
                      if (value != null) {
                        setDialogState(() => selected = value);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _field(portions, 'Porzioni',
                      keyboardType: TextInputType.number),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Aggiungi'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved == true) {
      setState(() {
        _details = ref.read(foodPlanningServiceProvider).addRecipeToMeal(
              meal: _details,
              recipe: selected,
              portions: _toDouble(portions.text) ?? 1,
            );
      });
      _invalidateFood(ref);
    }
  }

  Future<void> _showManualEstimateDialog() async {
    final TextEditingController name = TextEditingController();
    final TextEditingController kcal = TextEditingController();
    final TextEditingController protein = TextEditingController();
    final TextEditingController carbs = TextEditingController();
    final TextEditingController fat = TextEditingController();
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Stima manuale'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _field(name, 'Nome'),
                _field(kcal, 'Kcal', keyboardType: TextInputType.number),
                _field(protein, 'Proteine g',
                    keyboardType: TextInputType.number),
                _field(carbs, 'Carboidrati g',
                    keyboardType: TextInputType.number),
                _field(fat, 'Grassi g', keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Aggiungi'),
            ),
          ],
        );
      },
    );
    if (saved == true) {
      setState(() {
        _details =
            ref.read(foodPlanningServiceProvider).addManualEstimateToMeal(
                  meal: _details,
                  name: name.text,
                  kcal: _toDouble(kcal.text) ?? 0,
                  proteinGrams: _toDouble(protein.text) ?? 0,
                  carbsGrams: _toDouble(carbs.text) ?? 0,
                  fatGrams: _toDouble(fat.text) ?? 0,
                );
      });
      _invalidateFood(ref);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class PersistentIngredientListScreen extends ConsumerStatefulWidget {
  const PersistentIngredientListScreen({super.key});

  @override
  ConsumerState<PersistentIngredientListScreen> createState() =>
      _PersistentIngredientListScreenState();
}

class _PersistentIngredientListScreenState
    extends ConsumerState<PersistentIngredientListScreen> {
  final TextEditingController _query = TextEditingController();
  List<OpenFoodFactsProduct> _onlineResults = const <OpenFoodFactsProduct>[];
  bool _searchingOnline = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<IngredientEntity>> ingredientsValue =
        ref.watch(ingredientArchiveProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingredienti'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Scanner barcode',
            onPressed: () => context.push('/food/ingredients/scan'),
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
          IconButton(
            tooltip: 'Nuovo manuale',
            onPressed: _showManualIngredientDialog,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: const TtGlobalNavFab(),
      body: ingredientsValue.when(
        loading: () => const _LoadingState(),
        error: (Object error, StackTrace stackTrace) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(ingredientArchiveProvider),
        ),
        data: (List<IngredientEntity> ingredients) {
          final String query = _query.text.trim().toLowerCase();
          final List<IngredientEntity> filtered = query.isEmpty
              ? ingredients
              : ingredients.where((IngredientEntity ingredient) {
                  return ingredient.name.toLowerCase().contains(query) ||
                      ingredient.brand.toLowerCase().contains(query) ||
                      ingredient.barcode.contains(query);
                }).toList();
          return ListView(
            padding: _screenPadding,
            children: <Widget>[
              TextField(
                controller: _query,
                decoration: InputDecoration(
                  labelText: 'Cerca alimento salvato o online',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Cerca su Open Food Facts',
                    onPressed: _searchOpenFoodFacts,
                    icon: _searchingOnline
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.public_rounded),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _searchOpenFoodFacts(),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded),
                    label: const Text('Nuovo manuale'),
                    onPressed: _showManualIngredientDialog,
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scanner'),
                    onPressed: () => context.push('/food/ingredients/scan'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.public_rounded),
                    label: const Text('Cerca online'),
                    onPressed: _searchOpenFoodFacts,
                  ),
                ],
              ),
              if (_onlineResults.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.sectionGap),
                const TtSectionHeader(title: 'Open Food Facts'),
                const SizedBox(height: AppSpacing.md),
                for (final OpenFoodFactsProduct product in _onlineResults)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _OnlineProductCard(
                      product: product,
                      onSave: () => _saveOpenFoodFactsProduct(product),
                    ),
                  ),
              ],
              const SizedBox(height: AppSpacing.sectionGap),
              const TtSectionHeader(title: 'Archivio locale'),
              const SizedBox(height: AppSpacing.md),
              if (filtered.isEmpty)
                const _EmptyInline(
                  message: 'Nessun ingrediente locale con questi criteri.',
                )
              else
                for (final IngredientEntity ingredient in filtered)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _IngredientCard(ingredient: ingredient),
                  ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _searchOpenFoodFacts() async {
    final String query = _query.text.trim();
    if (query.isEmpty) {
      return;
    }
    setState(() => _searchingOnline = true);
    try {
      OpenFoodFactsProduct? byBarcode;
      if (RegExp(r'^\d{6,}$').hasMatch(query)) {
        byBarcode =
            await ref.read(openFoodFactsServiceProvider).findByBarcode(query);
      }
      final List<OpenFoodFactsProduct> byText = byBarcode == null
          ? await ref.read(openFoodFactsServiceProvider).searchText(query)
          : <OpenFoodFactsProduct>[byBarcode];
      if (mounted) {
        setState(() => _onlineResults = byText);
      }
    } finally {
      if (mounted) {
        setState(() => _searchingOnline = false);
      }
    }
  }

  Future<void> _saveOpenFoodFactsProduct(OpenFoodFactsProduct product) async {
    final ingredient = product.toIngredientEntity();
    final existing =
        ref.read(ingredientRepositoryProvider).findByBarcode(product.code);
    if (existing != null) {
      ingredient.id = existing.id;
      ingredient.uuid = existing.uuid;
      ingredient.createdAtEpochMs = existing.createdAtEpochMs;
    }
    ref.read(ingredientRepositoryProvider).save(ingredient);
    ref.invalidate(ingredientArchiveProvider);
    _invalidateFood(ref);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} salvato')),
      );
    }
  }

  Future<void> _showManualIngredientDialog() async {
    final TextEditingController name = TextEditingController();
    final TextEditingController brand = TextEditingController();
    final TextEditingController barcode = TextEditingController();
    final TextEditingController kcal = TextEditingController();
    final TextEditingController protein = TextEditingController();
    final TextEditingController carbs = TextEditingController();
    final TextEditingController fat = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Nuovo ingrediente'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _field(name, 'Nome', isRequired: true),
                  _field(brand, 'Brand'),
                  _field(barcode, 'Barcode'),
                  _field(kcal, 'Kcal per 100 g',
                      keyboardType: TextInputType.number),
                  _field(protein, 'Proteine per 100 g',
                      keyboardType: TextInputType.number),
                  _field(carbs, 'Carboidrati per 100 g',
                      keyboardType: TextInputType.number),
                  _field(fat, 'Grassi per 100 g',
                      keyboardType: TextInputType.number),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );
    if (saved != true) {
      return;
    }
    ref.read(ingredientRepositoryProvider).save(
          IngredientEntity(
            uuid: '',
            name: name.text.trim(),
            brand: brand.text.trim(),
            barcode: barcode.text.trim(),
            kcalPerReference: _toDouble(kcal.text) ?? 0,
            proteinPerReference: _toDouble(protein.text) ?? 0,
            carbsPerReference: _toDouble(carbs.text) ?? 0,
            fatPerReference: _toDouble(fat.text) ?? 0,
            createdAtEpochMs: 0,
            updatedAtEpochMs: 0,
          ),
        );
    ref.invalidate(ingredientArchiveProvider);
  }
}

class IngredientScannerScreen extends ConsumerStatefulWidget {
  const IngredientScannerScreen({super.key});

  @override
  ConsumerState<IngredientScannerScreen> createState() =>
      _IngredientScannerScreenState();
}

class _IngredientScannerScreenState
    extends ConsumerState<IngredientScannerScreen> {
  bool _handling = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner barcode')),
      floatingActionButton: const TtGlobalNavFab(),
      body: Stack(
        children: <Widget>[
          MobileScanner(
            onDetect: (BarcodeCapture capture) async {
              if (_handling) {
                return;
              }
              final String? code = capture.barcodes
                  .map((Barcode item) => item.rawValue)
                  .whereType<String>()
                  .firstOrNull;
              if (code == null || code.trim().isEmpty) {
                return;
              }
              setState(() => _handling = true);
              try {
                final OpenFoodFactsProduct? product = await ref
                    .read(openFoodFactsServiceProvider)
                    .findByBarcode(code.trim());
                if (!context.mounted) {
                  return;
                }
                if (product == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Barcode $code non trovato')),
                  );
                  setState(() => _handling = false);
                  return;
                }
                final IngredientEntity ingredient =
                    product.toIngredientEntity();
                final existing = ref
                    .read(ingredientRepositoryProvider)
                    .findByBarcode(product.code);
                if (existing != null) {
                  ingredient.id = existing.id;
                  ingredient.uuid = existing.uuid;
                  ingredient.createdAtEpochMs = existing.createdAtEpochMs;
                }
                ref.read(ingredientRepositoryProvider).save(ingredient);
                ref.invalidate(ingredientArchiveProvider);
                if (!context.mounted) {
                  return;
                }
                context.go('/food/ingredients');
              } finally {
                if (mounted) {
                  setState(() => _handling = false);
                }
              }
            },
          ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.xxxl,
            child: TtAppCard(
              child: Text(
                _handling
                    ? 'Sto leggendo il prodotto su Open Food Facts...'
                    : 'Inquadra il codice a barre. Puoi sempre tornare indietro e inserirlo a mano.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<RecipeEntity>> recipes =
        ref.watch(recipeArchiveProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ricette')),
      floatingActionButton: const TtGlobalNavFab(),
      body: recipes.when(
        loading: () => const _LoadingState(),
        error: (Object error, StackTrace stackTrace) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(recipeArchiveProvider),
        ),
        data: (List<RecipeEntity> recipes) {
          return ListView(
            padding: _screenPadding,
            children: <Widget>[
              TtPrimaryButton(
                label: 'Nuova ricetta',
                icon: Icons.add_rounded,
                onPressed: () => context.push('/food/recipes/new'),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              if (recipes.isEmpty)
                const _EmptyInline(message: 'Nessuna ricetta salvata.')
              else
                for (final RecipeEntity recipe in recipes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: TtAppCard(
                      onTap: () => context.push('/food/recipes/${recipe.id}'),
                      child: Row(
                        children: <Widget>[
                          CircleAvatar(
                            child: Text(recipe.title.isEmpty
                                ? '?'
                                : recipe.title.characters.first.toUpperCase()),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(recipe.title,
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                Text(
                                  '${recipe.servings} porzioni - ${recipe.prepTimeMinutes + recipe.cookTimeMinutes} min',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({
    required this.id,
    super.key,
  });

  final String id;

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _summary = TextEditingController();
  final TextEditingController _servings = TextEditingController(text: '1');
  final TextEditingController _prep = TextEditingController(text: '0');
  final TextEditingController _cook = TextEditingController(text: '0');
  final TextEditingController _difficulty = TextEditingController(text: 'easy');
  final TextEditingController _kcal = TextEditingController();
  final TextEditingController _ingredients = TextEditingController();
  final TextEditingController _steps = TextEditingController();
  RecipeEntity? _recipe;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _servings.dispose();
    _prep.dispose();
    _cook.dispose();
    _difficulty.dispose();
    _kcal.dispose();
    _ingredients.dispose();
    _steps.dispose();
    super.dispose();
  }

  void _load() {
    final int? id = int.tryParse(widget.id);
    final RecipeDetails? details = widget.id == 'new' || id == null
        ? null
        : ref.read(recipeRepositoryProvider).getDetails(id);
    _recipe = details?.recipe;
    if (_recipe != null) {
      _title.text = _recipe!.title;
      _summary.text = _recipe!.summary;
      _servings.text = _recipe!.servings.toString();
      _prep.text = _recipe!.prepTimeMinutes.toString();
      _cook.text = _recipe!.cookTimeMinutes.toString();
      _difficulty.text = _recipe!.difficultyCode;
      _kcal.text = _recipe!.kcalPerServing?.toString() ?? '';
      _ingredients.text = details!.ingredients
          .map((RecipeIngredientEntity item) => item.nameSnapshot)
          .join('\n');
      _steps.text = details.steps
          .map((RecipeStepEntity step) => step.instruction)
          .join('\n');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.id == 'new' ? 'Nuova ricetta' : _title.text)),
      floatingActionButton: const TtGlobalNavFab(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: _screenPadding,
          children: <Widget>[
            _field(_title, 'Titolo', isRequired: true),
            _field(_summary, 'Descrizione', maxLines: 3),
            _field(_servings, 'Porzioni', keyboardType: TextInputType.number),
            _field(_prep, 'Preparazione min',
                keyboardType: TextInputType.number),
            _field(_cook, 'Cottura min', keyboardType: TextInputType.number),
            _field(_difficulty, 'Difficoltà'),
            _field(_kcal, 'Kcal per porzione',
                keyboardType: TextInputType.number),
            _field(_ingredients, 'Ingredienti, uno per riga', maxLines: 6),
            _field(_steps, 'Passaggi, uno per riga', maxLines: 6),
            const SizedBox(height: AppSpacing.md),
            TtPrimaryButton(
              label: 'Salva ricetta',
              icon: Icons.check_rounded,
              onPressed: _saveRecipe,
            ),
          ],
        ),
      ),
    );
  }

  void _saveRecipe() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final RecipeEntity recipe = _recipe ??
        RecipeEntity(
          uuid: '',
          title: _title.text.trim(),
          createdAtEpochMs: 0,
          updatedAtEpochMs: 0,
        );
    recipe.title = _title.text.trim();
    recipe.summary = _summary.text.trim();
    recipe.servings = _toInt(_servings.text) ?? 1;
    recipe.prepTimeMinutes = _toInt(_prep.text) ?? 0;
    recipe.cookTimeMinutes = _toInt(_cook.text) ?? 0;
    recipe.difficultyCode =
        _difficulty.text.trim().isEmpty ? 'easy' : _difficulty.text.trim();
    recipe.kcalPerServing = _toDouble(_kcal.text);
    final List<RecipeIngredientEntity> ingredients = _ingredients.text
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .map((String line) {
      return RecipeIngredientEntity(
        uuid: '',
        nameSnapshot: line,
        createdAtEpochMs: 0,
        updatedAtEpochMs: 0,
      );
    }).toList();
    final List<RecipeStepEntity> steps = _steps.text
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .map((String line) {
      return RecipeStepEntity(
        uuid: '',
        instruction: line,
        createdAtEpochMs: 0,
        updatedAtEpochMs: 0,
      );
    }).toList();
    final RecipeDetails saved = ref
        .read(recipeRepositoryProvider)
        .saveRecipeWithChildren(recipe, ingredients: ingredients, steps: steps);
    ref.invalidate(recipeArchiveProvider);
    context.go('/food/recipes/${saved.recipe.id}');
  }
}

class _WeekDayCard extends StatelessWidget {
  const _WeekDayCard({
    required this.date,
    required this.day,
    required this.meals,
    required this.analytics,
  });

  final DateTime date;
  final DailyRecordEntity? day;
  final List<MealWithItems> meals;
  final FoodAnalyticsService analytics;

  @override
  Widget build(BuildContext context) {
    final String dateKey = _dateKey(date);
    final bool hasFree =
        meals.any((MealWithItems item) => item.meal.mealModeCode == 'free');
    final bool partial =
        meals.any((MealWithItems item) => item.isNutritionPartial);
    final double kcal = meals.fold<double>(
      0,
      (double sum, MealWithItems meal) => sum + meal.totals.kcal,
    );
    return TtAppCard(
      onTap: () => context.push('/food/days/$dateKey'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('${_weekdayFromDate(date)} $dateKey',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              _StatusPill(
                label: day == null ? 'Auto' : 'Presente',
                isWarning: day == null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _MetricGrid(
            metrics: <_Metric>[
              _Metric('Calorie', _fmtKcal(kcal)),
              _Metric('Pasti', meals.length.toString()),
              _Metric('Passi', day?.steps.toString() ?? '0'),
              _Metric(
                  'Peso',
                  day == null
                      ? 'n/d'
                      : _fmtNullable(analytics.weightForDay(day!), 'kg')),
            ],
          ),
          if (hasFree || partial) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              partial
                  ? 'Pasto libero non quantificato'
                  : 'Pasto libero presente',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MealSlotTile extends StatelessWidget {
  const _MealSlotTile({
    required this.slot,
    required this.dateKey,
    required this.meal,
  });

  final String slot;
  final String dateKey;
  final MealWithItems? meal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TtAppCard(
        onTap: () {
          if (meal == null) {
            context.push('/food/meals/new?date=$dateKey&slot=$slot');
          } else {
            context.push('/food/meals/${meal!.meal.id}');
          }
        },
        child: Row(
          children: <Widget>[
            Text(_slotEmoji(slot), style: const TextStyle(fontSize: 28)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(_slotLabel(slot),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    meal == null
                        ? 'Slot pronto'
                        : '${meal!.meal.title} - ${_fmtKcal(meal!.totals.kcal)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _MealListCard extends StatelessWidget {
  const _MealListCard({required this.meal});

  final MealWithItems meal;

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      onTap: () => context.push('/food/meals/${meal.meal.id}'),
      child: Row(
        children: <Widget>[
          Text(_slotEmoji(meal.meal.mealTypeCode),
              style: const TextStyle(fontSize: 28)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(meal.meal.title,
                    style: Theme.of(context).textTheme.titleLarge),
                Text(
                  '${meal.meal.dateKey} - ${_fmtKcal(meal.totals.kcal)} - ${meal.items.length} voci',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _MealItemCard extends StatelessWidget {
  const _MealItemCard({
    required this.item,
    required this.imageUrl,
    required this.onDelete,
  });

  final MealItemEntity item;
  final String imageUrl;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      child: Row(
        children: <Widget>[
          _FoodThumb(
              imageUrl: imageUrl, fallbackIcon: _kindIcon(item.kindCode)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.itemNameSnapshot,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${item.kindCode} - ${_fmtKcal(item.kcal)} - ${_fmt(item.proteinGrams)}P ${_fmt(item.carbsGrams)}C ${_fmt(item.fatGrams)}F',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Rimuovi',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _IngredientCard extends StatelessWidget {
  const _IngredientCard({required this.ingredient});

  final IngredientEntity ingredient;

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      child: Row(
        children: <Widget>[
          _FoodThumb(
            imageUrl: ingredient.imageUrl,
            fallbackIcon: Icons.inventory_2_outlined,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(ingredient.name,
                    style: Theme.of(context).textTheme.titleLarge),
                Text(
                  ingredient.brand.isEmpty
                      ? ingredient.sourceName
                      : ingredient.brand,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${_fmtKcal(ingredient.kcalPerReference)} / ${_fmt(ingredient.nutritionReferenceAmount)}${ingredient.baseUnit}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineProductCard extends StatelessWidget {
  const _OnlineProductCard({
    required this.product,
    required this.onSave,
  });

  final OpenFoodFactsProduct product;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      child: Row(
        children: <Widget>[
          _FoodThumb(
            imageUrl: product.imageUrl,
            fallbackIcon: Icons.public_rounded,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(product.name,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                  product.brand.isEmpty ? product.code : product.brand,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text('${_fmtKcal(product.kcal100)} / 100 g'),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Salva ingrediente',
            onPressed: onSave,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _FoodThumb extends StatelessWidget {
  const _FoodThumb({
    required this.imageUrl,
    required this.fallbackIcon,
  });

  final String imageUrl;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: 54,
        child: imageUrl.trim().isEmpty
            ? ColoredBox(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  fallbackIcon,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return ColoredBox(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      fallbackIcon,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _SectionLink extends StatelessWidget {
  const _SectionLink({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      onTap: () => context.push(route),
      child: Row(
        children: <Widget>[
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value);

  final String label;
  final String value;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth > 620 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 2.15,
          children: metrics.map((_Metric metric) {
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      metric.label,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metric.value,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.isWarning,
  });

  final String label;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: isWarning
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isWarning
                    ? Theme.of(context).colorScheme.onErrorContainer
                    : Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _screenPadding,
      children: <Widget>[
        TtAppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Errore', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(error.toString()),
              const SizedBox(height: AppSpacing.md),
              TtPrimaryButton(
                label: 'Riprova',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _screenPadding,
      children: <Widget>[
        TtAppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(message),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyInline extends StatelessWidget {
  const _EmptyInline({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return TtAppCard(child: Text(message));
  }
}

void _showInsights(BuildContext context, FoodHubV01Data data) {
  final MealNutritionTotals totals = _totalsForMeals(data.latestMeals);
  final double averageBalance = data.days.isEmpty
      ? 0
      : data.days.take(7).fold<double>(0, (double sum, DailyRecordEntity day) {
            final double target =
                day.targetKcal ?? data.adaptiveSummary.targetKcal;
            return sum + data.analytics.caloriesForDate(day.dateKey) - target;
          }) /
          data.days.take(7).length;
  final Map<String, int> eaten = <String, int>{};
  for (final MealWithItems meal in data.latestMeals) {
    for (final MealItemEntity item in meal.items) {
      eaten[item.itemNameSnapshot] = (eaten[item.itemNameSnapshot] ?? 0) + 1;
    }
  }
  final List<MapEntry<String, int>> topFoods = eaten.entries.toList()
    ..sort((MapEntry<String, int> a, MapEntry<String, int> b) {
      return b.value.compareTo(a.value);
    });
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (BuildContext context, ScrollController controller) {
          return ListView(
            controller: controller,
            padding: _screenPadding,
            children: <Widget>[
              Text('Insight generale',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              _MetricGrid(
                metrics: <_Metric>[
                  _Metric('Deficit/surplus medio', _signedKcal(averageBalance)),
                  _Metric('Macro medie',
                      '${_fmt(totals.proteinGrams)}P ${_fmt(totals.carbsGrams)}C ${_fmt(totals.fatGrams)}F'),
                  _Metric('Ingredienti', data.ingredients.length.toString()),
                  _Metric('Ricette', data.recipes.length.toString()),
                ],
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              _ChartCard(
                title: 'Peso',
                subtitle: 'Ultime misurazioni bilancia',
                child: TtMiniLineChart(
                  points: <TtChartPoint>[
                    for (final ScaleMeasurementEntity item
                        in data.scaleMeasurements.take(10).toList().reversed)
                      if (item.weightKg != null)
                        TtChartPoint(
                          label: item.dateKey.substring(5),
                          value: item.weightKg!,
                        ),
                  ],
                  valueSuffix: 'kg',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ChartCard(
                title: 'Misure corporee',
                subtitle: 'Numero misurazioni metro',
                child: TtMiniBarChart(
                  points: <TtChartPoint>[
                    TtChartPoint(
                      label: 'Metro',
                      value: data.tapeMeasurements.length.toDouble(),
                    ),
                    TtChartPoint(
                      label: 'Bilancia',
                      value: data.scaleMeasurements.length.toDouble(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              const TtSectionHeader(title: 'Alimenti ricorrenti'),
              const SizedBox(height: AppSpacing.md),
              if (topFoods.isEmpty)
                const _EmptyInline(
                    message: 'Nessun alimento nel giorno recente.')
              else
                for (final MapEntry<String, int> entry in topFoods.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: TtAppCard(
                      child: Text('${entry.key} - ${entry.value} volte'),
                    ),
                  ),
              const SizedBox(height: AppSpacing.sectionGap),
              const TtSectionHeader(title: 'Calendario rapido'),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final DailyRecordEntity day in data.days.take(14))
                    ActionChip(
                      label: Text(day.dateKey.substring(5)),
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/food/days/${day.dateKey}');
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              TtAppCard(
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/food/ingredients');
                },
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.search_rounded),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                        child: Text('Cerca negli alimenti salvati o online')),
                    Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

void _showAdaptiveDetails(BuildContext context, WeekAdaptiveSummary summary) {
  showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Dettaglio target adattivo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _detailRow('Target settimana', _fmtKcal(summary.targetKcal)),
              _detailRow('TDEE riferimento', _fmtKcal(summary.tdeeRefKcal)),
              _detailRow('TDEE teorico', _fmtKcal(summary.tdeeTheoreticalKcal)),
              _detailRow(
                  'TDEE osservato', _fmtNullableKcal(summary.tdeeObservedKcal)),
              _detailRow('Confidenza',
                  '${(summary.observedConfidence * 100).round()}%'),
              _detailRow(
                  'Giorni riferimento', summary.referenceDaysCount.toString()),
              _detailRow('Introiti validi', summary.validIntakeDays.toString()),
              _detailRow('Pesi validi', summary.validWeightDays.toString()),
              _detailRow('RMR', _fmtNullableKcal(summary.rmrKcal)),
              _detailRow('Peso ref', _fmtNullable(summary.weightRefKg, 'kg')),
              _detailRow('Attività ref', _fmtKcal(summary.activeRefKcal)),
              _detailRow('Attività settimana',
                  _fmtKcal(summary.currentWeekActiveKcal)),
              _detailRow(
                  'Delta attività', _signedKcal(summary.activityDeltaKcal)),
              _detailRow(
                  'Delta peso',
                  summary.deltaWeightKg == null
                      ? 'n/d'
                      : '${_fmt(summary.deltaWeightKg!)} kg'),
              _detailRow(
                  'Media kcal ref', _fmtNullableKcal(summary.avgCalories)),
            ],
          ),
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      );
    },
  );
}

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

void _invalidateFood(WidgetRef ref) {
  ref.invalidate(foodHubV01Provider);
  ref.invalidate(foodDaysV01Provider);
  ref.invalidate(foodMealsV01Provider);
}

MealNutritionTotals _totalsForMeals(List<MealWithItems> meals) {
  double kcal = 0;
  double protein = 0;
  double carbs = 0;
  double fat = 0;
  double fiber = 0;
  double sugar = 0;
  for (final MealWithItems meal in meals) {
    kcal += meal.totals.kcal;
    protein += meal.totals.proteinGrams;
    carbs += meal.totals.carbsGrams;
    fat += meal.totals.fatGrams;
    fiber += meal.totals.fiberGrams;
    sugar += meal.totals.sugarGrams;
  }
  return MealNutritionTotals(
    kcal: kcal,
    proteinGrams: protein,
    carbsGrams: carbs,
    fatGrams: fat,
    fiberGrams: fiber,
    sugarGrams: sugar,
  );
}

Widget _field(
  TextEditingController controller,
  String label, {
  bool isRequired = false,
  TextInputType? keyboardType,
  int maxLines = 1,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: isRequired
          ? (String? value) => value == null || value.trim().isEmpty
              ? 'Campo obbligatorio'
              : null
          : null,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

EdgeInsets get _screenPadding {
  return const EdgeInsets.fromLTRB(
    AppSpacing.screenHorizontal,
    AppSpacing.screenVertical,
    AppSpacing.screenHorizontal,
    AppSpacing.xxxl,
  );
}

IconData _kindIcon(String kindCode) {
  return <String, IconData>{
        'ingredient': Icons.inventory_2_outlined,
        'recipe': Icons.menu_book_rounded,
        'manual_estimate': Icons.edit_rounded,
      }[kindCode] ??
      Icons.restaurant_rounded;
}

String _dateKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _weekdayFromDate(DateTime date) {
  return const <int, String>{
    DateTime.monday: 'Lunedì',
    DateTime.tuesday: 'Martedì',
    DateTime.wednesday: 'Mercoledì',
    DateTime.thursday: 'Giovedì',
    DateTime.friday: 'Venerdì',
    DateTime.saturday: 'Sabato',
    DateTime.sunday: 'Domenica',
  }[date.weekday]!;
}

String _slotLabel(String slot) {
  return const <String, String>{
        'colazione': 'Colazione',
        'spuntino': 'Spuntino',
        'pranzo': 'Pranzo',
        'cena': 'Cena',
      }[slot] ??
      slot;
}

String _slotEmoji(String slot) {
  return const <String, String>{
        'colazione': '🥣',
        'spuntino': '🍎',
        'pranzo': '🍝',
        'cena': '🍽️',
      }[slot] ??
      '🍴';
}

String _sleepText(DailyRecordEntity day) {
  final double total = (day.sleepDeepHours ?? 0) + (day.sleepLightHours ?? 0);
  if (total <= 0) {
    return 'n/d';
  }
  return '${_fmt(total)} h';
}

String _fmtNullable(double? value, String suffix) {
  if (value == null) {
    return 'n/d';
  }
  return '${_fmt(value)} $suffix';
}

String _fmtNullableKcal(double? value) {
  if (value == null) {
    return 'n/d';
  }
  return _fmtKcal(value);
}

String _fmtKcal(double value) {
  return '${value.round()} kcal';
}

String _signedKcal(double value) {
  if (value > 0) {
    return '+${value.round()} kcal';
  }
  return '${value.round()} kcal';
}

String _fmt(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

double? _toDouble(String value) {
  final String normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) {
    return null;
  }
  return double.tryParse(normalized);
}

int? _toInt(String value) {
  final double? parsed = _toDouble(value);
  return parsed?.round();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}
