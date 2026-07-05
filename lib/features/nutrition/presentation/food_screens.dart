import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/objectbox_providers.dart';
import '../../../shared/widgets/tt_app_card.dart';
import '../../../shared/widgets/tt_primary_button.dart';
import '../../../shared/widgets/tt_section_header.dart';
import '../data/entities/ingredient_entity.dart';
import '../data/entities/nutrition_tracking_entities.dart';
import '../data/import/obsidian_food_seed.dart';
import '../data/repositories/meal_repository.dart';
import '../data/repositories/recipe_repository.dart';

final FutureProvider<FoodHubData> foodHubDataProvider =
    FutureProvider<FoodHubData>((Ref ref) async {
  final dailyRecords = ref.watch(dailyRecordRepositoryProvider);
  final meals = ref.watch(mealRepositoryProvider);
  final ingredients = ref.watch(ingredientRepositoryProvider);
  final recipes = ref.watch(recipeRepositoryProvider);
  final DailyRecordEntity? latest = dailyRecords.latest();
  final List<MealWithItems> latestMeals = latest == null
      ? <MealWithItems>[]
      : meals.getMealsWithItemsForDate(latest.dateKey);
  return FoodHubData(
    latest: latest,
    latestMeals: latestMeals,
    daysCount: dailyRecords.getAllActive().length,
    mealsCount: meals.getAllActive().length,
    ingredientsCount: ingredients.getAllActive().length,
    recipesCount: recipes.getAllActive().length,
  );
});

final FutureProvider<List<DailyRecordEntity>> dailyRecordsProvider =
    FutureProvider<List<DailyRecordEntity>>((Ref ref) async {
  return ref.watch(dailyRecordRepositoryProvider).getAllActive();
});

final FutureProvider<List<MealWithItems>> mealsProvider =
    FutureProvider<List<MealWithItems>>((Ref ref) async {
  return ref.watch(mealRepositoryProvider).getAllWithItems();
});

final FutureProvider<List<IngredientEntity>> persistentIngredientsProvider =
    FutureProvider<List<IngredientEntity>>((Ref ref) async {
  return ref.watch(ingredientRepositoryProvider).getAllActive();
});

final FutureProvider<List<RecipeEntity>> recipesProvider =
    FutureProvider<List<RecipeEntity>>((Ref ref) async {
  return ref.watch(recipeRepositoryProvider).getAllActive();
});

class FoodHubData {
  const FoodHubData({
    required this.latest,
    required this.latestMeals,
    required this.daysCount,
    required this.mealsCount,
    required this.ingredientsCount,
    required this.recipesCount,
  });

  final DailyRecordEntity? latest;
  final List<MealWithItems> latestMeals;
  final int daysCount;
  final int mealsCount;
  final int ingredientsCount;
  final int recipesCount;

  MealNutritionTotals get latestTotals {
    double kcal = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;
    double fiber = 0;
    double sugar = 0;
    for (final MealWithItems meal in latestMeals) {
      final MealNutritionTotals totals = meal.totals;
      kcal += totals.kcal;
      protein += totals.proteinGrams;
      carbs += totals.carbsGrams;
      fat += totals.fatGrams;
      fiber += totals.fiberGrams;
      sugar += totals.sugarGrams;
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

  bool get hasPartialNutrition {
    return latestMeals.any((MealWithItems meal) => meal.isNutritionPartial);
  }
}

class FoodHubScreen extends ConsumerWidget {
  const FoodHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<FoodHubData> asyncData = ref.watch(foodHubDataProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Alimentazione')),
      body: asyncData.when(
        loading: () => const _LoadingState(),
        error: (Object error, StackTrace stackTrace) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(foodHubDataProvider),
        ),
        data: (FoodHubData data) => _FoodHubBody(data: data),
      ),
    );
  }
}

class _FoodHubBody extends StatelessWidget {
  const _FoodHubBody({required this.data});

  final FoodHubData data;

  @override
  Widget build(BuildContext context) {
    final DailyRecordEntity? latest = data.latest;
    final MealNutritionTotals totals = data.latestTotals;
    return ListView(
      padding: _screenPadding,
      children: <Widget>[
        Text('Food Hub', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          latest == null
              ? 'Database pronto, nessun giorno registrato.'
              : 'Giornata piu recente: ${latest.dateKey}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        if (latest == null)
          const _EmptyInline(
            message:
                'Nessun giorno importato. Crea un giorno o genera il seed locale Obsidian.',
          )
        else ...<Widget>[
          TtAppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${_weekday(latest.weekdayLabel)} ${latest.dateKey}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    _StatusPill(
                      label: data.hasPartialNutrition
                          ? 'Nutrizione parziale'
                          : 'Completa',
                      isWarning: data.hasPartialNutrition,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _MetricGrid(
                  metrics: <_Metric>[
                    _Metric('Calorie pasti', _fmtKcal(totals.kcal)),
                    _Metric('Target', _fmtNullableKcal(latest.targetKcal)),
                    _Metric('Passi', latest.steps.toString()),
                    _Metric('Peso', _fmtNullable(latest.weightKg, 'kg')),
                    _Metric('Acqua', _fmtNullable(latest.waterLiters, 'l')),
                    _Metric('Sonno', _sleepText(latest)),
                    _Metric('Pasti', data.latestMeals.length.toString()),
                    _Metric(
                        'Bilancio', _fmtNullableKcal(latest.energyBalanceKcal)),
                  ],
                ),
              ],
            ),
          ),
          if (data.hasPartialNutrition) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const TtAppCard(
              child: Text(
                'Esiste almeno un pasto libero non quantificato o stimato '
                'parzialmente. I totali dei pasti restano visibili, ma il '
                'bilancio non va letto come completo.',
              ),
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.sectionGap),
        const TtSectionHeader(title: 'Azioni'),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _ActionChipButton(
              icon: Icons.add_rounded,
              label: 'Nuovo giorno',
              onTap: () => context.push('/food/days/new'),
            ),
            _ActionChipButton(
              icon: Icons.add_circle_outline_rounded,
              label: 'Nuovo pasto',
              onTap: () => context.push('/food/meals/new'),
            ),
            _ActionChipButton(
              icon: Icons.calendar_view_week_rounded,
              label: 'Settimana corrente',
              onTap: () => context.push('/food/week'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        const TtSectionHeader(title: 'Sezioni'),
        const SizedBox(height: AppSpacing.md),
        _SectionLink(
          title: 'Giorni',
          subtitle: '${data.daysCount} record',
          icon: Icons.calendar_today_rounded,
          route: '/food/days',
        ),
        const SizedBox(height: AppSpacing.md),
        _SectionLink(
          title: 'Pasti',
          subtitle: '${data.mealsCount} pasti',
          icon: Icons.lunch_dining_rounded,
          route: '/food/meals',
        ),
        const SizedBox(height: AppSpacing.md),
        _SectionLink(
          title: 'Ingredienti',
          subtitle: '${data.ingredientsCount} ingredienti',
          icon: Icons.inventory_2_outlined,
          route: '/food/ingredients',
        ),
        const SizedBox(height: AppSpacing.md),
        _SectionLink(
          title: 'Ricette',
          subtitle: '${data.recipesCount} ricette',
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
    final AsyncValue<List<DailyRecordEntity>> asyncDays =
        ref.watch(dailyRecordsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settimana')),
      body: asyncDays.when(
        loading: () => const _LoadingState(),
        error: (Object error, StackTrace stackTrace) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(dailyRecordsProvider),
        ),
        data: (List<DailyRecordEntity> days) {
          final DateTime reference = days.isEmpty
              ? DateTime.now()
              : DateTime.parse(days.first.dateKey);
          final DateTime monday =
              reference.subtract(Duration(days: reference.weekday - 1));
          final DateTime sunday = monday.add(const Duration(days: 6));
          final Map<String, DailyRecordEntity> byDate =
              <String, DailyRecordEntity>{
            for (final DailyRecordEntity day in days) day.dateKey: day,
          };
          final mealRepo = ref.watch(mealRepositoryProvider);
          final List<DailyRecordEntity> present = <DailyRecordEntity>[];
          for (int index = 0; index < 7; index += 1) {
            final String key = _dateKey(monday.add(Duration(days: index)));
            final DailyRecordEntity? day = byDate[key];
            if (day != null) {
              present.add(day);
            }
          }
          final double averageCalories = present.isEmpty
              ? 0
              : present.fold<double>(
                    0,
                    (double sum, DailyRecordEntity day) =>
                        sum + _mealsKcal(mealRepo, day.dateKey),
                  ) /
                  present.length;
          final double averageSteps = present.isEmpty
              ? 0
              : present.fold<double>(
                    0,
                    (double sum, DailyRecordEntity day) => sum + day.steps,
                  ) /
                  present.length;
          return ListView(
            padding: _screenPadding,
            children: <Widget>[
              Text(
                '${_dateKey(monday)} - ${_dateKey(sunday)}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              for (int index = 0; index < 7; index += 1) ...<Widget>[
                _WeekDayCard(
                  date: monday.add(Duration(days: index)),
                  day: byDate[_dateKey(monday.add(Duration(days: index)))],
                  meals: mealRepo.getMealsWithItemsForDate(
                    _dateKey(monday.add(Duration(days: index))),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              const TtSectionHeader(title: 'Medie semplici'),
              const SizedBox(height: AppSpacing.md),
              _MetricGrid(
                metrics: <_Metric>[
                  _Metric('Calorie', _fmtKcal(averageCalories)),
                  _Metric('Passi', averageSteps.round().toString()),
                  _Metric('Giorni presenti', '${present.length}/7'),
                ],
              ),
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
    final AsyncValue<List<DailyRecordEntity>> asyncDays =
        ref.watch(dailyRecordsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Giorni')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/food/days/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuovo'),
      ),
      body: asyncDays.when(
        loading: () => const _LoadingState(),
        error: (Object error, StackTrace stackTrace) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(dailyRecordsProvider),
        ),
        data: (List<DailyRecordEntity> days) {
          if (days.isEmpty) {
            return const _EmptyState(
              title: 'Nessun giorno',
              message: 'I record giornalieri ObjectBox appariranno qui.',
            );
          }
          final mealRepo = ref.watch(mealRepositoryProvider);
          return ListView.separated(
            padding: _screenPadding,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              final DailyRecordEntity day = days[index];
              final List<MealWithItems> meals =
                  mealRepo.getMealsWithItemsForDate(day.dateKey);
              return TtAppCard(
                onTap: () => context.push('/food/days/${day.dateKey}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${_weekday(day.weekdayLabel)} ${day.dateKey}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MetricGrid(
                      metrics: <_Metric>[
                        _Metric('Calorie',
                            _fmtKcal(_mealsKcal(mealRepo, day.dateKey))),
                        _Metric('Target', _fmtNullableKcal(day.targetKcal)),
                        _Metric('Pasti', meals.length.toString()),
                        _Metric('Passi', day.steps.toString()),
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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late DailyRecordEntity _record;
  bool _loaded = false;
  bool _isSaving = false;

  final TextEditingController _date = TextEditingController();
  final TextEditingController _target = TextEditingController();
  final TextEditingController _weight = TextEditingController();
  final TextEditingController _water = TextEditingController();
  final TextEditingController _glasses = TextEditingController();
  final TextEditingController _deepSleep = TextEditingController();
  final TextEditingController _lightSleep = TextEditingController();
  final TextEditingController _sleepQuality = TextEditingController();
  final TextEditingController _steps = TextEditingController();
  final TextEditingController _stepGoal = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _date.dispose();
    _target.dispose();
    _weight.dispose();
    _water.dispose();
    _glasses.dispose();
    _deepSleep.dispose();
    _lightSleep.dispose();
    _sleepQuality.dispose();
    _steps.dispose();
    _stepGoal.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _load() {
    final repository = ref.read(dailyRecordRepositoryProvider);
    final String dateKey =
        widget.date == 'new' ? _dateKey(DateTime.now()) : widget.date;
    _record = repository.findByDate(dateKey) ?? repository.createEmpty(dateKey);
    _date.text = _record.dateKey;
    _target.text = _record.targetKcal?.toStringAsFixed(0) ?? '';
    _weight.text = _record.weightKg?.toString() ?? '';
    _water.text = _record.waterLiters?.toString() ?? '';
    _glasses.text = _record.waterGlasses?.toString() ?? '';
    _deepSleep.text = _record.sleepDeepHours?.toString() ?? '';
    _lightSleep.text = _record.sleepLightHours?.toString() ?? '';
    _sleepQuality.text = _record.sleepQualityCode;
    _steps.text = _record.steps.toString();
    _stepGoal.text = _record.stepGoal.toString();
    _notes.text = _record.notes;
    _loaded = true;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      _record.dateKey = _date.text.trim();
      _record.targetKcal = _toDouble(_target.text);
      _record.weightKg = _toDouble(_weight.text);
      _record.waterLiters = _toDouble(_water.text);
      _record.waterGlasses = _toInt(_glasses.text);
      _record.sleepDeepHours = _toDouble(_deepSleep.text);
      _record.sleepLightHours = _toDouble(_lightSleep.text);
      _record.sleepQualityCode = _sleepQuality.text.trim();
      _record.steps = _toInt(_steps.text) ?? 0;
      _record.stepGoal = _toInt(_stepGoal.text) ?? 8000;
      _record.notes = _notes.text.trim();
      ref.read(dailyRecordRepositoryProvider).save(_record);
      ref.invalidate(dailyRecordsProvider);
      ref.invalidate(foodHubDataProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Giorno salvato in ObjectBox')),
        );
        context.go('/food/days/${_record.dateKey}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: _LoadingState());
    }
    final mealRepo = ref.watch(mealRepositoryProvider);
    final List<MealWithItems> meals =
        mealRepo.getMealsWithItemsForDate(_record.dateKey);
    final double stepKcal = _record.activeKcalSteps ?? _record.steps * 0.025;
    final double workoutKcal = _record.activeKcalWorkoutCompleted ?? 0;
    final double activeEffective =
        _record.activeEffectiveKcal ?? stepKcal + workoutKcal;
    final double caloriesIn = _mealsKcal(mealRepo, _record.dateKey);
    final double? target = _toDouble(_target.text);

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.date == 'new' ? 'Nuovo giorno' : _record.dateKey)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: _screenPadding,
          children: <Widget>[
            _MetricGrid(
              metrics: <_Metric>[
                _Metric('Settimana', _record.weekCode),
                _Metric('Giorno', _weekday(_record.weekdayLabel)),
                _Metric('Calorie pasti', _fmtKcal(caloriesIn)),
                _Metric('Bilancio',
                    target == null ? 'n/d' : _fmtKcal(caloriesIn - target)),
                _Metric('Kcal passi', _fmtKcal(stepKcal)),
                _Metric('Workout completati', _fmtKcal(workoutKcal)),
                _Metric('Attive effettive', _fmtKcal(activeEffective)),
                _Metric('Pasti', meals.length.toString()),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            const TtSectionHeader(title: 'Campi base'),
            const SizedBox(height: AppSpacing.md),
            _field(_date, 'Data', isRequired: true),
            _field(_target, 'Target kcal', keyboardType: TextInputType.number),
            _field(_weight, 'Peso kg', keyboardType: TextInputType.number),
            _field(_water, 'Acqua litri', keyboardType: TextInputType.number),
            _field(_glasses, 'Bicchieri', keyboardType: TextInputType.number),
            _field(_deepSleep, 'Sonno profondo ore',
                keyboardType: TextInputType.number),
            _field(_lightSleep, 'Sonno leggero ore',
                keyboardType: TextInputType.number),
            _field(_sleepQuality, 'Qualita sonno'),
            _field(_steps, 'Passi', keyboardType: TextInputType.number),
            _field(_stepGoal, 'Obiettivo passi',
                keyboardType: TextInputType.number),
            _field(_notes, 'Note', maxLines: 4),
            const SizedBox(height: AppSpacing.md),
            TtPrimaryButton(
              label: 'Salva giorno',
              icon: Icons.check_rounded,
              isLoading: _isSaving,
              onPressed: _save,
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            const TtSectionHeader(title: 'Pasti'),
            const SizedBox(height: AppSpacing.md),
            for (final String slot in ObsidianFoodSeedConstants.mealSlots)
              _MealSlotTile(
                slot: slot,
                dateKey: _record.dateKey,
                meal: meals
                    .where(
                        (MealWithItems item) => item.meal.mealTypeCode == slot)
                    .firstOrNull,
              ),
          ],
        ),
      ),
    );
  }
}

class FoodMealsScreen extends ConsumerWidget {
  const FoodMealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MealWithItems>> asyncMeals = ref.watch(mealsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pasti')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/food/meals/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuovo'),
      ),
      body: asyncMeals.when(
        loading: () => const _LoadingState(),
        error: (Object error, StackTrace stackTrace) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(mealsProvider),
        ),
        data: (List<MealWithItems> meals) {
          if (meals.isEmpty) {
            return const _EmptyState(
              title: 'Nessun pasto',
              message: 'I pasti importati o creati saranno elencati qui.',
            );
          }
          return ListView.separated(
            padding: _screenPadding,
            itemCount: meals.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              final MealWithItems item = meals[index];
              return TtAppCard(
                onTap: () => context.push('/food/meals/${item.meal.id}'),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.meal.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${item.meal.dateKey} - ${_slotLabel(item.meal.mealTypeCode)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '${_fmtKcal(item.totals.kcal)} - '
                            'P ${_fmt(item.totals.proteinGrams)}g '
                            'C ${_fmt(item.totals.carbsGrams)}g '
                            'F ${_fmt(item.totals.fatGrams)}g',
                          ),
                        ],
                      ),
                    ),
                    if (item.isNutritionPartial)
                      const Icon(Icons.warning_amber_rounded),
                    const Icon(Icons.chevron_right_rounded),
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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late MealEntity _meal;
  List<MealItemEntity> _items = <MealItemEntity>[];
  bool _saving = false;

  final TextEditingController _date = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _mode = TextEditingController();
  final TextEditingController _freeTracking = TextEditingController();
  final TextEditingController _freeLabel = TextEditingController();
  final TextEditingController _freeNotes = TextEditingController();
  final TextEditingController _manualName = TextEditingController();
  final TextEditingController _manualKcal = TextEditingController();
  final TextEditingController _manualProtein = TextEditingController();
  final TextEditingController _manualCarbs = TextEditingController();
  final TextEditingController _manualFat = TextEditingController();
  String _slot = 'colazione';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _date.dispose();
    _title.dispose();
    _mode.dispose();
    _freeTracking.dispose();
    _freeLabel.dispose();
    _freeNotes.dispose();
    _manualName.dispose();
    _manualKcal.dispose();
    _manualProtein.dispose();
    _manualCarbs.dispose();
    _manualFat.dispose();
    super.dispose();
  }

  void _load() {
    final MealRepository repository = ref.read(mealRepositoryProvider);
    if (widget.id == 'new') {
      final String dateKey = widget.initialDate ?? _dateKey(DateTime.now());
      _slot = widget.initialSlot ?? 'colazione';
      _meal = repository.createEmpty(dateKey: dateKey, mealTypeCode: _slot);
    } else {
      final int? id = int.tryParse(widget.id);
      final MealWithItems? details = id == null
          ? repository.getMealWithItemsByUuid(widget.id)
          : repository.getMealWithItemsById(id);
      if (details == null) {
        _meal = repository.createEmpty(
          dateKey: widget.initialDate ?? _dateKey(DateTime.now()),
          mealTypeCode: widget.initialSlot ?? 'colazione',
        );
      } else {
        _meal = details.meal;
        _items = details.items;
        _slot = _meal.mealTypeCode;
      }
    }

    _date.text = _meal.dateKey;
    _title.text = _meal.title;
    _mode.text = _meal.mealModeCode;
    _freeTracking.text = _meal.freeMealTrackingCode;
    _freeLabel.text = _meal.freeMealLabel;
    _freeNotes.text = _meal.freeMealNotes;
    final MealItemEntity? manual = _items
        .where((MealItemEntity item) => item.kindCode == 'manual_estimate')
        .firstOrNull;
    if (manual != null) {
      _manualName.text = manual.itemNameSnapshot;
      _manualKcal.text = manual.kcal.toString();
      _manualProtein.text = manual.proteinGrams.toString();
      _manualCarbs.text = manual.carbsGrams.toString();
      _manualFat.text = manual.fatGrams.toString();
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      _meal.dateKey = _date.text.trim();
      _meal.title = _title.text.trim();
      _meal.mealTypeCode = _slot;
      _meal.mealModeCode =
          _mode.text.trim().isEmpty ? 'standard' : _mode.text.trim();
      _meal.freeMealTrackingCode = _freeTracking.text.trim();
      _meal.freeMealLabel = _freeLabel.text.trim();
      _meal.freeMealNotes = _freeNotes.text.trim();
      _meal.dailyRecord.target =
          ref.read(dailyRecordRepositoryProvider).findByDate(_meal.dateKey);

      final List<MealItemEntity> nextItems = List<MealItemEntity>.from(_items);
      final String manualName = _manualName.text.trim();
      if (manualName.isNotEmpty || _manualKcal.text.trim().isNotEmpty) {
        nextItems.removeWhere(
          (MealItemEntity item) => item.kindCode == 'manual_estimate',
        );
        nextItems.add(
          MealItemEntity(
            uuid: '',
            kindCode: 'manual_estimate',
            itemNameSnapshot: manualName.isEmpty ? 'Stima manuale' : manualName,
            quantityModeCode: 'portions',
            portions: 1,
            kcal: _toDouble(_manualKcal.text) ?? 0,
            proteinGrams: _toDouble(_manualProtein.text) ?? 0,
            carbsGrams: _toDouble(_manualCarbs.text) ?? 0,
            fatGrams: _toDouble(_manualFat.text) ?? 0,
            createdAtEpochMs: 0,
            updatedAtEpochMs: 0,
          ),
        );
      }
      final MealWithItems saved =
          ref.read(mealRepositoryProvider).saveMealWithItems(_meal, nextItems);
      ref.invalidate(mealsProvider);
      ref.invalidate(foodHubDataProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pasto salvato in ObjectBox')),
        );
        context.go('/food/meals/${saved.meal.id}');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final MealWithItems details = MealWithItems(meal: _meal, items: _items);
    return Scaffold(
      appBar:
          AppBar(title: Text(widget.id == 'new' ? 'Nuovo pasto' : _meal.title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: _screenPadding,
          children: <Widget>[
            _MetricGrid(
              metrics: <_Metric>[
                _Metric('Settimana', _meal.weekCode),
                _Metric('Calorie', _fmtKcal(details.totals.kcal)),
                _Metric('Proteine', '${_fmt(details.totals.proteinGrams)} g'),
                _Metric('Carboidrati', '${_fmt(details.totals.carbsGrams)} g'),
                _Metric('Grassi', '${_fmt(details.totals.fatGrams)} g'),
                _Metric('Fibre', '${_fmt(details.totals.fiberGrams)} g'),
                _Metric('Zuccheri', '${_fmt(details.totals.sugarGrams)} g'),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            const TtSectionHeader(title: 'Pasto'),
            const SizedBox(height: AppSpacing.md),
            _field(_date, 'Data', isRequired: true),
            DropdownButtonFormField<String>(
              initialValue: _slot,
              decoration: const InputDecoration(labelText: 'Slot pasto'),
              items: ObsidianFoodSeedConstants.mealSlots
                  .map((String slot) => DropdownMenuItem<String>(
                        value: slot,
                        child: Text(_slotLabel(slot)),
                      ))
                  .toList(),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _slot = value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _field(_title, 'Titolo', isRequired: true),
            _field(_mode, 'Modalita: standard/free'),
            _field(_freeTracking, 'Pasto libero: tracked/estimated/untracked'),
            _field(_freeLabel, 'Etichetta pasto libero'),
            _field(_freeNotes, 'Note pasto libero', maxLines: 3),
            const SizedBox(height: AppSpacing.sectionGap),
            const TtSectionHeader(title: 'Voci snapshot'),
            const SizedBox(height: AppSpacing.md),
            if (_items.isEmpty)
              const _EmptyInline(message: 'Nessuna voce salvata.')
            else
              for (final MealItemEntity item in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: TtAppCard(
                    child: Text(
                      '${item.itemNameSnapshot} - ${_fmtKcal(item.kcal)} '
                      '(${item.kindCode})',
                    ),
                  ),
                ),
            const SizedBox(height: AppSpacing.sectionGap),
            const TtSectionHeader(title: 'Stima manuale'),
            const SizedBox(height: AppSpacing.md),
            _field(_manualName, 'Nome voce manuale'),
            _field(_manualKcal, 'Kcal', keyboardType: TextInputType.number),
            _field(_manualProtein, 'Proteine g',
                keyboardType: TextInputType.number),
            _field(_manualCarbs, 'Carboidrati g',
                keyboardType: TextInputType.number),
            _field(_manualFat, 'Grassi g', keyboardType: TextInputType.number),
            const SizedBox(height: AppSpacing.md),
            TtPrimaryButton(
              label: 'Salva pasto',
              icon: Icons.check_rounded,
              isLoading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class PersistentIngredientListScreen extends ConsumerWidget {
  const PersistentIngredientListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<IngredientEntity>> asyncIngredients =
        ref.watch(persistentIngredientsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ingredienti')),
      body: asyncIngredients.when(
        loading: () => const _LoadingState(),
        error: (Object error, StackTrace stackTrace) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(persistentIngredientsProvider),
        ),
        data: (List<IngredientEntity> ingredients) {
          if (ingredients.isEmpty) {
            return const _EmptyState(
              title: 'Nessun ingrediente',
              message: 'La UI legge IngredientEntity, non il catalogo mock.',
            );
          }
          return ListView.separated(
            padding: _screenPadding,
            itemCount: ingredients.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              final IngredientEntity ingredient = ingredients[index];
              return TtAppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      ingredient.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      ingredient.brand.isEmpty
                          ? ingredient.sourceName
                          : ingredient.brand,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${_fmtKcal(ingredient.kcalPerReference)} / '
                      '${_fmt(ingredient.nutritionReferenceAmount)}${ingredient.baseUnit}',
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

class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<RecipeEntity>> asyncRecipes =
        ref.watch(recipesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ricette')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/food/recipes/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuova'),
      ),
      body: asyncRecipes.when(
        loading: () => const _LoadingState(),
        error: (Object error, StackTrace stackTrace) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(recipesProvider),
        ),
        data: (List<RecipeEntity> recipes) {
          if (recipes.isEmpty) {
            return const _EmptyState(
              title: 'Nessuna ricetta',
              message: 'Le ricette create o importate saranno elencate qui.',
            );
          }

          return ListView.separated(
            padding: _screenPadding,
            itemCount: recipes.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              final RecipeEntity recipe = recipes[index];
              final double? kcal =
                  recipe.kcalPerServing ?? recipe.caloriesTotal;

              return TtAppCard(
                onTap: () => context.push('/food/recipes/${recipe.id}'),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 112,
                        height: 104,
                        child: _RecipeCardImage(path: recipe.imagePath),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            recipe.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (recipe.subtitle.trim().isNotEmpty) ...<Widget>[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              recipe.subtitle.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if (recipe.summary.trim().isNotEmpty) ...<Widget>[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              recipe.summary.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            children: <Widget>[
                              if (kcal != null)
                                Text(
                                  recipe.kcalPerServing != null
                                      ? '${_fmtKcal(kcal)} / porzione'
                                      : _fmtKcal(kcal),
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              Text(
                                '${recipe.servings} porzioni',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              if (recipe.prepTimeMinutes +
                                      recipe.cookTimeMinutes >
                                  0)
                                Text(
                                  '${recipe.prepTimeMinutes + recipe.cookTimeMinutes} min',
                                  style:
                                      Theme.of(context).textTheme.labelMedium,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(Icons.chevron_right_rounded),
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

class _RecipeCardImage extends StatelessWidget {
  const _RecipeCardImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Widget fallback = ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Icon(
        Icons.restaurant_menu_rounded,
        color: colors.onSurfaceVariant,
        size: 34,
      ),
    );

    final String value = path.trim();
    if (value.isEmpty) {
      return fallback;
    }

    final Uri? uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return Image.network(
        value,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    if (value.startsWith('assets/')) {
      return Image.asset(
        value,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    final File file = File(value);
    if (!file.existsSync()) {
      return fallback;
    }

    return Image.file(
      file,
      fit: BoxFit.cover,
      cacheWidth: 480,
      errorBuilder: (_, __, ___) => fallback,
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
  late RecipeEntity _recipe;
  bool _saving = false;

  final TextEditingController _title = TextEditingController();
  final TextEditingController _summary = TextEditingController();
  final TextEditingController _servings = TextEditingController();
  final TextEditingController _prep = TextEditingController();
  final TextEditingController _cook = TextEditingController();
  final TextEditingController _difficulty = TextEditingController();
  final TextEditingController _yield = TextEditingController();
  final TextEditingController _kcal = TextEditingController();
  final TextEditingController _ingredients = TextEditingController();
  final TextEditingController _steps = TextEditingController();

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
    _yield.dispose();
    _kcal.dispose();
    _ingredients.dispose();
    _steps.dispose();
    super.dispose();
  }

  void _load() {
    final RecipeRepository repository = ref.read(recipeRepositoryProvider);
    final int? id = int.tryParse(widget.id);
    final RecipeDetails? details =
        widget.id == 'new' || id == null ? null : repository.getDetails(id);
    _recipe = details?.recipe ??
        RecipeEntity(
          uuid: '',
          title: '',
          createdAtEpochMs: 0,
          updatedAtEpochMs: 0,
        );
    _title.text = _recipe.title;
    _summary.text = _recipe.summary;
    _servings.text = _recipe.servings.toString();
    _prep.text = _recipe.prepTimeMinutes.toString();
    _cook.text = _recipe.cookTimeMinutes.toString();
    _difficulty.text = _recipe.difficultyCode;
    _yield.text = _recipe.yieldGrams?.toString() ?? '';
    _kcal.text = _recipe.kcalPerServing?.toString() ?? '';
    _ingredients.text = details == null
        ? ''
        : details.ingredients
            .map((RecipeIngredientEntity item) => item.nameSnapshot)
            .join('\n');
    _steps.text = details == null
        ? ''
        : details.steps
            .map((RecipeStepEntity step) => step.instruction)
            .join('\n');
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      _recipe.title = _title.text.trim();
      _recipe.summary = _summary.text.trim();
      _recipe.servings = _toInt(_servings.text) ?? 1;
      _recipe.prepTimeMinutes = _toInt(_prep.text) ?? 0;
      _recipe.cookTimeMinutes = _toInt(_cook.text) ?? 0;
      _recipe.difficultyCode =
          _difficulty.text.trim().isEmpty ? 'easy' : _difficulty.text.trim();
      _recipe.yieldGrams = _toDouble(_yield.text);
      _recipe.kcalPerServing = _toDouble(_kcal.text);
      final List<RecipeIngredientEntity> ingredients = _ingredients.text
          .split('\n')
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .map(
            (String value) => RecipeIngredientEntity(
              uuid: '',
              nameSnapshot: value,
              createdAtEpochMs: 0,
              updatedAtEpochMs: 0,
            ),
          )
          .toList();
      final List<RecipeStepEntity> steps = _steps.text
          .split('\n')
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .map(
            (String value) => RecipeStepEntity(
              uuid: '',
              instruction: value,
              createdAtEpochMs: 0,
              updatedAtEpochMs: 0,
            ),
          )
          .toList();
      final RecipeDetails saved = ref
          .read(recipeRepositoryProvider)
          .saveRecipeWithChildren(_recipe,
              ingredients: ingredients, steps: steps);
      ref.invalidate(recipesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ricetta salvata in ObjectBox')),
        );
        context.go('/food/recipes/${saved.recipe.id}');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.id == 'new' ? 'Nuova ricetta' : _recipe.title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: _screenPadding,
          children: <Widget>[
            _field(_title, 'Titolo', isRequired: true),
            _field(_summary, 'Descrizione', maxLines: 3),
            _field(_servings, 'Porzioni', keyboardType: TextInputType.number),
            _field(_prep, 'Tempo preparazione min',
                keyboardType: TextInputType.number),
            _field(_cook, 'Tempo cottura min',
                keyboardType: TextInputType.number),
            _field(_difficulty, 'Difficolta'),
            _field(_yield, 'Resa g', keyboardType: TextInputType.number),
            _field(_kcal, 'Kcal per porzione',
                keyboardType: TextInputType.number),
            _field(_ingredients, 'Ingredienti, uno per riga', maxLines: 6),
            _field(_steps, 'Passaggi, uno per riga', maxLines: 6),
            const SizedBox(height: AppSpacing.md),
            TtPrimaryButton(
              label: 'Salva ricetta',
              icon: Icons.check_rounded,
              isLoading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDayCard extends StatelessWidget {
  const _WeekDayCard({
    required this.date,
    required this.day,
    required this.meals,
  });

  final DateTime date;
  final DailyRecordEntity? day;
  final List<MealWithItems> meals;

  @override
  Widget build(BuildContext context) {
    final String dateKey = _dateKey(date);
    final bool hasFreeMeal =
        meals.any((MealWithItems item) => item.meal.mealModeCode == 'free');
    final bool hasPartial =
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
                child: Text(
                  '${_weekdayFromDate(date)} $dateKey',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _StatusPill(
                label: day == null ? 'Mancante' : 'Presente',
                isWarning: day == null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _MetricGrid(
            metrics: <_Metric>[
              _Metric('Calorie', day == null ? 'n/d' : _fmtKcal(kcal)),
              _Metric('Pasti', meals.length.toString()),
              _Metric('Passi', day?.steps.toString() ?? 'n/d'),
              _Metric('Peso', _fmtNullable(day?.weightKg, 'kg')),
            ],
          ),
          if (hasFreeMeal || hasPartial) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              hasPartial
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _slotLabel(slot),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    meal == null
                        ? 'Crea pasto'
                        : '${meal!.meal.title} - ${_fmtKcal(meal!.totals.kcal)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
                meal == null ? Icons.add_rounded : Icons.chevron_right_rounded),
          ],
        ),
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
          childAspectRatio: 2.1,
          children: metrics
              .map(
                (_Metric metric) => DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
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
                ),
              )
              .toList(),
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

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
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

EdgeInsets get _screenPadding {
  return const EdgeInsets.fromLTRB(
    AppSpacing.screenHorizontal,
    AppSpacing.screenVertical,
    AppSpacing.screenHorizontal,
    AppSpacing.xxxl,
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

double _mealsKcal(MealRepository mealRepository, String dateKey) {
  return mealRepository.getMealsWithItemsForDate(dateKey).fold<double>(
        0,
        (double sum, MealWithItems meal) => sum + meal.totals.kcal,
      );
}

String _dateKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _weekdayFromDate(DateTime date) {
  return const <int, String>{
    DateTime.monday: 'Lunedi',
    DateTime.tuesday: 'Martedi',
    DateTime.wednesday: 'Mercoledi',
    DateTime.thursday: 'Giovedi',
    DateTime.friday: 'Venerdi',
    DateTime.saturday: 'Sabato',
    DateTime.sunday: 'Domenica',
  }[date.weekday]!;
}

String _weekday(String value) {
  return value.isEmpty ? 'Giorno' : value;
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
