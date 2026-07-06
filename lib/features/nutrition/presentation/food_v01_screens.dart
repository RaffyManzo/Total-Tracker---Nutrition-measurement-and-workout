import 'dart:io';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/objectbox_providers.dart';
import '../../../core/diagnostics/app_diagnostics.dart';
import '../../../core/diagnostics/interaction_trace.dart';
import '../../../core/preferences/food_service_preferences.dart';
import '../../../shared/widgets/tt_app_card.dart';
import '../../../shared/widgets/tt_global_nav_fab.dart';
import '../../../shared/widgets/tt_mini_charts.dart';
import '../../../shared/widgets/tt_primary_button.dart';
import '../../../shared/widgets/tt_section_header.dart';
import '../../profile/data/entities/user_profile_entity.dart';
import '../../profile/data/repositories/user_profile_repository.dart';
import '../../profile/domain/profile_nutrition_calculator.dart';
import '../../workout/data/repositories/workout_session_repository.dart';
import '../data/entities/ingredient_entity.dart';
import '../data/entities/nutrition_tracking_entities.dart';
import '../data/import/obsidian_food_seed.dart';
import '../data/repositories/daily_record_repository.dart';
import '../data/repositories/measurement_repository.dart';
import '../data/repositories/meal_repository.dart';
import '../data/repositories/recipe_repository.dart';
import '../data/services/food_analytics_service.dart';
import '../data/services/tdee_reliability_score.dart';
import '../data/food_data_refresh_bus.dart';
import '../data/services/food_planning_service.dart';
import '../data/services/open_food_facts_service.dart';
import '../domain/adaptive_target_engine.dart';
import '../domain/meal_target_settings.dart';
import '../domain/target_model_constants.dart';
import 'measurement_screens.dart' show measurementHubProvider;
import 'meal_ingredient_batch_picker_sheet.dart';
import 'widgets/month_meal_calendar_card.dart';

final FutureProvider<FoodHubV01Data> foodHubV01Provider =
    FutureProvider<FoodHubV01Data>((Ref ref) async {
  final Stopwatch total = Stopwatch()..start();
  final Map<String, Object?> phases = <String, Object?>{};

  T phase<T>(String name, T Function() operation) {
    final Stopwatch watch = Stopwatch()..start();
    final T value = operation();
    watch.stop();
    phases[name] = watch.elapsedMilliseconds;
    return value;
  }

  try {
    final dailyRepository = ref.watch(dailyRecordRepositoryProvider);
    final mealRepository = ref.watch(mealRepositoryProvider);
    final planning = ref.watch(foodPlanningServiceProvider);
    final analytics = ref.watch(foodAnalyticsServiceProvider);
    final UserProfileEntity? profile = phase<UserProfileEntity?>(
      'profileMs',
      () => ref.watch(userProfileRepositoryProvider).getActiveProfile(),
    );
    final DateTime now = DateTime.now();
    final String todayKey = _dateKey(now);
    final FoodDayBundle todayBundle = phase<FoodDayBundle>(
      'ensureTodayMs',
      () => planning.ensureDay(todayKey),
    );
    final List<MealWithItems> todayMeals = phase<List<MealWithItems>>(
      'todayMealsMs',
      () => mealRepository.getMealsWithItemsInRange(
        fromDateKey: todayKey,
        toDateKey: todayKey,
      ),
    );
    final DailyRecordEntity latest = phase<DailyRecordEntity>(
      'todayRecordMs',
      () => dailyRepository.findByDate(todayKey) ?? todayBundle.day,
    );
    final int sourceRevision = FoodDataRefreshBus.revision;
    final int adaptiveReferenceDays = profile?.adaptiveReferenceDays ?? 28;
    final String adaptiveFromKey = _dateKey(
      now.subtract(Duration(days: adaptiveReferenceDays)),
    );
    final List<DailyRecordEntity> adaptiveDays = phase<List<DailyRecordEntity>>(
      'adaptiveHistoryMs',
      () => List<DailyRecordEntity>.from(
        dailyRepository.listBetween(adaptiveFromKey, todayKey),
      ),
    );
    if (adaptiveDays.every((DailyRecordEntity item) => item.id != latest.id)) {
      adaptiveDays.add(latest);
    }
    adaptiveDays.sort(
      (DailyRecordEntity a, DailyRecordEntity b) =>
          b.dateKey.compareTo(a.dateKey),
    );
    final TargetDayResult latestTargetResult = phase<TargetDayResult>(
      'dailyTargetResultMs',
      () => analytics.targetResultForDay(
        day: latest,
        allDays: adaptiveDays,
        profile: profile,
        now: now,
      ),
    );
    final DateTime normalizedToday = DateTime(now.year, now.month, now.day);
    final WeekAdaptiveSummary adaptiveSummary = WeekAdaptiveSummary(
      monday: normalizedToday,
      sunday: normalizedToday,
      targetKcal: latestTargetResult.targetKcal,
      targetStatusCode: latestTargetResult.targetStatusCode,
      tdeeRefKcal: latestTargetResult.tdeeRefKcal,
      tdeeTheoreticalKcal: latestTargetResult.tdeeTheoreticalKcal,
      tdeeObservedKcal: latestTargetResult.tdeeObservedKcal,
      observedConfidence: latestTargetResult.observedConfidence,
      referenceDaysCount: latestTargetResult.referenceDaysCount,
      validIntakeDays: latestTargetResult.validIntakeDays,
      validWeightDays: latestTargetResult.validWeightDays,
      rmrKcal: latestTargetResult.rmrKcal,
      weightRefKg: latestTargetResult.weightRefKg,
      weightStatusCode: latestTargetResult.weightStatusCode,
      weightDaysSinceMeasurement: latestTargetResult.weightDaysSinceMeasurement,
      weightTrendEnabled: latestTargetResult.validWeightDays >= 4,
      activeRefKcal: latestTargetResult.activeRefKcal,
      activeRefSourceCode: 'daily_target_result',
      currentWeekActiveKcal: latestTargetResult.activity.totalKcal,
      activityStatusCode: latestTargetResult.activity.statusCode,
      activityDeltaKcal: latestTargetResult.activityDeltaKcal,
      deltaWeightKg: latestTargetResult.deltaWeightKg,
      avgCalories: latestTargetResult.avgCalories,
      kcalPerKg: latestTargetResult.kcalPerKg,
      alerts: latestTargetResult.alerts,
    );
    total.stop();
    unawaited(
      AppDiagnostics.instance.info(
        'dashboard.today_load.breakdown',
        data: <String, Object?>{
          ...phases,
          'totalMs': total.elapsedMilliseconds,
          'mealCount': todayMeals.length,
          'dateKey': todayKey,
        },
      ),
    );
    return FoodHubV01Data(
      latest: latest,
      latestMeals: todayMeals,
      allMeals: todayMeals,
      days: adaptiveDays,
      ingredients: const <IngredientEntity>[],
      recipes: const <RecipeEntity>[],
      scaleMeasurements: const <ScaleMeasurementEntity>[],
      tapeMeasurements: const <TapeMeasurementEntity>[],
      analytics: analytics,
      adaptiveSummary: adaptiveSummary,
      latestTargetResult: latestTargetResult,
      profile: profile,
      sourceRevision: sourceRevision,
    );
  } catch (error, stackTrace) {
    total.stop();
    await AppDiagnostics.instance.error(
      'dashboard.today_load.failed',
      error: error,
      stackTrace: stackTrace,
      data: <String, Object?>{
        ...phases,
        'totalMs': total.elapsedMilliseconds,
      },
    );
    rethrow;
  }
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
  return ref
      .watch(ingredientRepositoryProvider)
      .getAllActive()
      .take(25)
      .toList();
});

final FutureProvider<List<RecipeEntity>> recipeArchiveProvider =
    FutureProvider<List<RecipeEntity>>((Ref ref) async {
  return ref.watch(recipeRepositoryProvider).getAllActive();
});

class FoodHubV01Data {
  const FoodHubV01Data({
    required this.latest,
    required this.latestMeals,
    required this.allMeals,
    required this.days,
    required this.ingredients,
    required this.recipes,
    required this.scaleMeasurements,
    required this.tapeMeasurements,
    required this.analytics,
    required this.adaptiveSummary,
    this.latestTargetResult,
    required this.profile,
    required this.sourceRevision,
  });

  final DailyRecordEntity? latest;
  final List<MealWithItems> latestMeals;
  final List<MealWithItems> allMeals;
  final List<DailyRecordEntity> days;
  final List<IngredientEntity> ingredients;
  final List<RecipeEntity> recipes;
  final List<ScaleMeasurementEntity> scaleMeasurements;
  final List<TapeMeasurementEntity> tapeMeasurements;
  final FoodAnalyticsService analytics;
  final WeekAdaptiveSummary adaptiveSummary;
  final TargetDayResult? latestTargetResult;
  final UserProfileEntity? profile;
  final int sourceRevision;

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

  List<TtChartPoint> get recentCalorieTargets {
    final List<DailyRecordEntity> recent =
        days.take(7).toList().reversed.toList();
    return <TtChartPoint>[
      for (final DailyRecordEntity day in recent)
        TtChartPoint(
          label: day.dateKey.substring(5),
          value: analytics.targetForDay(
            day: day,
            allDays: days,
            profile: profile,
          ),
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

  List<TtChartPoint> get recentStepTargets {
    final List<DailyRecordEntity> recent =
        days.take(7).toList().reversed.toList();
    return <TtChartPoint>[
      for (final DailyRecordEntity day in recent)
        TtChartPoint(
          label: day.dateKey.substring(5),
          value: day.stepGoal.toDouble(),
        ),
    ];
  }
}

class FoodHubScreen extends ConsumerStatefulWidget {
  const FoodHubScreen({super.key});

  @override
  ConsumerState<FoodHubScreen> createState() => _FoodHubScreenState();
}

class _FoodHubScreenState extends ConsumerState<FoodHubScreen>
    with WidgetsBindingObserver {
  FoodHubV01Data? _cachedData;
  DateTime? _backgroundedAt;
  StreamSubscription<FoodDataChange>? _changeSubscription;
  FoodDataChange? _pendingChange;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _changeSubscription = FoodDataRefreshBus.changes.listen(_onFoodDataChange);
    final FoodDataChange? lastChange = FoodDataRefreshBus.lastChange;
    if (lastChange != null && lastChange.dateKey == _dateKey(DateTime.now())) {
      _pendingChange = lastChange;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.invalidate(foodHubV01Provider);
      });
    }
    unawaited(AppDiagnostics.instance.info('dashboard.screen_opened'));
  }

  @override
  void dispose() {
    _changeSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onFoodDataChange(FoodDataChange change) {
    if (!mounted) return;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime? changed = DateTime.tryParse(change.dateKey);
    final int referenceDays = _cachedData?.profile?.adaptiveReferenceDays ?? 28;
    final DateTime earliest = today.subtract(Duration(days: referenceDays + 1));
    final String? visibleDate = _cachedData?.latest?.dateKey;
    final bool affectsVisibleDay = change.dateKey == visibleDate;
    final bool affectsAdaptiveWindow = changed != null &&
        !changed.isAfter(today) &&
        !changed.isBefore(earliest);
    if (!affectsVisibleDay && !affectsAdaptiveWindow) return;
    setState(() => _pendingChange = change);
    ref.invalidate(foodHubV01Provider);
  }

  Future<void> _refreshDashboard() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final String todayKey = _dateKey(DateTime.now());
    FoodDataRefreshBus.publishManualRefresh(todayKey);
    ref.invalidate(foodHubV01Provider);
    try {
      final FoodHubV01Data fresh = await ref.read(foodHubV01Provider.future);
      _cachedData = fresh;
      if (!mounted) return;
      setState(() => _pendingChange = null);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  bool _isCacheStale(FoodHubV01Data data) {
    final FoodDataChange? change = _pendingChange;
    return change != null && data.sourceRevision < change.revision;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _backgroundedAt = DateTime.now();
      unawaited(AppDiagnostics.instance.info('lifecycle.background'));
      return;
    }
    if (state == AppLifecycleState.resumed) {
      final DateTime now = DateTime.now();
      unawaited(
        AppDiagnostics.instance.info(
          'lifecycle.resume',
          data: <String, Object?>{
            if (_backgroundedAt != null)
              'backgroundMs': now.difference(_backgroundedAt!).inMilliseconds,
            'hasTodayCache': _cachedData != null,
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<FoodHubV01Data> state = ref.watch(foodHubV01Provider);
    final FoodHubV01Data? fresh = state.asData?.value;
    if (fresh != null) {
      _cachedData = fresh;
      final FoodDataChange? pending = _pendingChange;
      if (pending != null && !_isCacheStale(fresh)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && identical(_pendingChange, pending)) {
            setState(() => _pendingChange = null);
          }
        });
      }
    }
    final FoodHubV01Data? visible = fresh ?? _cachedData;

    final Widget body;
    if (visible != null) {
      body = Stack(
        children: <Widget>[
          _FoodHubV01Body(
            data: visible,
            cacheStale: _isCacheStale(visible),
            refreshing: _refreshing || state.isLoading,
            onRefresh: _refreshDashboard,
          ),
          if (state.isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      );
    } else {
      body = state.when(
        loading: () => const _DashboardLoadingState(),
        error: (Object error, StackTrace stackTrace) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(foodHubV01Provider),
        ),
        data: (FoodHubV01Data data) => _FoodHubV01Body(
          data: data,
          cacheStale: false,
          refreshing: _refreshing,
          onRefresh: _refreshDashboard,
        ),
      );
    }

    return Scaffold(
      bottomNavigationBar: const TtFoodBottomNavBar(),
      body: body,
    );
  }
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    Widget skeleton({double height = 72}) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(20),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: _screenPadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Caricamento della giornata di oggi…',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              skeleton(height: 170),
              const SizedBox(height: AppSpacing.md),
              skeleton(),
              const SizedBox(height: AppSpacing.md),
              skeleton(height: 130),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodHubV01Body extends StatelessWidget {
  const _FoodHubV01Body({
    required this.data,
    required this.cacheStale,
    required this.refreshing,
    required this.onRefresh,
  });

  final FoodHubV01Data data;
  final bool cacheStale;
  final bool refreshing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final String profileName = data.profile?.displayName.trim() ?? '';
    final String dashboardTitle =
        profileName.isEmpty ? 'Dashboard' : 'Dashboard di $profileName';
    final DailyRecordEntity? latest = data.latest;
    final MealNutritionTotals totals = data.latestTotals;
    final TargetDayResult? latestTargetResult =
        latest == null ? null : data.latestTargetResult;
    final double latestTarget =
        latestTargetResult?.targetKcal ?? data.adaptiveSummary.targetKcal;
    final ProfileNutritionTargets macroTargets = latest == null
        ? const ProfileNutritionCalculator().calculateFixedTargets(
            data.profile ??
                UserProfileEntity(
                  uuid: 'fallback',
                  createdAtEpochMs: 0,
                  updatedAtEpochMs: 0,
                ),
          )
        : data.analytics.macroTargetsForDay(
            day: latest,
            profile: data.profile,
          );
    final ActivityBreakdown? latestActivity = latest == null
        ? null
        : data.analytics.activityForDay(latest, profile: data.profile);
    final double? latestWeight =
        latest == null ? null : data.analytics.weightForDay(latest);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _screenPadding,
        children: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text(
            dashboardTitle,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          if (cacheStale) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _DashboardRefreshBanner(refreshing: refreshing),
          ],
          const SizedBox(height: AppSpacing.sectionGap),
          _DashboardDailySummary(
            day: latest,
            meals: data.latestMeals,
            totals: totals,
            targetKcal: latestTarget,
            macroTargets: macroTargets,
            onTap: latest == null || latestActivity == null
                ? null
                : () => _showDayStatsSheet(
                      context: context,
                      day: latest,
                      caloriesIn: totals.kcal,
                      target: latestTarget,
                      balance: totals.kcal - latestTarget,
                      activity: latestActivity,
                      weight: latestWeight,
                      onOpenDay: () =>
                          context.push('/food/days/${latest.dateKey}'),
                    ),
            onMealTap: (MealWithItems meal) {
              context.push('/food/meals/${meal.meal.id}');
            },
          ),
          if (latestTargetResult != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _TdeeReliabilityCard(result: latestTargetResult),
          ],
          if (latestTargetResult != null &&
              latestTargetResult.alerts.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            for (final TargetAlert alert in latestTargetResult.alerts)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _TargetAlertCard(alert: alert),
              ),
          ],
          if (data.hasPartialNutrition) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const TtAppCard(
              child: Text(
                'C e almeno un pasto libero non tracciato: il riepilogo '
                'odierno usa soltanto i dati disponibili.',
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sectionGap),
          TtAppCard(
            onTap: () {
              InteractionTrace.event('dashboard.weekly_hub_card_opened');
              context.push('/food/week');
            },
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.calendar_view_week_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Riepilogo della settimana',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Statistiche, giorni e pasti con navigazione settimanale.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const MonthMealCalendarCard(),
          const SizedBox(height: AppSpacing.md),
          TtAppCard(
            onTap: () => context.push('/food/ingredients'),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.search_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Ricerca alimenti',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Ingredienti locali, Open Food Facts e OpenNutrition.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TtAppCard(
            onTap: () => context.push('/food/insights'),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.insights_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Insight generale',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Grafici, trend e statistiche sugli alimenti in una '
                        'pagina dedicata.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.open_in_new_rounded),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _DashboardRefreshBanner extends StatelessWidget {
  const _DashboardRefreshBanner({required this.refreshing});

  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            if (refreshing)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.sync_rounded, color: colors.onSecondaryContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                refreshing
                    ? 'Aggiornamento della dashboard in corso.'
                    : 'Sono disponibili dati aggiornati. Trascina verso il '
                        'basso per sincronizzare la dashboard.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSecondaryContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardDailySummary extends StatelessWidget {
  const _DashboardDailySummary({
    required this.day,
    required this.meals,
    required this.totals,
    required this.targetKcal,
    required this.macroTargets,
    required this.onTap,
    this.onMealTap,
  });

  final DailyRecordEntity? day;
  final List<MealWithItems> meals;
  final MealNutritionTotals totals;
  final double targetKcal;
  final ProfileNutritionTargets macroTargets;
  final VoidCallback? onTap;
  final ValueChanged<MealWithItems>? onMealTap;

  @override
  Widget build(BuildContext context) {
    final int mealsWithFood =
        meals.where((MealWithItems meal) => meal.items.isNotEmpty).length;
    final double calorieTarget = targetKcal <= 0 ? 1 : targetKcal;
    final double calorieProgress =
        (totals.kcal / calorieTarget).clamp(0, 1).toDouble();
    final int steps = day?.steps ?? 0;
    final int rawStepGoal = day?.stepGoal ?? 8000;
    final int stepGoal = rawStepGoal <= 0 ? 8000 : rawStepGoal;
    final double stepProgress = (steps / stepGoal).clamp(0, 1).toDouble();
    final int glasses = day?.waterLiters == null
        ? (day?.waterGlasses ?? 0)
        : (day!.waterLiters! / 0.2).round();
    final double sleepHours =
        (day?.sleepDeepHours ?? 0) + (day?.sleepLightHours ?? 0);
    final bool isToday = day?.dateKey == _dateKey(DateTime.now());
    final Map<String, MealWithItems> mealsBySlot = <String, MealWithItems>{
      for (final MealWithItems meal in meals) meal.meal.mealTypeCode: meal,
    };
    return TtAppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Riepilogo giornaliero',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      day == null
                          ? 'Oggi'
                          : '${day!.weekdayLabel} ${day!.dateKey}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (day != null && isToday) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Hero(
                  tag: 'today-tag-${day!.dateKey}',
                  child: const _StatusPill(
                    label: 'Today',
                    isWarning: false,
                  ),
                ),
              ],
              _StatusPill(
                label: '$mealsWithFood/4 pasti',
                isWarning: mealsWithFood == 0,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              SizedBox.square(
                dimension: 118,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    SizedBox.square(
                      dimension: 104,
                      child: CircularProgressIndicator(
                        value: calorieProgress,
                        strokeWidth: 10,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text('🔥'),
                        Text(
                          totals.kcal.round().toString(),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '/ ${targetKcal.round()} kcal',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  children: <Widget>[
                    _MacroProgressLine(
                      label: '🥩 Proteine',
                      value: totals.proteinGrams,
                      target: macroTargets.proteinGrams,
                    ),
                    _MacroProgressLine(
                      label: '🍚 Carbo',
                      value: totals.carbsGrams,
                      target: macroTargets.carbsGrams,
                    ),
                    _MacroProgressLine(
                      label: '🥑 Grassi',
                      value: totals.fatGrams,
                      target: macroTargets.fatGrams,
                    ),
                    _MacroProgressLine(
                      label: 'Fibre',
                      value: totals.fiberGrams,
                      target: macroTargets.fiberGrams,
                    ),
                    _MacroProgressLine(
                      label: 'Zuccheri totali · nessun limite automatico',
                      value: totals.sugarGrams,
                      target: null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _SummaryDivider(),
          const SizedBox(height: AppSpacing.md),
          _WalkingProgressBar(
            value: stepProgress,
            label: '🚶 $steps / $stepGoal passi',
          ),
          const SizedBox(height: AppSpacing.md),
          const _SummaryDivider(),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '💧 ${_waterGlassesText(glasses)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Expanded(
                child: Text(
                  '😴 ${sleepHours <= 0 ? 'n/d' : '${_fmt(sleepHours)} h'}',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _SummaryDivider(),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              for (final String slot in ObsidianFoodSeedConstants.mealSlots)
                Expanded(
                  child: _MealCompletionCell(
                    emoji: _slotEmoji(slot),
                    label: _slotLabel(slot),
                    selected: mealsBySlot[slot]?.items.isNotEmpty ?? false,
                    onTap: mealsBySlot[slot] == null || onMealTap == null
                        ? null
                        : () => onMealTap!(mealsBySlot[slot]!),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalkingProgressBar extends StatelessWidget {
  const _WalkingProgressBar({
    required this.value,
    required this.label,
  });

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double clamped = value.clamp(0, 1).toDouble();
            final double markerX = (constraints.maxWidth - 24) * clamped;
            return SizedBox(
              height: 28,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: clamped,
                      minHeight: 10,
                    ),
                  ),
                  Positioned(
                    left: markerX,
                    child: const Text('🚶', style: TextStyle(fontSize: 22)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MealCompletionCell extends StatelessWidget {
  const _MealCompletionCell({
    required this.emoji,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color background = selected
        ? colors.primaryContainer.withValues(alpha: 0.72)
        : colors.surfaceContainerHighest.withValues(alpha: 0.6);
    final Color foreground =
        selected ? colors.onPrimaryContainer : colors.onSurfaceVariant;
    return Semantics(
      button: onTap != null,
      label: '$label, ${selected ? 'registrato' : 'vuoto'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(emoji, style: const TextStyle(fontSize: 23)),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: selected ? colors.primary : colors.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _waterGlassesText(int glasses) {
  if (glasses <= 0) {
    return 'n/d';
  }
  final int capped = glasses.clamp(0, 8);
  return '${List<String>.filled(capped, '🥛').join()} ${(glasses * 0.2).toStringAsFixed(1)} L';
}

class _FoodWeekLoadRequest {
  const _FoodWeekLoadRequest({required this.mondayKey});

  final String mondayKey;
}

_FoodWeekSnapshot _loadFoodWeekInBackground(
  Store store,
  _FoodWeekLoadRequest request,
) {
  final Map<String, int> phases = <String, int>{};

  T measure<T>(String name, T Function() operation) {
    final Stopwatch watch = Stopwatch();
    watch.start();
    final T value = operation();
    watch.stop();
    phases[name] = watch.elapsedMilliseconds;
    return value;
  }

  final DateTime monday = DateTime.parse(request.mondayKey);
  final DateTime sunday = monday.add(const Duration(days: 6));
  final DailyRecordRepository dailyRepository = DailyRecordRepository(store);
  final MealRepository mealRepository = MealRepository(store);
  final FoodPlanningService planning = FoodPlanningService(
    dailyRecords: dailyRepository,
    meals: mealRepository,
    recipes: RecipeRepository(store),
  );
  final UserProfileEntity? profile =
      UserProfileRepository(store).getActiveProfile();
  final FoodAnalyticsService analytics = FoodAnalyticsService(
    meals: mealRepository,
    measurements: MeasurementRepository(store),
    workoutSessions: WorkoutSessionRepository(store),
    diagnosticsEnabled: false,
  );

  measure<void>('ensureDaysMs', () {
    for (int index = 0; index < 7; index += 1) {
      planning.ensureDay(_dateKey(monday.add(Duration(days: index))));
    }
  });

  final int referenceDays = profile?.adaptiveReferenceDays ?? 28;
  final DateTime historyStart = monday.subtract(Duration(days: referenceDays));
  final List<DailyRecordEntity> history = measure<List<DailyRecordEntity>>(
    'historyQueryMs',
    () => dailyRepository.listBetween(
      _dateKey(historyStart),
      _dateKey(sunday),
    ),
  );
  final List<MealWithItems> meals = measure<List<MealWithItems>>(
    'mealQueryMs',
    () => mealRepository.getMealsWithItemsInRange(
      fromDateKey: _dateKey(monday),
      toDateKey: _dateKey(sunday),
    ),
  );

  final Map<String, DailyRecordEntity> daysByDate = <String, DailyRecordEntity>{
    for (final DailyRecordEntity day in history) day.dateKey: day,
  };
  final Map<String, List<MealWithItems>> mealsByDate =
      <String, List<MealWithItems>>{};
  for (final MealWithItems meal in meals) {
    mealsByDate
        .putIfAbsent(meal.meal.dateKey, () => <MealWithItems>[])
        .add(meal);
  }

  final Stopwatch targetWatch = Stopwatch();
  targetWatch.start();
  final DateTime todayValue = DateTime.now();
  final DateTime today = DateTime(
    todayValue.year,
    todayValue.month,
    todayValue.day,
  );
  final DailyRecordEntity? anchorDay = daysByDate[_dateKey(today)] ??
      daysByDate[_dateKey(monday)] ??
      (history.isEmpty ? null : history.first);
  final TargetDayResult? liveTarget = anchorDay == null
      ? null
      : analytics.targetResultForDay(
          day: anchorDay,
          allDays: history,
          profile: profile,
        );
  final double liveReliability = liveTarget == null
      ? 0
      : TdeeReliabilityScore.fromTarget(liveTarget).total;
  int snapshotTargetDays = 0;
  int derivedTargetDays = 0;
  final List<_FoodWeekDaySnapshot> days = <_FoodWeekDaySnapshot>[];
  for (int index = 0; index < 7; index += 1) {
    final DateTime date = monday.add(Duration(days: index));
    final String dateKey = _dateKey(date);
    final DailyRecordEntity? day = daysByDate[dateKey];
    if (day == null) continue;
    final bool hasPersistedTarget =
        day.targetKcal != null && day.targetKcal! > 0;
    final double targetKcal;
    if (hasPersistedTarget) {
      targetKcal = day.targetKcal!;
      snapshotTargetDays += 1;
    } else {
      targetKcal = liveTarget?.targetKcal ?? 2000;
      derivedTargetDays += 1;
    }
    final List<MealWithItems> dayMeals =
        mealsByDate[dateKey] ?? const <MealWithItems>[];
    final double calories = dayMeals.fold<double>(
      0,
      (double sum, MealWithItems meal) => sum + meal.totals.kcal,
    );
    days.add(
      _FoodWeekDaySnapshot(
        date: date,
        dateKey: dateKey,
        weekdayLabel: day.weekdayLabel,
        steps: day.steps,
        stepGoal: day.stepGoal,
        calories: calories,
        targetKcal: targetKcal,
        reliabilityTotal: liveReliability,
        meals: <_FoodWeekMealSnapshot>[
          for (final MealWithItems meal in dayMeals)
            _FoodWeekMealSnapshot(
              id: meal.meal.id,
              slotCode: meal.meal.mealTypeCode,
              calories: meal.totals.kcal,
              itemCount: meal.items.length,
              isFreeMeal: meal.meal.mealModeCode == 'free' ||
                  meal.meal.freeMealTrackingCode.isNotEmpty,
              freeTrackingCode: meal.meal.freeMealTrackingCode,
            ),
        ],
      ),
    );
  }
  targetWatch.stop();
  phases['dailyTargetsMs'] = targetWatch.elapsedMilliseconds;
  phases['liveTargetCalculations'] = liveTarget == null ? 0 : 1;
  phases['snapshotTargetDays'] = snapshotTargetDays;
  phases['derivedTargetDays'] = derivedTargetDays;

  return _FoodWeekSnapshot(
    monday: monday,
    sunday: sunday,
    days: List<_FoodWeekDaySnapshot>.unmodifiable(days),
    phaseTimings: Map<String, int>.unmodifiable(phases),
  );
}

class _TdeeReliabilityCard extends StatelessWidget {
  const _TdeeReliabilityCard({required this.result});

  final TargetDayResult result;

  @override
  Widget build(BuildContext context) {
    final TdeeReliabilityScore score = TdeeReliabilityScore.fromTarget(result);
    final ColorScheme colors = Theme.of(context).colorScheme;
    return TtAppCard(
      onTap: () => _showDetails(context, score),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.verified_user_outlined, color: colors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Affidabilità TDEE osservato',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${score.total.round()}/100',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: score.total / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${score.bandLabel} · punteggio basato su copertura, peso, '
            'alimentazione e qualità dei dati di attività.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _showDetails(
    BuildContext context,
    TdeeReliabilityScore score,
  ) async {
    InteractionTrace.event(
      'tdee_reliability.details_opened',
      data: <String, Object?>{
        'score': score.total.round(),
        'band': score.bandCode,
        'targetStatus': result.targetStatusCode,
      },
    );
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Affidabilità TDEE osservato',
                  style: Theme.of(sheetContext).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${score.total.round()}/100 · ${score.bandLabel}',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Indice ingegneristico di qualità delle evidenze. È distinto '
                  'dalla confidenza matematica usata per fondere TDEE teorico '
                  'e osservato e non rappresenta una misura clinica.',
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final TdeeReliabilityComponent component
                    in score.components) ...<Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          component.label,
                          style: Theme.of(sheetContext).textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        '${component.earnedPoints.round()}/'
                        '${component.maximumPoints.round()}',
                        style: Theme.of(sheetContext).textTheme.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  LinearProgressIndicator(
                    value: component.maximumPoints <= 0
                        ? 0
                        : component.earnedPoints / component.maximumPoints,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    component.explanation,
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class FoodWeekScreen extends ConsumerStatefulWidget {
  const FoodWeekScreen({super.key});

  @override
  ConsumerState<FoodWeekScreen> createState() => _FoodWeekScreenState();
}

class _FoodWeekScreenState extends ConsumerState<FoodWeekScreen> {
  late DateTime _monday;
  late Future<_FoodWeekSnapshot> _future;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _monday = _startOfWeek(DateTime.now());
    _future = _loadWeek(_monday);
    InteractionTrace.event(
      'weekly_hub.screen_opened',
      data: <String, Object?>{'weekStart': _dateKey(_monday)},
    );
  }

  DateTime _startOfWeek(DateTime date) {
    final DateTime normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  void _changeWeek(int delta, {required String source}) {
    final DateTime next = _monday.add(Duration(days: 7 * delta));
    InteractionTrace.event(
      'weekly_hub.navigation_requested',
      data: <String, Object?>{
        'source': source,
        'direction': delta < 0 ? 'previous' : 'next',
        'fromWeek': _dateKey(_monday),
        'toWeek': _dateKey(next),
      },
    );
    setState(() {
      _monday = next;
      _future = _loadWeek(next);
    });
  }

  Future<_FoodWeekSnapshot> _loadWeek(DateTime monday) async {
    final int generation = ++_requestGeneration;
    final InteractionTraceSpan trace = InteractionTrace.start(
      'weekly_hub.load',
      data: <String, Object?>{
        'weekStart': _dateKey(monday),
        'generation': generation,
      },
    );
    try {
      final Store store = ref.read(objectBoxStoreProvider);
      final _FoodWeekSnapshot snapshot =
          await store.runAsync<_FoodWeekLoadRequest, _FoodWeekSnapshot>(
        _loadFoodWeekInBackground,
        _FoodWeekLoadRequest(mondayKey: _dateKey(monday)),
      );
      if (generation != _requestGeneration) {
        InteractionTrace.event(
          'weekly_hub.load_superseded',
          data: <String, Object?>{
            'weekStart': _dateKey(monday),
            'generation': generation,
            'latestGeneration': _requestGeneration,
          },
        );
      }
      trace.complete(
        data: <String, Object?>{
          ...snapshot.phaseTimings,
          'dayCount': snapshot.days.length,
          'mealCount': snapshot.totalMeals,
          'averageReliability': snapshot.averageReliability.round(),
          'workerIsolate': true,
        },
      );
      return snapshot;
    } catch (error, stackTrace) {
      trace.fail(error, stackTrace);
      rethrow;
    }
  }

  void _handleSwipe(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 250) return;
    _changeWeek(velocity > 0 ? -1 : 1, source: 'swipe');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riepilogo settimanale')),
      bottomNavigationBar:
          const TtFoodBottomNavBar(activeItem: TtFoodNavItem.none),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: _handleSwipe,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Row(
                children: <Widget>[
                  IconButton.filledTonal(
                    tooltip: 'Settimana precedente',
                    onPressed: () => _changeWeek(-1, source: 'arrow'),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        Text(
                          '${_dateKey(_monday)} – '
                          '${_dateKey(_monday.add(const Duration(days: 6)))}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Scorri lateralmente oppure usa le frecce',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Settimana successiva',
                    onPressed: () => _changeWeek(1, source: 'arrow'),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<_FoodWeekSnapshot>(
                future: _future,
                builder: (
                  BuildContext context,
                  AsyncSnapshot<_FoodWeekSnapshot> state,
                ) {
                  if (state.connectionState != ConnectionState.done) {
                    return const _WeekHubLoadingState();
                  }
                  if (state.hasError || !state.hasData) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.error_outline_rounded, size: 42),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Caricamento della settimana non riuscito: '
                              '${state.error}',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            FilledButton.icon(
                              onPressed: () {
                                setState(() => _future = _loadWeek(_monday));
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Riprova'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return _WeekHubContent(snapshot: state.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekHubLoadingState extends StatelessWidget {
  const _WeekHubLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(),
          SizedBox(height: AppSpacing.md),
          Text('Caricamento completo della settimana…'),
        ],
      ),
    );
  }
}

class _WeekHubContent extends StatelessWidget {
  const _WeekHubContent({required this.snapshot});

  final _FoodWeekSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final List<TtChartPoint> caloriePoints = <TtChartPoint>[
      for (final _FoodWeekDaySnapshot item in snapshot.days)
        TtChartPoint(
          label: _shortWeekdayLabel(item.date),
          value: item.calories,
        ),
    ];
    final List<TtChartPoint> calorieTargets = <TtChartPoint>[
      for (final _FoodWeekDaySnapshot item in snapshot.days)
        TtChartPoint(
          label: _shortWeekdayLabel(item.date),
          value: item.targetKcal,
        ),
    ];
    final List<TtChartPoint> stepPoints = <TtChartPoint>[
      for (final _FoodWeekDaySnapshot item in snapshot.days)
        TtChartPoint(
          label: _shortWeekdayLabel(item.date),
          value: item.steps.toDouble(),
        ),
    ];
    final List<TtChartPoint> stepTargets = <TtChartPoint>[
      for (final _FoodWeekDaySnapshot item in snapshot.days)
        TtChartPoint(
          label: _shortWeekdayLabel(item.date),
          value: item.stepGoal.toDouble(),
        ),
    ];

    return ListView(
      key: ValueKey<String>(_dateKey(snapshot.monday)),
      padding: _screenPadding,
      children: <Widget>[
        TtAppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Statistiche della settimana',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              _MetricGrid(
                metrics: <_Metric>[
                  _Metric('Calorie assunte', _fmtKcal(snapshot.totalCalories)),
                  _Metric('Target medio', _fmtKcal(snapshot.averageTarget)),
                  _Metric('Passi', snapshot.totalSteps.toString()),
                  _Metric('Pasti', snapshot.totalMeals.toString()),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  const Icon(Icons.verified_user_outlined),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Affidabilità media TDEE: '
                      '${snapshot.averageReliability.round()}/100',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _ChartCard(
          title: 'Calorie',
          subtitle: 'Assunte e target giornaliero',
          child: TtMiniBarChart(
            points: caloriePoints,
            targetPoints: calorieTargets,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _ChartCard(
          title: 'Passi',
          subtitle: 'Passi registrati e obiettivo',
          child: TtMiniBarChart(
            points: stepPoints,
            targetPoints: stepTargets,
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        Text('Giorni e pasti', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        for (final _FoodWeekDaySnapshot item in snapshot.days) ...<Widget>[
          _WeekHubDayCard(item: item),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _WeekHubDayCard extends StatelessWidget {
  const _WeekHubDayCard({required this.item});

  final _FoodWeekDaySnapshot item;

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${item.weekdayLabel} ${item.dateKey}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${item.reliabilityTotal.round()}/100',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                tooltip: 'Apri giornata',
                onPressed: () => context.push('/food/days/${item.dateKey}'),
                icon: const Icon(Icons.open_in_new_rounded),
              ),
            ],
          ),
          Text(
            '${item.calories.round()} / ${item.targetKcal.round()} kcal'
            ' · ${item.steps}/${item.stepGoal} passi',
          ),
          const SizedBox(height: AppSpacing.md),
          for (final _FoodWeekMealSnapshot meal in item.meals) ...<Widget>[
            _WeekHubMealRow(meal: meal),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _WeekHubMealRow extends StatelessWidget {
  const _WeekHubMealRow({required this.meal});

  final _FoodWeekMealSnapshot meal;

  String get _statusLabel {
    if (!meal.isFreeMeal) {
      return meal.itemCount == 0 ? 'Vuoto' : 'Standard';
    }
    return switch (meal.normalizedFreeTrackingCode) {
      'untracked' => 'Libero · non tracciato',
      'estimated' => 'Libero · stimato',
      _ => 'Libero · tracciato',
    };
  }

  String get _calorieLabel {
    if (meal.isFreeMeal && meal.normalizedFreeTrackingCode == 'untracked') {
      return 'Parziale';
    }
    if (meal.itemCount == 0) return '—';
    return '${meal.calories.round()} kcal';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool warning = meal.isFreeMeal || meal.itemCount == 0;
    return Material(
      color: warning
          ? colors.tertiaryContainer.withValues(alpha: 0.42)
          : colors.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/food/meals/${meal.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                flex: 5,
                child: Text(
                  _slotLabel(meal.slotCode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  _calorieLabel,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 5,
                child: Text(
                  _statusLabel,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: warning
                            ? colors.onTertiaryContainer
                            : colors.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodWeekSnapshot {
  const _FoodWeekSnapshot({
    required this.monday,
    required this.sunday,
    required this.days,
    required this.phaseTimings,
  });

  final DateTime monday;
  final DateTime sunday;
  final List<_FoodWeekDaySnapshot> days;
  final Map<String, int> phaseTimings;

  double get totalCalories => days.fold<double>(
        0,
        (double sum, _FoodWeekDaySnapshot item) => sum + item.calories,
      );
  int get totalSteps => days.fold<int>(
        0,
        (int sum, _FoodWeekDaySnapshot item) => sum + item.steps,
      );
  int get totalMeals => days.fold<int>(
        0,
        (int sum, _FoodWeekDaySnapshot item) => sum + item.meals.length,
      );
  double get averageTarget => days.isEmpty
      ? 0
      : days.fold<double>(
            0,
            (double sum, _FoodWeekDaySnapshot item) => sum + item.targetKcal,
          ) /
          days.length;
  double get averageReliability => days.isEmpty
      ? 0
      : days.fold<double>(
            0,
            (double sum, _FoodWeekDaySnapshot item) =>
                sum + item.reliabilityTotal,
          ) /
          days.length;
}

class _FoodWeekDaySnapshot {
  const _FoodWeekDaySnapshot({
    required this.date,
    required this.dateKey,
    required this.weekdayLabel,
    required this.steps,
    required this.stepGoal,
    required this.meals,
    required this.calories,
    required this.targetKcal,
    required this.reliabilityTotal,
  });

  final DateTime date;
  final String dateKey;
  final String weekdayLabel;
  final int steps;
  final int stepGoal;
  final List<_FoodWeekMealSnapshot> meals;
  final double calories;
  final double targetKcal;
  final double reliabilityTotal;
}

class _FoodWeekMealSnapshot {
  const _FoodWeekMealSnapshot({
    required this.id,
    required this.slotCode,
    required this.calories,
    required this.itemCount,
    required this.isFreeMeal,
    required this.freeTrackingCode,
  });

  final int id;
  final String slotCode;
  final double calories;
  final int itemCount;
  final bool isFreeMeal;
  final String freeTrackingCode;

  String get normalizedFreeTrackingCode {
    final String clean = freeTrackingCode.trim().toLowerCase();
    if (clean == 'untracked' || clean == 'estimated' || clean == 'tracked') {
      return clean;
    }
    return isFreeMeal ? 'tracked' : '';
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
      bottomNavigationBar:
          const TtFoodBottomNavBar(activeItem: TtFoodNavItem.none),
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

  // Retained as an internal diagnostic action; the visible info button uses
  // the transparent adaptive calculation sheet.
  // ignore: unused_element
  Future<void> _showDayObjectBoxDetails(
    DailyRecordEntity day,
    List<MealWithItems> meals,
  ) async {
    final int mealItemCount = meals.fold<int>(
      0,
      (int sum, MealWithItems meal) => sum + meal.items.length,
    );
    final bool? clearRequested = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color:
                            Theme.of(sheetContext).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.storage_rounded,
                        color: Theme.of(sheetContext)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Dettagli giornata',
                            style:
                                Theme.of(sheetContext).textTheme.headlineSmall,
                          ),
                          Text(
                            'Campi persistenti salvati in ObjectBox',
                            style: Theme.of(sheetContext).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Chiudi',
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  children: <Widget>[
                    _TrackingSheetSection(
                      emoji: '🧱',
                      title: 'Identificativi',
                      children: <Widget>[
                        _detailRow('ObjectBox id', day.id.toString()),
                        _detailRow('UUID', day.uuid),
                      ],
                    ),
                    _TrackingSheetSection(
                      emoji: '📅',
                      title: 'Calendario',
                      children: <Widget>[
                        _detailRow('Data', day.dateKey),
                        _detailRow('Settimana', day.weekCode),
                        _detailRow('Weekday code', day.weekdayCode),
                        _detailRow('Weekday label', day.weekdayLabel),
                        _detailRow(
                            'Weekday index', day.weekdayIndex.toString()),
                      ],
                    ),
                    _TrackingSheetSection(
                      emoji: '🎯',
                      title: 'Target e attività',
                      children: <Widget>[
                        _detailRow('Target kcal',
                            _fmtNullable(day.targetKcal, 'kcal')),
                        _detailRow('Target status', day.targetStatusCode),
                        _detailRow('Target source hash', day.targetSourceHash),
                        _detailRow('RMR', _fmtNullable(day.rmrKcal, 'kcal')),
                        _detailRow('TDEE riferimento',
                            _fmtNullable(day.tdeeRefKcal, 'kcal')),
                        _detailRow('TDEE teorico',
                            _fmtNullable(day.tdeeTheoreticalKcal, 'kcal')),
                        _detailRow('TDEE osservato',
                            _fmtNullable(day.tdeeObservedKcal, 'kcal')),
                        _detailRow('Attive effettive',
                            _fmtNullable(day.activeEffectiveKcal, 'kcal')),
                        _detailRow('Stato attività', day.activeStatusCode),
                      ],
                    ),
                    _TrackingSheetSection(
                      emoji: '📝',
                      title: 'Monitoraggio',
                      children: <Widget>[
                        _detailRow('Pasti', meals.length.toString()),
                        _detailRow('Voci nei pasti', mealItemCount.toString()),
                        _detailRow('Passi', day.steps.toString()),
                        _detailRow('Obiettivo passi configurato',
                            day.stepGoal.toString()),
                        _detailRow('Acqua', _fmtNullable(day.waterLiters, 'l')),
                        _detailRow(
                            'Bicchieri', day.waterGlasses?.toString() ?? ''),
                        _detailRow('Sonno profondo',
                            _fmtNullable(day.sleepDeepHours, 'h')),
                        _detailRow('Sonno leggero',
                            _fmtNullable(day.sleepLightHours, 'h')),
                        _detailRow('Qualità sonno', day.sleepQualityCode),
                        _detailRow('Note', day.notes),
                      ],
                    ),
                    _TrackingSheetSection(
                      emoji: '🕒',
                      title: 'Audit',
                      children: <Widget>[
                        _detailRow(
                            'Creato epoch ms', day.createdAtEpochMs.toString()),
                        _detailRow('Aggiornato epoch ms',
                            day.updatedAtEpochMs.toString()),
                        _detailRow(
                          'Eliminato epoch ms',
                          day.deletedAtEpochMs?.toString() ?? '',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(sheetContext).colorScheme.error,
                        side: BorderSide(
                          color: Theme.of(sheetContext).colorScheme.error,
                        ),
                      ),
                      onPressed: mealItemCount == 0
                          ? null
                          : () => Navigator.of(sheetContext).pop(true),
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: Text(
                        mealItemCount == 0
                            ? 'Nessuna voce da eliminare'
                            : 'Svuota i pasti della giornata ($mealItemCount)',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (clearRequested != true || !mounted) {
      return;
    }
    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Svuota i pasti della giornata',
                  style: Theme.of(sheetContext).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Verranno eliminate tutte le $mealItemCount voci presenti nei '
                  'pasti del ${day.dateKey}. Gli slot Colazione, Pranzo, Spuntino '
                  'e Cena resteranno disponibili.',
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('Annulla'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              Theme.of(sheetContext).colorScheme.error,
                          foregroundColor:
                              Theme.of(sheetContext).colorScheme.onError,
                        ),
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('Svuota'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final int removed =
        ref.read(mealRepositoryProvider).clearItemsForDate(day.dateKey);
    _invalidateFood(ref);
    setState(_load);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed == 1
              ? 'Eliminata 1 voce dai pasti della giornata.'
              : 'Eliminate $removed voci dai pasti della giornata.',
        ),
      ),
    );
  }

  Future<void> _showAdaptiveTargetDetails(
    DailyRecordEntity day,
    List<MealWithItems> meals,
    TargetDayResult targetResult,
    ActivityBreakdown activity,
    UserProfileEntity? profile,
    List<DailyRecordEntity> allDays,
    bool hasPartialNutrition,
  ) async {
    final int mealItemCount = meals.fold<int>(
      0,
      (int sum, MealWithItems meal) => sum + meal.items.length,
    );
    final ResolvedActivityBreakdown resolved = targetResult.activity;
    final DateTime dayDate = DateTime.parse(day.dateKey);
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime normalizedDay =
        DateTime(dayDate.year, dayDate.month, dayDate.day);
    final bool isFuture = normalizedDay.isAfter(today);
    final String dayMode = isFuture ||
            resolved.usedStepGoalFallback ||
            resolved.usedProfileWorkoutFallback
        ? 'Previsionale'
        : 'Registrato';
    final double sedentaryBase =
        targetResult.tdeeTheoreticalKcal - targetResult.activeRefKcal;
    final double observedWeight = targetResult.observedConfidence;
    final double theoreticalWeight = 1 - observedWeight;
    final int priorRecords = allDays
        .where(
          (DailyRecordEntity item) => item.dateKey.compareTo(day.dateKey) < 0,
        )
        .length;

    String fmt(double value) {
      if (!value.isFinite) return 'n/d';
      return value.toStringAsFixed(value.abs() >= 100 ? 0 : 1);
    }

    String fmtNullable(double? value, String unit) {
      if (value == null || !value.isFinite) return 'n/d';
      final String suffix = unit.trim().isEmpty ? '' : ' ${unit.trim()}';
      return '${fmt(value)}$suffix';
    }

    Widget detailRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 5,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 6,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    Widget metricCard({
      required String label,
      required String value,
      required IconData icon,
      Color? accent,
    }) {
      final Color resolved = accent ?? Theme.of(context).colorScheme.primary;
      return SizedBox(
        width: 158,
        child: TtAppCard(
          backgroundColor: resolved.withValues(alpha: 0.08),
          borderColor: resolved.withValues(alpha: 0.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: resolved),
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    Widget section({
      required String title,
      required List<Widget> children,
      IconData icon = Icons.info_outline_rounded,
      Color? accent,
    }) {
      final Color resolved = accent ?? Theme.of(context).colorScheme.primary;
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: TtAppCard(
          borderColor: resolved.withValues(alpha: 0.28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: resolved.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: resolved, size: 21),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(),
              ...children,
            ],
          ),
        ),
      );
    }

    final bool? clearRequested = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.94,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color:
                            Theme.of(sheetContext).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.calculate_outlined,
                        color: Theme.of(sheetContext)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Calcolo adattivo giornaliero',
                            style:
                                Theme.of(sheetContext).textTheme.headlineSmall,
                          ),
                          Text(
                            'Formula, fonti, fallback e snapshot del ${day.dateKey}',
                            style: Theme.of(sheetContext).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Chiudi',
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  children: <Widget>[
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        metricCard(
                          label: 'Target finale',
                          value: '${fmt(targetResult.targetKcal)} kcal',
                          icon: Icons.flag_rounded,
                        ),
                        metricCard(
                          label: 'TDEE riferimento',
                          value: '${fmt(targetResult.tdeeRefKcal)} kcal',
                          icon: Icons.monitor_heart_outlined,
                        ),
                        metricCard(
                          label: 'Attività usata',
                          value: '${fmt(resolved.totalKcal)} kcal',
                          icon: Icons.directions_walk_rounded,
                        ),
                        metricCard(
                          label: 'Affidabilità osservata',
                          value:
                              '${(targetResult.observedConfidence * 100).round()}%',
                          icon: Icons.verified_outlined,
                          accent: targetResult.tdeeObservedKcal == null
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    section(
                      title: 'Formula finale',
                      icon: Icons.functions_rounded,
                      children: <Widget>[
                        detailRow(
                          'Formula',
                          'target = TDEE riferimento + (attività giorno - attività riferimento)',
                        ),
                        detailRow(
                          'Sostituzione',
                          '${fmt(targetResult.targetKcal)} = '
                              '${fmt(targetResult.tdeeRefKcal)} + '
                              '(${fmt(resolved.totalKcal)} - '
                              '${fmt(targetResult.activeRefKcal)}) kcal',
                        ),
                        detailRow(
                          'Delta attività',
                          '${fmt(targetResult.activityDeltaKcal)} kcal',
                        ),
                        detailRow(
                          'Target finale',
                          '${fmt(targetResult.targetKcal)} kcal',
                        ),
                        detailRow(
                            'Stato target', targetResult.targetStatusCode),
                        detailRow('Modalità del giorno', dayMode),
                      ],
                    ),
                    section(
                      title: 'TDEE di riferimento',
                      icon: Icons.monitor_heart_outlined,
                      children: <Widget>[
                        detailRow(
                          'RMR',
                          fmtNullable(targetResult.rmrKcal, 'kcal'),
                        ),
                        detailRow(
                          'Base sedentaria',
                          '${fmt(sedentaryBase)} kcal',
                        ),
                        detailRow(
                          'Attività di riferimento',
                          '${fmt(targetResult.activeRefKcal)} kcal',
                        ),
                        detailRow(
                          'TDEE teorico',
                          '${fmt(targetResult.tdeeTheoreticalKcal)} kcal',
                        ),
                        detailRow(
                          'TDEE osservato',
                          fmtNullable(targetResult.tdeeObservedKcal, 'kcal'),
                        ),
                        detailRow(
                          'Metodo osservato',
                          targetResult.observedModelLevelCode ==
                                  'composition_blended'
                              ? 'introito medio − variazione energetica combinata '
                                  'di massa grassa, massa priva di grasso e peso'
                              : 'media ponderata delle calorie assunte − '
                                  '(pendenza Theil–Sen kg/giorno × 7700 kcal/kg)',
                        ),
                        detailRow(
                          'Media calorie usata',
                          fmtNullable(targetResult.avgCalories, 'kcal'),
                        ),
                        detailRow(
                          'Variazione peso usata',
                          fmtNullable(targetResult.deltaWeightKg, 'kg'),
                        ),
                        detailRow(
                          'Pendenza robusta peso',
                          fmtNullable(
                              targetResult.weightSlopeKgPerDay, 'kg/giorno'),
                        ),
                        detailRow(
                          'Livello osservato',
                          targetResult.observedModelLevelCode,
                        ),
                        detailRow(
                          'Composizione corporea',
                          targetResult.observedModelLevelCode ==
                                  'composition_blended'
                              ? 'attiva · confidenza '
                                  '${(targetResult.compositionConfidence * 100).round()}%'
                              : 'fallback al peso · '
                                  '${targetResult.compositionFallbackReasonCode}',
                        ),
                        detailRow(
                          'Candidato energetico composizione',
                          fmtNullable(
                            targetResult.compositionEnergyChangeKcalPerDay,
                            'kcal/giorno',
                          ),
                        ),
                        detailRow(
                          'Variazione energetica effettiva',
                          fmtNullable(
                            targetResult.effectiveBodyEnergyChangeKcalPerDay,
                            'kcal/giorno',
                          ),
                        ),
                        detailRow(
                          'Conversione energetica',
                          '${fmt(targetResult.kcalPerKg)} kcal/kg',
                        ),
                        detailRow(
                          'Componente osservata',
                          '${(observedWeight * 100).round()}%',
                        ),
                        detailRow(
                          'Componente teorica',
                          '${(theoreticalWeight * 100).round()}%',
                        ),
                        detailRow(
                          'TDEE combinato',
                          '${fmt(targetResult.tdeeRefKcal)} kcal',
                        ),
                      ],
                    ),
                    section(
                      title: 'Attività del giorno',
                      icon: Icons.directions_run_rounded,
                      children: <Widget>[
                        detailRow('Passi registrati', day.steps.toString()),
                        detailRow('Obiettivo passi', day.stepGoal.toString()),
                        detailRow(
                          'Passi degli allenamenti',
                          'esclusi manualmente dal totale giornaliero',
                        ),
                        detailRow(
                          'Kcal passi registrate',
                          '${fmt(resolved.actualStepKcal)} kcal',
                        ),
                        detailRow(
                          'Kcal passi usate',
                          '${fmt(resolved.effectiveStepKcal)} kcal',
                        ),
                        detailRow(
                          'Calorie allenamento registrate',
                          '${fmt(resolved.actualWorkoutKcal)} kcal',
                        ),
                        detailRow(
                          'Calorie allenamento usate',
                          '${fmt(resolved.effectiveWorkoutKcal)} kcal',
                        ),
                        detailRow(
                          'Sorgente calorie allenamento',
                          'estimated_active_calories esposto dalle sessioni completate',
                        ),
                        detailRow(
                          'Consumo attivo usato',
                          '${fmt(resolved.totalKcal)} kcal',
                        ),
                        detailRow(
                          'Stato attività',
                          resolved.statusCode == 'partially_provisional'
                              ? 'parzialmente provvisorio'
                              : resolved.statusCode == 'provisional'
                                  ? 'provvisorio'
                                  : resolved.statusCode,
                        ),
                        detailRow(
                          'Lunghezza passo',
                          resolved.stepLengthMeters == null
                              ? 'fallback legacy'
                              : '${resolved.stepLengthMeters!.toStringAsFixed(3)} m',
                        ),
                        detailRow(
                          'Sorgente lunghezza',
                          resolved.stepLengthSourceCode,
                        ),
                        detailRow(
                          'Peso usato per i passi',
                          resolved.stepWeightSourceCode,
                        ),
                        detailRow(
                          'Coefficiente effettivo',
                          '${resolved.effectiveStepKcalCoefficient.toStringAsFixed(5)} kcal/passo',
                        ),
                        detailRow(
                          'Fallback passi',
                          resolved.usedStepGoalFallback ? 'sì' : 'no',
                        ),
                        detailRow(
                          'Fallback allenamento',
                          resolved.usedProfileWorkoutFallback ? 'sì' : 'no',
                        ),
                      ],
                    ),
                    section(
                      title: 'Finestra osservata e peso',
                      icon: Icons.timeline_rounded,
                      children: <Widget>[
                        detailRow(
                          'Giorni di riferimento usati',
                          targetResult.referenceDaysCount.toString(),
                        ),
                        detailRow(
                          'Record precedenti disponibili',
                          priorRecords.toString(),
                        ),
                        detailRow(
                          'Introiti validi',
                          targetResult.validIntakeDays.toString(),
                        ),
                        detailRow(
                          'Pesi validi',
                          targetResult.validWeightDays.toString(),
                        ),
                        detailRow(
                          'Peso di riferimento',
                          fmtNullable(targetResult.weightRefKg, 'kg'),
                        ),
                        detailRow('Stato peso', targetResult.weightStatusCode),
                        detailRow(
                          "Giorni dall'ultima pesata",
                          targetResult.weightDaysSinceMeasurement?.toString() ??
                              'n/d',
                        ),
                      ],
                    ),
                    section(
                      title: 'Configurazione del modello',
                      icon: Icons.tune_rounded,
                      children: <Widget>[
                        detailRow(
                          'Finestra massima',
                          '${profile?.adaptiveReferenceDays ?? 28} giorni',
                        ),
                        detailRow(
                          'Minimo giorni osservati',
                          '${profile?.adaptiveMinimumObservedDays ?? 7}',
                        ),
                        detailRow(
                          'Versione modello',
                          targetResult.targetModelVersion,
                        ),
                        detailRow(
                          'Data di entrata in vigore',
                          TargetModelConstants.effectiveDate,
                        ),
                        detailRow(
                          'RMR',
                          '${targetResult.rmrEquationCode} · '
                              '${targetResult.rmrPhysiologicalCoefficientCode}',
                        ),
                        detailRow(
                          'Formula passi',
                          'peso × passi × lunghezza × 0,50 / 1000',
                        ),
                        detailRow(
                          'Prior variazione peso',
                          '${TargetModelConstants.energyDensityPriorKcalPerKg.round()} kcal/kg',
                        ),
                        detailRow(
                          'Limiti TDEE',
                          '${profile?.minimumReasonableTdee ?? 1300} - '
                              '${profile?.maximumReasonableTdee ?? 4600} kcal',
                        ),
                        detailRow(
                          'Guardrail',
                          targetResult.guardrailApplied
                              ? 'applicato (${targetResult.guardrailReasonCode}) · '
                                  'prima ${fmtNullable(targetResult.unclampedTargetKcal, 'kcal')}'
                              : 'non applicato',
                        ),
                        detailRow(
                          'Fallback attività',
                          profile?.activityFallbackModeCode ?? 'recorded_only',
                        ),
                        detailRow(
                          'Regola fallback',
                          'ogni componente registrata prevale; viene stimata '
                              'solo la componente mancante',
                        ),
                      ],
                    ),
                    section(
                      title: 'Fonti, formule e limiti',
                      icon: Icons.menu_book_outlined,
                      children: <Widget>[
                        detailRow(
                          'Evidenza scientifica',
                          'Mifflin–St Jeor per RMR; stima di popolazione non clinica',
                        ),
                        detailRow(
                          'Linea guida passi',
                          'escludere passi di allenamenti registrati separatamente',
                        ),
                        detailRow(
                          'Obiettivo passi',
                          'configurabile dall’utente; usato come fallback solo se i passi mancano',
                        ),
                        detailRow(
                          'Contratto allenamenti',
                          'il giorno usa estimated_active_calories; il modello interno dell’allenamento è fuori ambito',
                        ),
                        detailRow(
                          'Euristiche interne',
                          'Theil–Sen, 7700 kcal/kg, blending e confidenza',
                        ),
                        detailRow(
                          'IN STALLO',
                          'quota base 1,10 e guardrail 1300–4600',
                        ),
                        detailRow(
                          'Limite d’uso',
                          'adulti sani, uso generale/sportivo non clinico',
                        ),
                      ],
                    ),
                    if (targetResult.alerts.isNotEmpty || hasPartialNutrition)
                      section(
                        title: 'Avvisi del giorno',
                        icon: Icons.warning_amber_rounded,
                        accent: Theme.of(context).colorScheme.tertiary,
                        children: <Widget>[
                          for (final TargetAlert alert in targetResult.alerts)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: _TargetAlertCard(alert: alert),
                            ),
                          if (hasPartialNutrition)
                            const _TargetAlertCard(
                              alert: TargetAlert(
                                code: 'partial_nutrition',
                                title: 'Nutrizione parziale',
                                message:
                                    'Questo giorno contiene un pasto libero '
                                    'non completamente quantificato. Il '
                                    'bilancio usa soltanto i dati disponibili.',
                                severityCode: TargetAlertSeverityCodes.warning,
                              ),
                            ),
                        ],
                      ),
                    section(
                      title: 'Snapshot e persistenza',
                      icon: Icons.storage_rounded,
                      children: <Widget>[
                        detailRow('ObjectBox id', day.id.toString()),
                        detailRow('Target source hash', day.targetSourceHash),
                        detailRow(
                          'Target calcolato epoch ms',
                          day.targetCalculatedAtEpochMs?.toString() ?? 'n/d',
                        ),
                        detailRow('Pasti', meals.length.toString()),
                        detailRow('Voci nei pasti', mealItemCount.toString()),
                        detailRow(
                          'Calorie registrate',
                          '${fmt(activity.actualTotalKcal)} kcal attive; '
                              '${fmt(_totalsForMeals(meals).kcal)} kcal assunte',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(sheetContext).colorScheme.error,
                        side: BorderSide(
                          color: Theme.of(sheetContext).colorScheme.error,
                        ),
                      ),
                      onPressed: mealItemCount == 0
                          ? null
                          : () => Navigator.of(sheetContext).pop(true),
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: Text(
                        mealItemCount == 0
                            ? 'Nessuna voce da eliminare'
                            : 'Svuota i pasti della giornata ($mealItemCount)',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (clearRequested != true || !mounted) return;
    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Svuota i pasti della giornata',
                  style: Theme.of(sheetContext).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Verranno eliminate tutte le $mealItemCount voci presenti '
                  'nei pasti del ${day.dateKey}. Gli slot resteranno disponibili.',
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('Annulla'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              Theme.of(sheetContext).colorScheme.error,
                          foregroundColor:
                              Theme.of(sheetContext).colorScheme.onError,
                        ),
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('Svuota'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;
    final int removed =
        ref.read(mealRepositoryProvider).clearItemsForDate(day.dateKey);
    _invalidateFood(ref);
    setState(_load);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed == 1
              ? 'Eliminata 1 voce dai pasti della giornata.'
              : 'Eliminate $removed voci dai pasti della giornata.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: _LoadingState());
    }
    final DailyRecordEntity day = _bundle.day;
    final MealRepository mealRepository = ref.watch(mealRepositoryProvider);
    final measurementRepository = ref.watch(measurementRepositoryProvider);
    final FoodAnalyticsService analytics =
        ref.watch(foodAnalyticsServiceProvider);
    final UserProfileEntity? profile =
        ref.watch(userProfileRepositoryProvider).getActiveProfile();
    final List<DailyRecordEntity> allDays =
        ref.watch(dailyRecordRepositoryProvider).getAllActive();
    final List<MealWithItems> meals =
        mealRepository.getMealsWithItemsForDate(day.dateKey);
    final double caloriesIn = analytics.caloriesForDate(day.dateKey);
    final MealNutritionTotals totals = _totalsForMeals(meals);
    final ActivityBreakdown activity =
        analytics.activityForDay(day, profile: profile);
    final TargetDayResult targetResult = analytics.targetResultForDay(
      day: day,
      allDays: allDays,
      profile: profile,
    );
    final double target = targetResult.targetKcal;
    final ProfileNutritionTargets macroTargets = analytics.macroTargetsForDay(
      day: day,
      profile: profile,
    );
    final double balance = caloriesIn - target;
    final ScaleMeasurementEntity? scaleMeasurement =
        measurementRepository.findScaleByDate(day.dateKey);
    final double? weight =
        scaleMeasurement?.weightKg ?? analytics.weightForDay(day);
    final bool hasScaleMeasurement = scaleMeasurement != null;
    final bool partial = analytics.hasPartialNutrition(day.dateKey);
    final bool allMealsRegistered = _hasAllMealSlotsLogged(meals);

    return Scaffold(
      appBar: AppBar(
        title: Text('${day.weekdayLabel} ${day.dateKey}'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Come viene calcolato il target',
            onPressed: () => _showAdaptiveTargetDetails(
              day,
              meals,
              targetResult,
              activity,
              profile,
              allDays,
              partial,
            ),
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      bottomNavigationBar:
          const TtFoodBottomNavBar(activeItem: TtFoodNavItem.none),
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
                label: partial
                    ? 'Parziale'
                    : allMealsRegistered
                        ? 'Completo'
                        : 'Da completare',
                isWarning: partial || !allMealsRegistered,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TtPrimaryButton(
            label: 'Aggiorna dati giornalieri',
            icon: Icons.edit_note_rounded,
            onPressed: () =>
                _showDayTrackingDialog(day, weight, hasScaleMeasurement),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          _DashboardDailySummary(
            day: day,
            meals: meals,
            targetKcal: target,
            totals: totals,
            macroTargets: macroTargets,
            onTap: () => _showDayStatsSheet(
              context: context,
              day: day,
              caloriesIn: caloriesIn,
              target: target,
              balance: balance,
              activity: activity,
              weight: weight,
            ),
          ),
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
    bool hasScaleMeasurement,
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
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext _) {
        return _DayTrackingSheet(
          formKey: formKey,
          target: target,
          weight: weight,
          water: water,
          glasses: glasses,
          deep: deep,
          light: light,
          quality: quality,
          steps: steps,
          stepGoal: stepGoal,
          notes: notes,
          hasScaleMeasurement: hasScaleMeasurement,
        );
      },
    );
    if (saved != true) {
      return;
    }
    if (!mounted) {
      return;
    }
    final String? sleepError = _sleepTotalError(deep.text, light.text);
    if (sleepError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sleepError)),
      );
      return;
    }
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
    if (!hasScaleMeasurement && nextWeight != null) {
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
    final UserProfileEntity? profile =
        ref.read(userProfileRepositoryProvider).getActiveProfile();
    final dailyRepository = ref.read(dailyRecordRepositoryProvider);
    final FoodAnalyticsService analytics =
        ref.read(foodAnalyticsServiceProvider);
    final List<DailyRecordEntity> allDays = dailyRepository.getAllActive();
    final TargetDayResult targetResult = analytics.targetResultForDay(
      day: day,
      allDays: allDays,
      profile: profile,
    );
    analytics.applyTargetSnapshot(day, targetResult);
    dailyRepository.save(day);
    ref.invalidate(foodDaysV01Provider);
    ref.invalidate(foodHubV01Provider);
    setState(() =>
        _bundle = ref.read(foodPlanningServiceProvider).ensureDay(day.dateKey));
  }
}

class _DayTrackingSheet extends StatelessWidget {
  const _DayTrackingSheet({
    required this.formKey,
    required this.target,
    required this.weight,
    required this.water,
    required this.glasses,
    required this.deep,
    required this.light,
    required this.quality,
    required this.steps,
    required this.stepGoal,
    required this.notes,
    required this.hasScaleMeasurement,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController target;
  final TextEditingController weight;
  final TextEditingController water;
  final TextEditingController glasses;
  final TextEditingController deep;
  final TextEditingController light;
  final TextEditingController quality;
  final TextEditingController steps;
  final TextEditingController stepGoal;
  final TextEditingController notes;
  final bool hasScaleMeasurement;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Monitoraggio giornaliero',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          'Aggiorna i dati della giornata',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chiudi',
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  children: <Widget>[
                    _TrackingSheetSection(
                      emoji: '🔥',
                      title: 'Energia',
                      children: <Widget>[
                        _field(
                          target,
                          'Target kcal',
                          enabled: false,
                          helperText: 'Gestito da profilo e impostazioni',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                    _TrackingSheetSection(
                      emoji: '⚖️',
                      title: 'Peso',
                      children: <Widget>[
                        _field(
                          weight,
                          'Peso bilancia kg',
                          enabled: !hasScaleMeasurement,
                          helperText: hasScaleMeasurement
                              ? 'Gestito dalla sezione Body Measurement'
                              : 'Se salvi qui creo una misurazione bilancia',
                          keyboardType: TextInputType.number,
                          onTap: hasScaleMeasurement
                              ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Peso gia registrato nelle misurazioni: apri Body Measurement per modificarlo.',
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        ),
                      ],
                    ),
                    _TrackingSheetSection(
                      emoji: '💧',
                      title: 'Idratazione',
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _field(
                                water,
                                'Acqua litri',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _field(
                                glasses,
                                'Bicchieri',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    _TrackingSheetSection(
                      emoji: '😴',
                      title: 'Sonno',
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _SleepDurationField(
                                controller: deep,
                                label: 'Profondo',
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _SleepDurationField(
                                controller: light,
                                label: 'Leggero',
                              ),
                            ),
                          ],
                        ),
                        _SleepQualityDropdown(controller: quality),
                        _SleepTotalPreview(deep: deep, light: light),
                      ],
                    ),
                    _TrackingSheetSection(
                      emoji: '🚶',
                      title: 'Attivita',
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _field(
                                steps,
                                'Passi',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _field(
                                stepGoal,
                                'Obiettivo',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    _TrackingSheetSection(
                      emoji: '📝',
                      title: 'Note',
                      children: <Widget>[
                        _field(notes, 'Note', maxLines: 4),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Annulla'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          final bool formOk =
                              formKey.currentState?.validate() ?? false;
                          if (!formOk) {
                            return;
                          }
                          final String? sleepError =
                              _sleepTotalError(deep.text, light.text);
                          if (sleepError != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(sleepError)),
                            );
                            return;
                          }
                          Navigator.of(context).pop(true);
                        },
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Salva'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingSheetSection extends StatelessWidget {
  const _TrackingSheetSection({
    required this.emoji,
    required this.title,
    required this.children,
  });

  final String emoji;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TtAppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  emoji,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SleepDurationField extends StatefulWidget {
  const _SleepDurationField({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  State<_SleepDurationField> createState() => _SleepDurationFieldState();
}

class _SleepDurationFieldState extends State<_SleepDurationField> {
  late final TextEditingController _hours;
  late final TextEditingController _minutes;

  @override
  void initState() {
    super.initState();
    final double totalHours = _toDouble(widget.controller.text) ?? 0;
    final int hours = totalHours.floor();
    final int minutes = ((totalHours - hours) * 60).round().clamp(0, 59);
    _hours = TextEditingController(text: hours == 0 ? '' : hours.toString());
    _minutes =
        TextEditingController(text: minutes == 0 ? '' : minutes.toString());
  }

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _sync() {
    final int hours = _toInt(_hours.text) ?? 0;
    final int minutes = _toInt(_minutes.text) ?? 0;
    if (hours < 0 || minutes < 0 || minutes > 59) {
      return;
    }
    final double value = hours + minutes / 60;
    if (value > 24) {
      return;
    }
    widget.controller.text = value <= 0 ? '' : value.toStringAsFixed(2);
  }

  String? _validateHours(String? value) {
    final String clean = value?.trim() ?? '';
    if (clean.isEmpty) {
      return null;
    }
    final int? hours = _toInt(clean);
    if (hours == null || hours < 0) {
      return 'Ore non valide';
    }
    if (hours > 24) {
      return 'Max 24 ore';
    }
    return null;
  }

  String? _validateMinutes(String? value) {
    final String clean = value?.trim() ?? '';
    if (clean.isEmpty) {
      return null;
    }
    final int? minutes = _toInt(clean);
    if (minutes == null || minutes < 0 || minutes > 59) {
      return '0-59 min';
    }
    final int hours = _toInt(_hours.text) ?? 0;
    if (hours >= 24 && minutes > 0) {
      return 'Totale oltre 24h';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                controller: _hours,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ore'),
                validator: _validateHours,
                onChanged: (_) => _sync(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextFormField(
                controller: _minutes,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Min'),
                validator: _validateMinutes,
                onChanged: (_) => _sync(),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _SleepQualityDropdown extends StatefulWidget {
  const _SleepQualityDropdown({required this.controller});

  final TextEditingController controller;

  @override
  State<_SleepQualityDropdown> createState() => _SleepQualityDropdownState();
}

class _SleepQualityDropdownState extends State<_SleepQualityDropdown> {
  static const Map<String, String> _options = <String, String>{
    '': 'Non indicata',
    'excellent': 'Ottima',
    'good': 'Buona',
    'average': 'Media',
    'poor': 'Scarsa',
  };

  @override
  Widget build(BuildContext context) {
    final String current = widget.controller.text.trim();
    final List<DropdownMenuItem<String>> items = <DropdownMenuItem<String>>[
      for (final MapEntry<String, String> entry in _options.entries)
        DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value),
        ),
      if (current.isNotEmpty && !_options.containsKey(current))
        DropdownMenuItem<String>(
          value: current,
          child: Text(current),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DropdownButtonFormField<String>(
        initialValue: items.any(
          (DropdownMenuItem<String> item) => item.value == current,
        )
            ? current
            : '',
        decoration: const InputDecoration(labelText: 'Qualita sonno'),
        items: items,
        onChanged: (String? value) {
          widget.controller.text = value ?? '';
        },
      ),
    );
  }
}

class _SleepTotalPreview extends StatefulWidget {
  const _SleepTotalPreview({
    required this.deep,
    required this.light,
  });

  final TextEditingController deep;
  final TextEditingController light;

  @override
  State<_SleepTotalPreview> createState() => _SleepTotalPreviewState();
}

class _SleepTotalPreviewState extends State<_SleepTotalPreview> {
  @override
  void initState() {
    super.initState();
    widget.deep.addListener(_refresh);
    widget.light.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.deep.removeListener(_refresh);
    widget.light.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final double deep = _toDouble(widget.deep.text) ?? 0;
    final double light = _toDouble(widget.light.text) ?? 0;
    final double total = deep + light;
    final String? error = _sleepTotalError(widget.deep.text, widget.light.text);
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: error == null
              ? colors.surfaceContainerHighest
              : colors.errorContainer,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Icon(
                error == null
                    ? Icons.bedtime_outlined
                    : Icons.error_outline_rounded,
                color: error == null
                    ? colors.onSurfaceVariant
                    : colors.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  error ?? 'Sonno totale: ${_sleepDurationText(total)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: error == null
                            ? colors.onSurfaceVariant
                            : colors.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _sleepTotalError(String deepText, String lightText) {
  final double deep = _toDouble(deepText) ?? 0;
  final double light = _toDouble(lightText) ?? 0;
  if (deep < 0 || light < 0) {
    return 'Le ore di sonno non possono essere negative.';
  }
  final double total = deep + light;
  if (total > 24) {
    return 'Il sonno totale supera 24 ore.';
  }
  return null;
}

String _sleepDurationText(double hours) {
  if (hours <= 0) {
    return 'n/d';
  }
  int wholeHours = hours.floor();
  int minutes = ((hours - wholeHours) * 60).round();
  if (minutes == 60) {
    wholeHours += 1;
    minutes = 0;
  }
  if (minutes == 0) {
    return '$wholeHours h';
  }
  return '$wholeHours h ${minutes.toString().padLeft(2, '0')} min';
}

class _MacroProgressLine extends StatelessWidget {
  const _MacroProgressLine({
    required this.label,
    required this.value,
    required this.target,
  });

  final String label;
  final double value;
  final double? target;

  @override
  Widget build(BuildContext context) {
    final double? cleanTarget = target != null && target! > 0 ? target : null;
    final double safeTarget = cleanTarget ?? 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(label)),
              Text(
                cleanTarget == null
                    ? '${_fmt(value)} g'
                    : '${_fmt(value)} / ${_fmt(safeTarget)} g',
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (cleanTarget != null)
            LinearProgressIndicator(
              value: (value / safeTarget).clamp(0, 1).toDouble(),
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
            ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 1,
      color:
          isDark ? Colors.white.withValues(alpha: 0.12) : Colors.grey.shade300,
    );
  }
}

Future<void> _showDayStatsSheet({
  required BuildContext context,
  required DailyRecordEntity day,
  required double caloriesIn,
  required double? target,
  required double? balance,
  required ActivityBreakdown activity,
  required double? weight,
  VoidCallback? onOpenDay,
}) async {
  final double safeTarget = target == null || target <= 0 ? 1.0 : target;
  final double calorieProgress =
      (caloriesIn / safeTarget).clamp(0, 1).toDouble();
  final double sleepTotal =
      (day.sleepDeepHours ?? 0) + (day.sleepLightHours ?? 0);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: false,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) {
      final ColorScheme colors = Theme.of(sheetContext).colorScheme;
      return FractionallySizedBox(
        heightFactor: 0.9,
        child: Column(
          children: <Widget>[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.dashboard_customize_outlined,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Riepilogo giornaliero',
                          style: Theme.of(sheetContext).textTheme.headlineSmall,
                        ),
                        Text(
                          '${day.weekdayLabel} ${day.dateKey}',
                          style: Theme.of(sheetContext).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chiudi',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: <Widget>[
                        SizedBox.square(
                          dimension: 96,
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              SizedBox.square(
                                dimension: 88,
                                child: CircularProgressIndicator(
                                  value: calorieProgress,
                                  strokeWidth: 9,
                                  backgroundColor:
                                      colors.surface.withValues(alpha: 0.72),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Text('🔥',
                                      style: TextStyle(fontSize: 20)),
                                  Text(
                                    caloriesIn.round().toString(),
                                    style: Theme.of(sheetContext)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: colors.onPrimaryContainer,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Calorie assunte',
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: colors.onPrimaryContainer,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Target ${_fmtNullableKcal(target)}',
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: colors.onPrimaryContainer,
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.surface.withValues(alpha: 0.74),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  balance == null
                                      ? 'Bilancio n/d'
                                      : 'Bilancio ${_signedKcal(balance)}',
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _DaySummarySection(
                    icon: Icons.directions_walk_rounded,
                    title: 'Attività',
                    values: <_DaySummaryValue>[
                      _DaySummaryValue(
                        icon: Icons.directions_walk_rounded,
                        label: 'Passi',
                        value: day.steps.toString(),
                      ),
                      _DaySummaryValue(
                        icon: Icons.flag_outlined,
                        label: 'Obiettivo',
                        value: day.stepGoal.toString(),
                      ),
                      _DaySummaryValue(
                        icon: Icons.local_fire_department_outlined,
                        label: 'Passi kcal',
                        value: _fmtKcal(activity.stepKcal),
                      ),
                      _DaySummaryValue(
                        icon: Icons.fitness_center_rounded,
                        label: 'Workout',
                        value: _fmtKcal(activity.completedWorkoutKcal),
                      ),
                      _DaySummaryValue(
                        icon: Icons.bolt_rounded,
                        label: 'Attive effettive',
                        value: _fmtKcal(activity.actualTotalKcal),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DaySummarySection(
                    icon: Icons.favorite_outline_rounded,
                    title: 'Benessere',
                    values: <_DaySummaryValue>[
                      _DaySummaryValue(
                        icon: Icons.monitor_weight_outlined,
                        label: 'Peso',
                        value: _fmtNullable(weight, 'kg'),
                      ),
                      _DaySummaryValue(
                        icon: Icons.water_drop_outlined,
                        label: 'Acqua',
                        value: _fmtNullable(day.waterLiters, 'l'),
                      ),
                      _DaySummaryValue(
                        icon: Icons.local_drink_outlined,
                        label: 'Bicchieri',
                        value: day.waterGlasses?.toString() ?? 'n/d',
                      ),
                      _DaySummaryValue(
                        icon: Icons.bedtime_outlined,
                        label: 'Sonno totale',
                        value:
                            sleepTotal <= 0 ? 'n/d' : '${_fmt(sleepTotal)} h',
                      ),
                      _DaySummaryValue(
                        icon: Icons.dark_mode_outlined,
                        label: 'Profondo',
                        value: _fmtNullable(day.sleepDeepHours, 'h'),
                      ),
                      _DaySummaryValue(
                        icon: Icons.light_mode_outlined,
                        label: 'Leggero',
                        value: _fmtNullable(day.sleepLightHours, 'h'),
                      ),
                      _DaySummaryValue(
                        icon: Icons.auto_awesome_outlined,
                        label: 'Qualità',
                        value: day.sleepQualityCode.isEmpty
                            ? 'n/d'
                            : day.sleepQualityCode,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onOpenDay != null)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        onOpenDay();
                      },
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Apri giornata completa'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _DaySummaryValue {
  const _DaySummaryValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _DaySummarySection extends StatelessWidget {
  const _DaySummarySection({
    required this.icon,
    required this.title,
    required this.values,
  });

  final IconData icon;
  final String title;
  final List<_DaySummaryValue> values;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: colors.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = (constraints.maxWidth - AppSpacing.sm) / 2;
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final _DaySummaryValue value in values)
                    SizedBox(
                      width: width,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 78),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              value.icon,
                              size: 19,
                              color: colors.primary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    value.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    value.value,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class FoodMealsScreen extends ConsumerStatefulWidget {
  const FoodMealsScreen({super.key});

  @override
  ConsumerState<FoodMealsScreen> createState() => _FoodMealsScreenState();
}

class _FoodMealsScreenState extends ConsumerState<FoodMealsScreen> {
  final TextEditingController _from = TextEditingController();
  final TextEditingController _to = TextEditingController();

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<MealWithItems>> meals =
        ref.watch(foodMealsV01Provider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pasti')),
      bottomNavigationBar:
          const TtFoodBottomNavBar(activeItem: TtFoodNavItem.none),
      body: meals.when(
        loading: () => const _LoadingState(),
        error: (Object error, StackTrace stackTrace) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(foodMealsV01Provider),
        ),
        data: (List<MealWithItems> meals) {
          final String from = _from.text.trim();
          final String to = _to.text.trim();
          final List<MealWithItems> filtered =
              meals.where((MealWithItems meal) {
            final String date = meal.meal.dateKey;
            final bool afterFrom = from.isEmpty || date.compareTo(from) >= 0;
            final bool beforeTo = to.isEmpty || date.compareTo(to) <= 0;
            return afterFrom && beforeTo;
          }).toList();
          if (meals.isEmpty) {
            return const _EmptyState(
              title: 'Nessun pasto',
              message:
                  'I pasti vengono creati automaticamente quando apri un giorno.',
            );
          }
          return ListView(
            padding: _screenPadding,
            children: <Widget>[
              TtAppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Filtra per data',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _field(
                            _from,
                            'Da',
                            enabled: false,
                            onTap: () => _pickFilterDate(_from),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _field(
                            _to,
                            'A',
                            enabled: false,
                            onTap: () => _pickFilterDate(_to),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        ActionChip(
                          avatar: const Icon(Icons.today_rounded),
                          label: const Text('Oggi'),
                          onPressed: () {
                            final String today = _dateKey(DateTime.now());
                            setState(() {
                              _from.text = today;
                              _to.text = today;
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.clear_rounded),
                          label: const Text('Pulisci'),
                          onPressed: () {
                            setState(() {
                              _from.clear();
                              _to.clear();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              if (filtered.isEmpty)
                const _EmptyInline(
                  message: 'Nessun pasto in questo intervallo.',
                )
              else
                for (final MealWithItems meal in filtered)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _MealListCard(meal: meal),
                  ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickFilterDate(TextEditingController controller) async {
    final DateTime initial =
        DateTime.tryParse(controller.text.trim()) ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => controller.text = _dateKey(picked));
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

  Future<void> _showMealObjectBoxDetails() async {
    final MealEntity meal = _details.meal;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.78,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Dettagli pasto',
                            style:
                                Theme.of(sheetContext).textTheme.headlineSmall,
                          ),
                          Text(
                            'Campi persistenti salvati in ObjectBox',
                            style: Theme.of(sheetContext).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Chiudi',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  children: <Widget>[
                    _TrackingSheetSection(
                      emoji: '🧱',
                      title: 'Identificativi',
                      children: <Widget>[
                        _detailRow('ObjectBox id', meal.id.toString()),
                        _detailRow('UUID', meal.uuid),
                        _detailRow(
                          'DailyRecord targetId',
                          meal.dailyRecord.targetId.toString(),
                        ),
                      ],
                    ),
                    _TrackingSheetSection(
                      emoji: '📅',
                      title: 'Data e slot',
                      children: <Widget>[
                        _detailRow('Data', meal.dateKey),
                        _detailRow('Settimana', meal.weekCode),
                        _detailRow('Weekday code', meal.weekdayCode),
                        _detailRow('Weekday label', meal.weekdayLabel),
                        _detailRow('Meal type code', meal.mealTypeCode),
                      ],
                    ),
                    _TrackingSheetSection(
                      emoji: '🍽️',
                      title: 'Configurazione',
                      children: <Widget>[
                        _detailRow('Titolo', meal.title),
                        _detailRow('Meal mode', meal.mealModeCode),
                        _detailRow(
                          'Free tracking',
                          meal.freeMealTrackingCode,
                        ),
                        _detailRow('Free label', meal.freeMealLabel),
                        _detailRow('Free notes', meal.freeMealNotes),
                        _detailRow(
                            'Voci collegate', _details.items.length.toString()),
                        _detailRow(
                          'Nutrizione parziale',
                          _details.isNutritionPartial ? 'si' : 'no',
                        ),
                      ],
                    ),
                    _TrackingSheetSection(
                      emoji: '🕒',
                      title: 'Audit',
                      children: <Widget>[
                        _detailRow('Creato epoch ms',
                            meal.createdAtEpochMs.toString()),
                        _detailRow(
                          'Aggiornato epoch ms',
                          meal.updatedAtEpochMs.toString(),
                        ),
                        _detailRow(
                          'Eliminato epoch ms',
                          meal.deletedAtEpochMs?.toString() ?? '',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(profileSettingsRevisionProvider);
    final MealEntity meal = _details.meal;
    final MealNutritionTotals totals = _details.totals;
    final UserProfileEntity? profile =
        ref.watch(userProfileRepositoryProvider).getActiveProfile();
    final DailyRecordRepository dailyRepository =
        ref.watch(dailyRecordRepositoryProvider);
    final FoodAnalyticsService analytics =
        ref.watch(foodAnalyticsServiceProvider);
    final DailyRecordEntity? day = dailyRepository.findByDate(meal.dateKey);
    final ProfileNutritionTargets? dailyTargets = profile == null
        ? null
        : day == null
            ? const ProfileNutritionCalculator().calculateFixedTargets(profile)
            : analytics.macroTargetsForDay(day: day, profile: profile);
    final double dailyKcal = profile == null || dailyTargets == null
        ? 0
        : day == null
            ? dailyTargets.targetKcal
            : analytics
                .targetResultForDay(
                  day: day,
                  allDays: dailyRepository.getAllActive(),
                  profile: profile,
                )
                .targetKcal;
    final MealNutrientTarget mealTarget =
        profile == null || dailyTargets == null
            ? MealNutrientTarget.empty
            : MealTargetSettings.fromProfile(profile).targetForSlot(
                slotCode: meal.mealTypeCode,
                dailyKcal: dailyKcal,
                dailyProteinGrams: dailyTargets.proteinGrams,
                dailyCarbsGrams: dailyTargets.carbsGrams,
                dailyFatGrams: dailyTargets.fatGrams,
                dailyFiberGrams: dailyTargets.fiberGrams,
                dailySugarGrams: dailyTargets.sugarGrams,
              );
    return Scaffold(
      appBar: AppBar(
        title: Text('${_slotEmoji(meal.mealTypeCode)} ${meal.title}'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Dettagli ObjectBox',
            onPressed: _showMealObjectBoxDetails,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      bottomNavigationBar:
          const TtFoodBottomNavBar(activeItem: TtFoodNavItem.none),
      body: ListView(
        padding: _screenPadding,
        children: <Widget>[
          _MealNutritionRecap(
            meal: meal,
            totals: totals,
            target: mealTarget,
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
          TtAppCard(
            onTap: _showMealSettingsDialog,
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.tune_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Pasto libero e impostazioni',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        meal.mealModeCode == 'free'
                            ? 'Configurazione: ${meal.freeMealTrackingCode}'
                            : 'Standard. Tocca per impostare un pasto libero.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Aggiungi voce'),
          const SizedBox(height: AppSpacing.md),
          Column(
            children: <Widget>[
              _MealAddActionCard(
                icon: Icons.inventory_2_outlined,
                title: 'Ingrediente',
                subtitle: 'Cerca alimenti locali e inserisci la grammatura.',
                onTap: _showAddIngredientDialog,
              ),
              const SizedBox(height: AppSpacing.sm),
              _MealAddActionCard(
                icon: Icons.menu_book_rounded,
                title: 'Ricetta',
                subtitle: 'Aggiungi una ricetta salvata come porzione.',
                onTap: _showAddRecipeDialog,
              ),
              const SizedBox(height: AppSpacing.sm),
              _MealAddActionCard(
                icon: Icons.edit_note_rounded,
                title: 'Stima manuale',
                subtitle:
                    'Inserisci calorie e macro quando non hai dati precisi.',
                onTap: _showManualEstimateDialog,
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
                  onTap: () => _showMealItemActions(item),
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

  VoidCallback? _openReferenceForItem(MealItemEntity item) {
    if (item.kindCode == 'ingredient') {
      final IngredientEntity? ingredient =
          ref.read(ingredientRepositoryProvider).findByUuid(item.sourceUuid);
      if (ingredient == null) {
        return null;
      }
      return () => context.push('/food/ingredients/${ingredient.id}');
    }
    if (item.kindCode == 'recipe') {
      final RecipeEntity? recipe = ref
          .read(recipeRepositoryProvider)
          .getAllActive()
          .where((RecipeEntity recipe) => recipe.uuid == item.sourceUuid)
          .firstOrNull;
      if (recipe == null) {
        return null;
      }
      return () => context.push('/food/recipes/${recipe.id}');
    }
    return null;
  }

  Future<void> _showMealItemActions(MealItemEntity item) async {
    final VoidCallback? openReference = _openReferenceForItem(item);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.itemNameSnapshot,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                _ActionSheetCard(
                  icon: Icons.delete_outline_rounded,
                  title: 'Rimuovi',
                  subtitle: 'Elimina questa voce dal pasto.',
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _details = ref
                          .read(foodPlanningServiceProvider)
                          .removeItemAt(_details, item.position);
                    });
                    _invalidateFood(ref);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                _ActionSheetCard(
                  icon: Icons.scale_outlined,
                  title: 'Modifica quantita',
                  subtitle: item.quantityModeCode == 'grams'
                      ? 'Aggiorna i grammi mantenendo lo snapshot.'
                      : 'Aggiorna le porzioni mantenendo lo snapshot.',
                  onTap: () {
                    Navigator.of(context).pop();
                    _showEditMealItemQuantity(item);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                _ActionSheetCard(
                  icon: Icons.open_in_new_rounded,
                  title: 'Apri ingrediente/ricetta',
                  subtitle: openReference == null
                      ? 'Nessun collegamento disponibile.'
                      : 'Apri la scheda collegata.',
                  onTap: openReference == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          openReference();
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditMealItemQuantity(MealItemEntity item) async {
    final bool gramsMode = item.quantityModeCode == 'grams';
    final double current = gramsMode ? item.grams ?? 0 : item.portions ?? 1;
    final TextEditingController controller =
        TextEditingController(text: current <= 0 ? '' : _fmt(current));
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.sm,
              bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Modifica quantita',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                _field(
                  controller,
                  gramsMode ? 'Grammi' : 'Porzioni',
                  keyboardType: TextInputType.number,
                  isRequired: true,
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Annulla'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Salva'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (saved != true) {
      return;
    }
    final double? next = _toDouble(controller.text);
    if (next == null || next <= 0) {
      return;
    }
    final double ratio = current <= 0 ? 1 : next / current;
    final List<MealItemEntity> nextItems = <MealItemEntity>[
      for (final MealItemEntity existing in _details.items)
        if (existing.position == item.position)
          existing
            ..grams = gramsMode ? next : existing.grams
            ..portions = gramsMode ? existing.portions : next
            ..kcal = existing.kcal * ratio
            ..proteinGrams = existing.proteinGrams * ratio
            ..carbsGrams = existing.carbsGrams * ratio
            ..fatGrams = existing.fatGrams * ratio
            ..fiberGrams = existing.fiberGrams * ratio
            ..sugarGrams = existing.sugarGrams * ratio
        else
          existing,
    ];
    setState(() {
      _details = ref
          .read(mealRepositoryProvider)
          .saveMealWithItems(_details.meal, nextItems);
    });
    _invalidateFood(ref);
  }

  Future<void> _showMealSettingsDialog() async {
    final TextEditingController title =
        TextEditingController(text: _details.meal.title);
    String mode = _details.meal.mealModeCode;
    String freeTracking = _details.meal.freeMealTrackingCode.isEmpty
        ? 'tracked'
        : _details.meal.freeMealTrackingCode;
    final TextEditingController freeLabel =
        TextEditingController(text: _details.meal.freeMealLabel);
    final TextEditingController freeNotes =
        TextEditingController(text: _details.meal.freeMealNotes);
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return FractionallySizedBox(
              heightFactor: 0.9,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.sm,
                        AppSpacing.md,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Modifica pasto',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Chiudi',
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(false),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.md,
                        ),
                        children: <Widget>[
                          _TrackingSheetSection(
                            emoji: '🍽️',
                            title: 'Identita',
                            children: <Widget>[
                              _field(title, 'Titolo', isRequired: true),
                              InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Slot',
                                  helperText:
                                      'Lo slot è fisso e non può essere modificato.',
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Text(
                                      _slotEmoji(_details.meal.mealTypeCode),
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        _slotLabel(
                                          _details.meal.mealTypeCode,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    const Icon(Icons.lock_outline_rounded),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          _TrackingSheetSection(
                            emoji: '🎯',
                            title: 'Tipo pasto',
                            children: <Widget>[
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
                                  setSheetState(() => mode = value.first);
                                },
                              ),
                            ],
                          ),
                          if (mode == 'free')
                            _TrackingSheetSection(
                              emoji: '⚠️',
                              title: 'Pasto libero',
                              children: <Widget>[
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
                                      setSheetState(
                                        () => freeTracking = value,
                                      );
                                    }
                                  },
                                ),
                                _field(freeLabel, 'Etichetta'),
                                _field(
                                  freeNotes,
                                  'Note pasto libero',
                                  maxLines: 3,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.md,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(false),
                                child: const Text('Annulla'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(true),
                                icon: const Icon(Icons.save_rounded),
                                label: const Text('Salva'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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

    final List<MealIngredientBatchSelection>? selections =
        await showModalBottomSheet<List<MealIngredientBatchSelection>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext _) {
        return MealIngredientBatchPickerSheet(ingredients: ingredients);
      },
    );
    if (!mounted || selections == null || selections.isEmpty) {
      return;
    }

    MealWithItems next = _details;
    final FoodPlanningService planning = ref.read(foodPlanningServiceProvider);
    for (final MealIngredientBatchSelection selection in selections) {
      next = planning.addIngredientToMeal(
        meal: next,
        ingredient: selection.ingredient,
        grams: selection.grams,
      );
    }
    if (!mounted) return;
    setState(() => _details = next);
    _invalidateFood(ref);
  }

  Future<void> _showAddRecipeDialog() async {
    final List<RecipeEntity> recipes =
        ref.read(recipeRepositoryProvider).getAllActive();
    if (recipes.isEmpty) {
      _snack('Nessuna ricetta salvata.');
      return;
    }
    final _RecipeMealSelection? selection =
        await showModalBottomSheet<_RecipeMealSelection>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext _) {
        return _RecipeMealPickerSheet(recipes: recipes);
      },
    );
    if (selection == null) {
      return;
    }
    setState(() {
      _details = ref.read(foodPlanningServiceProvider).addRecipeToMeal(
            meal: _details,
            recipe: selection.recipe,
            quantityModeCode: selection.quantityModeCode,
            portions: selection.quantityModeCode == 'portions'
                ? selection.quantity
                : 1,
            grams: selection.quantityModeCode == 'grams'
                ? selection.quantity
                : null,
          );
    });
    _invalidateFood(ref);
  }

  Future<void> _showManualEstimateDialog() async {
    final TextEditingController name = TextEditingController();
    final TextEditingController kcal = TextEditingController();
    final TextEditingController protein = TextEditingController();
    final TextEditingController carbs = TextEditingController();
    final TextEditingController fat = TextEditingController();
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.82,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Stima manuale',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Chiudi',
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    children: <Widget>[
                      _TrackingSheetSection(
                        emoji: '📝',
                        title: 'Descrizione',
                        children: <Widget>[
                          _field(name, 'Nome'),
                        ],
                      ),
                      _TrackingSheetSection(
                        emoji: '🔥',
                        title: 'Valori nutrizionali',
                        children: <Widget>[
                          _field(
                            kcal,
                            'Kcal',
                            keyboardType: TextInputType.number,
                          ),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: _field(
                                  protein,
                                  'Proteine g',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _field(
                                  carbs,
                                  'Carboidrati g',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          _field(
                            fat,
                            'Grassi g',
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(false),
                            child: const Text('Annulla'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(true),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Aggiungi'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
  final TextEditingController _brandFilter = TextEditingController();
  List<OpenFoodFactsProduct> _onlineResults = const <OpenFoodFactsProduct>[];
  bool _searchingOnline = false;
  String _onlineError = '';
  int _onlineAttempt = 0;

  @override
  void dispose() {
    _query.dispose();
    _brandFilter.dispose();
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
      bottomNavigationBar:
          const TtFoodBottomNavBar(activeItem: TtFoodNavItem.none),
      body: ingredientsValue.when(
        loading: () => const _LoadingState(),
        error: (Object error, StackTrace stackTrace) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(ingredientArchiveProvider),
        ),
        data: (List<IngredientEntity> ingredients) {
          final String query = _query.text.trim().toLowerCase();
          final String brandQuery = _brandFilter.text.trim().toLowerCase();
          final List<IngredientEntity> filtered =
              ingredients.where((IngredientEntity ingredient) {
            final bool nameMatch = query.isEmpty ||
                ingredient.name.toLowerCase().contains(query) ||
                ingredient.barcode.toLowerCase().contains(query);
            final bool brandMatch = brandQuery.isEmpty ||
                ingredient.brand.toLowerCase().contains(brandQuery);
            return nameMatch && brandMatch;
          }).toList();
          final List<OpenFoodFactsProduct> filteredOnline =
              _onlineResults.where((OpenFoodFactsProduct product) {
            final bool nameMatch = query.isEmpty ||
                product.name.toLowerCase().contains(query) ||
                product.code.toLowerCase().contains(query);
            final bool brandMatch = brandQuery.isEmpty ||
                product.brand.toLowerCase().contains(brandQuery);
            return nameMatch && brandMatch;
          }).toList();
          return ListView(
            padding: _screenPadding,
            children: <Widget>[
              TextField(
                controller: _query,
                decoration: const InputDecoration(
                  labelText: 'Cerca alimento salvato',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _brandFilter,
                decoration: const InputDecoration(
                  labelText: 'Filtra per brand',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
                onChanged: (_) => setState(() {}),
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
                    avatar: _searchingOnline
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.public_rounded),
                    label: Text(_searchingOnline
                        ? 'Ricerca online $_onlineAttempt/20'
                        : 'Cerca online su Open Food Facts'),
                    onPressed: _searchingOnline ? null : _searchOpenFoodFacts,
                  ),
                ],
              ),
              if (_onlineError.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                TtAppCard(
                  child: Text(
                    'Ricerca online non riuscita dopo 20 tentativi: $_onlineError',
                  ),
                ),
              ],
              if (_onlineResults.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.sectionGap),
                const TtSectionHeader(title: 'Open Food Facts'),
                const SizedBox(height: AppSpacing.md),
                if (filteredOnline.isEmpty)
                  const _EmptyInline(
                    message: 'Nessun risultato online con questi filtri.',
                  )
                else
                  for (final OpenFoodFactsProduct product in filteredOnline)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _OnlineProductCard(
                        product: product,
                        onTap: () => _showOpenFoodFactsProductSheet(product),
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
      setState(() {
        _onlineError = 'Inserisci prima un nome alimento o un barcode.';
      });
      return;
    }
    setState(() {
      _searchingOnline = true;
      _onlineError = '';
      _onlineAttempt = 0;
    });
    Object? lastError;
    for (int attempt = 1; attempt <= 20; attempt += 1) {
      if (!mounted) {
        return;
      }
      setState(() => _onlineAttempt = attempt);
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
          setState(() {
            _onlineResults = byText;
            _searchingOnline = false;
            _onlineError = '';
          });
        }
        return;
      } catch (error) {
        lastError = error;
        if (attempt < 20) {
          await Future<void>.delayed(const Duration(milliseconds: 220));
        }
      }
    }
    if (mounted) {
      setState(() {
        _searchingOnline = false;
        _onlineError = lastError.toString();
      });
    }
  }

  Future<void> _showOpenFoodFactsProductSheet(
    OpenFoodFactsProduct product,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _FoodThumb(
                      imageUrl: product.imageUrl,
                      fallbackIcon: Icons.public_rounded,
                      size: 86,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            product.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (product.brand.isNotEmpty)
                            Text(
                              product.brand,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          const SizedBox(height: AppSpacing.xs),
                          _StatusPill(
                            label: product.code.isEmpty
                                ? 'Open Food Facts'
                                : product.code,
                            isWarning: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                _MetricGrid(
                  metrics: <_Metric>[
                    _Metric('Kcal', _fmtKcal(product.kcal100)),
                    _Metric('Proteine', '${_fmt(product.protein100)} g'),
                    _Metric('Carboidrati', '${_fmt(product.carbs100)} g'),
                    _Metric('Grassi', '${_fmt(product.fat100)} g'),
                    _Metric('Fibre', '${_fmt(product.fiber100)} g'),
                    _Metric('Zuccheri', '${_fmt(product.sugar100)} g'),
                  ],
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                TtAppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _detailRow('Quantita', product.quantity),
                      _detailRow('Categorie', product.categories),
                      _detailRow('Fonte', product.sourceUrl),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                TtPrimaryButton(
                  label: 'Importa alimento',
                  icon: Icons.download_done_rounded,
                  onPressed: () {
                    Navigator.of(context).pop();
                    _saveOpenFoodFactsProduct(product);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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
      _resetIngredientSearchState();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} salvato')),
      );
    }
  }

  Future<void> _showManualIngredientDialog() async {
    final _ManualIngredientDraft? draft =
        await showModalBottomSheet<_ManualIngredientDraft>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return _ManualIngredientSheet(
          onPickImage: (TextEditingController controller) => _pickAndStoreImage(
            controller: controller,
            folderName: 'ingredient_images',
            fallbackBaseName: 'ingredient',
          ),
        );
      },
    );

    if (draft == null || !mounted) {
      return;
    }

    ref.read(ingredientRepositoryProvider).save(
          IngredientEntity(
            uuid: '',
            name: draft.name,
            brand: draft.brand,
            barcode: draft.barcode,
            imageUrl: draft.imageUrl,
            kcalPerReference: draft.kcalPerReference,
            proteinPerReference: draft.proteinPerReference,
            carbsPerReference: draft.carbsPerReference,
            fatPerReference: draft.fatPerReference,
            fiberPerReference: draft.fiberPerReference,
            sugarPerReference: draft.sugarPerReference,
            createdAtEpochMs: 0,
            updatedAtEpochMs: 0,
          ),
        );
    ref.invalidate(ingredientArchiveProvider);
    _invalidateFood(ref);
    _resetIngredientSearchState();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${draft.name} salvato')),
    );
  }

  void _resetIngredientSearchState() {
    setState(() {
      _query.clear();
      _brandFilter.clear();
      _onlineResults = const <OpenFoodFactsProduct>[];
      _onlineError = '';
      _onlineAttempt = 0;
      _searchingOnline = false;
    });
  }
}

class _ManualIngredientDraft {
  const _ManualIngredientDraft({
    required this.name,
    required this.brand,
    required this.barcode,
    required this.imageUrl,
    required this.kcalPerReference,
    required this.proteinPerReference,
    required this.carbsPerReference,
    required this.fatPerReference,
    required this.fiberPerReference,
    required this.sugarPerReference,
  });

  final String name;
  final String brand;
  final String barcode;
  final String imageUrl;
  final double kcalPerReference;
  final double proteinPerReference;
  final double carbsPerReference;
  final double fatPerReference;
  final double fiberPerReference;
  final double sugarPerReference;
}

class _ManualIngredientSheet extends StatefulWidget {
  const _ManualIngredientSheet({required this.onPickImage});

  final Future<void> Function(TextEditingController controller) onPickImage;

  @override
  State<_ManualIngredientSheet> createState() => _ManualIngredientSheetState();
}

class _ManualIngredientSheetState extends State<_ManualIngredientSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _brand = TextEditingController();
  final TextEditingController _barcode = TextEditingController();
  final TextEditingController _image = TextEditingController();
  final TextEditingController _kcal = TextEditingController();
  final TextEditingController _protein = TextEditingController();
  final TextEditingController _carbs = TextEditingController();
  final TextEditingController _fat = TextEditingController();
  final TextEditingController _fiber = TextEditingController();
  final TextEditingController _sugar = TextEditingController();

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _name,
      _brand,
      _barcode,
      _image,
      _kcal,
      _protein,
      _carbs,
      _fat,
      _fiber,
      _sugar,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(
      _ManualIngredientDraft(
        name: _name.text.trim(),
        brand: _brand.text.trim(),
        barcode: _barcode.text.trim(),
        imageUrl: _image.text.trim(),
        kcalPerReference: _toDouble(_kcal.text) ?? 0,
        proteinPerReference: _toDouble(_protein.text) ?? 0,
        carbsPerReference: _toDouble(_carbs.text) ?? 0,
        fatPerReference: _toDouble(_fat.text) ?? 0,
        fiberPerReference: _toDouble(_fiber.text) ?? 0,
        sugarPerReference: _toDouble(_sugar.text) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.68,
      maxChildSize: 0.96,
      builder: (
        BuildContext context,
        ScrollController scrollController,
      ) {
        return Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.add_shopping_cart_rounded,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Nuovo alimento',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Aggiunta manuale: compila le sezioni',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chiudi',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _IngredientFormSection(
                icon: Icons.badge_outlined,
                title: 'Informazioni principali',
                subtitle: 'Identità, marca e codice del prodotto.',
                children: <Widget>[
                  _field(_name, 'Nome alimento', isRequired: true),
                  _field(_brand, 'Brand o produttore'),
                  _field(
                    _barcode,
                    'Codice a barre',
                    keyboardType: TextInputType.number,
                    helperText: 'Facoltativo. Deve contenere solo cifre.',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _IngredientFormSection(
                icon: Icons.image_outlined,
                title: 'Immagine',
                subtitle: 'Usa un file locale oppure un URL remoto.',
                children: <Widget>[
                  _ImageSourcePickerField(
                    controller: _image,
                    title: 'Immagine alimento',
                    fallbackIcon: Icons.inventory_2_outlined,
                    onPick: () => widget.onPickImage(_image),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _IngredientFormSection(
                icon: Icons.monitor_heart_outlined,
                title: 'Valori nutrizionali per 100 g',
                subtitle: 'Lascia vuoto ciò che non è disponibile.',
                children: <Widget>[
                  _field(
                    _kcal,
                    'Calorie',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  _field(
                    _protein,
                    'Proteine (g)',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  _field(
                    _carbs,
                    'Carboidrati (g)',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  _field(
                    _fat,
                    'Grassi (g)',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  _field(
                    _fiber,
                    'Fibre (g)',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  _field(
                    _sugar,
                    'Zuccheri (g)',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annulla'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Salva alimento'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IngredientFormSection extends StatelessWidget {
  const _IngredientFormSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: TtAppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: colors.onSecondaryContainer),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ...children,
          ],
        ),
      ),
    );
  }
}

class IngredientDetailScreen extends ConsumerStatefulWidget {
  const IngredientDetailScreen({
    required this.id,
    super.key,
  });

  final String id;

  @override
  ConsumerState<IngredientDetailScreen> createState() =>
      _IngredientDetailScreenState();
}

class _IngredientDetailScreenState
    extends ConsumerState<IngredientDetailScreen> {
  bool _isWorking = false;
  DateTime? _usageFrom;
  DateTime? _usageTo;

  @override
  Widget build(BuildContext context) {
    final int? numericId = int.tryParse(widget.id);
    final IngredientEntity? ingredient = numericId == null
        ? ref.read(ingredientRepositoryProvider).findByUuid(widget.id)
        : ref.read(ingredientRepositoryProvider).getById(numericId);
    if (ingredient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ingrediente')),
        bottomNavigationBar:
            const TtFoodBottomNavBar(activeItem: TtFoodNavItem.none),
        body: const _EmptyInline(message: 'Ingrediente non trovato.'),
      );
    }
    final List<IngredientMealUsage> ingredientUsage =
        ref.read(mealRepositoryProvider).getIngredientUsage(
              ingredient.uuid,
              fromDateKey: _usageFrom == null ? null : _dateKey(_usageFrom!),
              toDateKey: _usageTo == null ? null : _dateKey(_usageTo!),
            );
    final _IngredientUsageStats usageStats = _IngredientUsageStats.fromUsage(
      ingredientUsage,
      from: _usageFrom,
      to: _usageTo,
    );
    final List<IngredientMealUsage> recentUsage =
        ingredientUsage.take(10).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(ingredient.name),
        actions: <Widget>[
          IconButton(
            tooltip: 'Modifica ingrediente',
            onPressed: () async {
              try {
                final bool saved = await _showIngredientEditSheet(
                  context,
                  ref,
                  ingredient,
                  onApplying: () {
                    if (mounted) {
                      setState(() => _isWorking = true);
                    }
                  },
                );
                if (!mounted) {
                  return;
                }
                if (saved) {
                  setState(() {});
                }
              } finally {
                if (mounted) {
                  setState(() => _isWorking = false);
                }
              }
            },
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            tooltip: 'Rimuovi ingrediente',
            onPressed: () => _confirmDeleteIngredient(ingredient),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      bottomNavigationBar:
          const TtFoodBottomNavBar(activeItem: TtFoodNavItem.none),
      body: Stack(
        children: <Widget>[
          ListView(
            padding: _screenPadding,
            children: <Widget>[
              TtAppCard(
                child: Row(
                  children: <Widget>[
                    _FoodThumb(
                      imageUrl: ingredient.imageUrl,
                      fallbackIcon: Icons.inventory_2_outlined,
                      size: 84,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            ingredient.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          if (ingredient.brand.isNotEmpty)
                            Text(
                              ingredient.brand,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          const SizedBox(height: AppSpacing.xs),
                          _StatusPill(
                            label: ingredient.sourceName.isEmpty
                                ? ingredient.sourceTypeCode
                                : ingredient.sourceName,
                            isWarning: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              const TtSectionHeader(title: 'Nutrizione'),
              const SizedBox(height: AppSpacing.md),
              _MetricGrid(
                metrics: <_Metric>[
                  _Metric(
                    'Riferimento',
                    '${_fmt(ingredient.nutritionReferenceAmount)} ${ingredient.baseUnit}',
                  ),
                  _Metric('Calorie', _fmtKcal(ingredient.kcalPerReference)),
                  _Metric(
                      'Proteine', '${_fmt(ingredient.proteinPerReference)} g'),
                  _Metric(
                      'Carboidrati', '${_fmt(ingredient.carbsPerReference)} g'),
                  _Metric('Grassi', '${_fmt(ingredient.fatPerReference)} g'),
                  _Metric('Fibre', '${_fmt(ingredient.fiberPerReference)} g'),
                  _Metric(
                      'Zuccheri', '${_fmt(ingredient.sugarPerReference)} g'),
                  _Metric('Sale', '${_fmt(ingredient.saltPerReference)} g'),
                ],
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              const TtSectionHeader(title: 'Quando l’ho mangiato'),
              const SizedBox(height: AppSpacing.md),
              TtAppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: () => _pickUsageDate(isStart: true),
                          icon: const Icon(Icons.date_range_outlined),
                          label: Text(
                            _usageFrom == null
                                ? 'Data iniziale'
                                : _dateKey(_usageFrom!),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _pickUsageDate(isStart: false),
                          icon: const Icon(Icons.event_outlined),
                          label: Text(
                            _usageTo == null
                                ? 'Data finale'
                                : _dateKey(_usageTo!),
                          ),
                        ),
                        if (_usageFrom != null || _usageTo != null)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _usageFrom = null;
                                _usageTo = null;
                              });
                            },
                            icon: const Icon(Icons.clear_rounded),
                            label: const Text('Azzera'),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MetricGrid(
                      metrics: <_Metric>[
                        _Metric(
                          'Grammi totali',
                          '${_fmt(usageStats.totalGrams)} g',
                        ),
                        _Metric(
                          'Registrazioni',
                          usageStats.registrationCount.toString(),
                        ),
                        _Metric(
                          'Media settimanale',
                          '${_fmt(usageStats.registrationsPerWeek)} / sett.',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (recentUsage.isEmpty)
                const _EmptyInline(
                  message: 'Nessun pasto trovato nell’intervallo selezionato.',
                )
              else
                for (final IngredientMealUsage usage in recentUsage)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: TtAppCard(
                      onTap: () => context.push('/food/meals/${usage.meal.id}'),
                      child: Row(
                        children: <Widget>[
                          CircleAvatar(
                            child: Text(
                              usage.meal.dateKey.length >= 10
                                  ? usage.meal.dateKey.substring(8, 10)
                                  : '•',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  usage.meal.title,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  '${usage.meal.dateKey} · '
                                  '${_slotLabel(usage.meal.mealTypeCode)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                '${_fmt(usage.grams)} g',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (usage.registrationCount > 1)
                                Text(
                                  '${usage.registrationCount} voci',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: AppSpacing.sectionGap),
              const TtSectionHeader(title: 'Dettagli'),
              const SizedBox(height: AppSpacing.md),
              TtAppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _detailRow('Barcode', ingredient.barcode),
                    _detailRow(
                      'Quantità confezione',
                      ingredient.packageQuantity == null
                          ? ''
                          : _fmt(ingredient.packageQuantity!),
                    ),
                    _detailRow('Categorie', ingredient.categories),
                    _detailRow('Fonte', ingredient.sourceUrl),
                    _detailRow('Note', ingredient.notes),
                  ],
                ),
              ),
            ],
          ),
          if (_isWorking)
            Positioned.fill(
              child: ColoredBox(
                color:
                    Theme.of(context).colorScheme.scrim.withValues(alpha: 0.42),
                child: Center(
                  child: TtAppCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const CircularProgressIndicator(),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Aggiorno pasti e ricette...',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickUsageDate({required bool isStart}) async {
    final DateTime initialDate = isStart
        ? (_usageFrom ?? _usageTo ?? DateTime.now())
        : (_usageTo ?? _usageFrom ?? DateTime.now());
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (isStart) {
        _usageFrom = picked;
        if (_usageTo != null && picked.isAfter(_usageTo!)) {
          _usageTo = picked;
        }
      } else {
        _usageTo = picked;
        if (_usageFrom != null && picked.isBefore(_usageFrom!)) {
          _usageFrom = picked;
        }
      }
    });
  }

  Future<void> _confirmDeleteIngredient(IngredientEntity ingredient) async {
    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Rimuovi ingrediente',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${ingredient.name} verrà rimosso dall archivio. I pasti e le ricette esistenti manterranno gli snapshot salvati.',
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('Annulla'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Rimuovi'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _isWorking = true);
    try {
      ref.read(ingredientRepositoryProvider).softDelete(ingredient);
      ref.invalidate(ingredientArchiveProvider);
      _invalidateFood(ref);
      if (!mounted) {
        return;
      }
      context.go('/food/ingredients');
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }
}

class _IngredientUsageStats {
  const _IngredientUsageStats({
    required this.totalGrams,
    required this.registrationCount,
    required this.registrationsPerWeek,
  });

  factory _IngredientUsageStats.fromUsage(
    List<IngredientMealUsage> usage, {
    DateTime? from,
    DateTime? to,
  }) {
    final double totalGrams = usage.fold<double>(
      0,
      (double sum, IngredientMealUsage item) => sum + item.grams,
    );
    final int registrationCount = usage.fold<int>(
      0,
      (int sum, IngredientMealUsage item) => sum + item.registrationCount,
    );
    if (usage.isEmpty) {
      return const _IngredientUsageStats(
        totalGrams: 0,
        registrationCount: 0,
        registrationsPerWeek: 0,
      );
    }

    final List<DateTime> usageDates = usage
        .map((IngredientMealUsage item) => DateTime.parse(item.meal.dateKey))
        .toList()
      ..sort();
    final DateTime rangeStart = from ?? usageDates.first;
    final DateTime rangeEnd = to ?? usageDates.last;
    final int inclusiveDays = rangeEnd.difference(rangeStart).inDays + 1;
    final double weeks = inclusiveDays < 7 ? 1.0 : inclusiveDays / 7;

    return _IngredientUsageStats(
      totalGrams: totalGrams,
      registrationCount: registrationCount,
      registrationsPerWeek:
          weeks <= 0 ? registrationCount.toDouble() : registrationCount / weeks,
    );
  }

  final double totalGrams;
  final int registrationCount;
  final double registrationsPerWeek;
}

class _IngredientSourceSnapshot {
  const _IngredientSourceSnapshot({
    required this.uuid,
    required this.name,
  });

  factory _IngredientSourceSnapshot.from(IngredientEntity ingredient) {
    return _IngredientSourceSnapshot(
      uuid: ingredient.uuid,
      name: ingredient.name,
    );
  }

  final String uuid;
  final String name;
}

Future<bool> _showIngredientEditSheet(
  BuildContext parentContext,
  WidgetRef ref,
  IngredientEntity ingredient, {
  VoidCallback? onApplying,
}) async {
  final _IngredientSourceSnapshot before =
      _IngredientSourceSnapshot.from(ingredient);
  final TextEditingController name =
      TextEditingController(text: ingredient.name);
  final TextEditingController brand =
      TextEditingController(text: ingredient.brand);
  final TextEditingController barcode =
      TextEditingController(text: ingredient.barcode);
  final TextEditingController image =
      TextEditingController(text: ingredient.imageUrl);
  final TextEditingController quantity =
      TextEditingController(text: ingredient.packageQuantity?.toString() ?? '');
  final TextEditingController unit = TextEditingController(
      text: ingredient.baseUnit.trim().isEmpty ? 'g' : ingredient.baseUnit);
  final TextEditingController sourceName =
      TextEditingController(text: ingredient.sourceName);
  final TextEditingController sourceUrl =
      TextEditingController(text: ingredient.sourceUrl);
  final TextEditingController categories =
      TextEditingController(text: ingredient.categories);
  final TextEditingController notes =
      TextEditingController(text: ingredient.notes);
  final TextEditingController kcal =
      TextEditingController(text: ingredient.kcalPerReference.toString());
  final TextEditingController protein =
      TextEditingController(text: ingredient.proteinPerReference.toString());
  final TextEditingController carbs =
      TextEditingController(text: ingredient.carbsPerReference.toString());
  final TextEditingController fat =
      TextEditingController(text: ingredient.fatPerReference.toString());
  final TextEditingController fiber =
      TextEditingController(text: ingredient.fiberPerReference.toString());
  final TextEditingController sugar =
      TextEditingController(text: ingredient.sugarPerReference.toString());
  final TextEditingController salt =
      TextEditingController(text: ingredient.saltPerReference.toString());
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final bool? saved = await showModalBottomSheet<bool>(
    context: parentContext,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) {
      return FractionallySizedBox(
        heightFactor: 0.92,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Modifica ingrediente',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Chiudi',
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Form(
                  key: formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    children: <Widget>[
                      _field(name, 'Nome', isRequired: true),
                      _field(brand, 'Brand'),
                      _field(
                        barcode,
                        'Barcode',
                        suffixIcon: IconButton(
                          tooltip: 'Apri scanner',
                          onPressed: ref
                                  .read(foodServicePreferencesProvider)
                                  .openFoodFactsEnabled
                              ? () {
                                  Navigator.of(sheetContext).pop(false);
                                  parentContext.push('/food/ingredients/scan');
                                }
                              : null,
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                        ),
                      ),
                      _ImageSourcePickerField(
                        controller: image,
                        title: 'Immagine ingrediente',
                        fallbackIcon: Icons.inventory_2_outlined,
                        onPick: () => _pickAndStoreImage(
                          controller: image,
                          folderName: 'ingredient_images',
                          fallbackBaseName: 'ingredient',
                        ),
                      ),
                      _field(
                        quantity,
                        'Quantità confezione',
                        keyboardType: TextInputType.number,
                      ),
                      _field(unit, 'Unità base'),
                      _field(sourceName, 'Fonte'),
                      _field(sourceUrl, 'URL fonte'),
                      _field(categories, 'Categorie'),
                      _field(kcal, 'Kcal per 100 g',
                          keyboardType: TextInputType.number),
                      _field(protein, 'Proteine per 100 g',
                          keyboardType: TextInputType.number),
                      _field(carbs, 'Carboidrati per 100 g',
                          keyboardType: TextInputType.number),
                      _field(fat, 'Grassi per 100 g',
                          keyboardType: TextInputType.number),
                      _field(fiber, 'Fibre per 100 g',
                          keyboardType: TextInputType.number),
                      _field(sugar, 'Zuccheri per 100 g',
                          keyboardType: TextInputType.number),
                      _field(salt, 'Sale per 100 g',
                          keyboardType: TextInputType.number),
                      _field(notes, 'Note', maxLines: 4),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          child: const Text('Annulla'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            if (formKey.currentState?.validate() ?? false) {
                              Navigator.of(sheetContext).pop(true);
                            }
                          },
                          child: const Text('Salva'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (saved != true) {
    return false;
  }
  onApplying?.call();
  ingredient
    ..name = name.text.trim()
    ..brand = brand.text.trim()
    ..barcode = barcode.text.trim()
    ..imageUrl = image.text.trim()
    ..packageQuantity = _toDouble(quantity.text)
    ..baseUnit = unit.text.trim().isEmpty ? 'g' : unit.text.trim()
    ..sourceName = sourceName.text.trim()
    ..sourceUrl = sourceUrl.text.trim()
    ..categories = categories.text.trim()
    ..kcalPerReference = _toDouble(kcal.text) ?? 0
    ..proteinPerReference = _toDouble(protein.text) ?? 0
    ..carbsPerReference = _toDouble(carbs.text) ?? 0
    ..fatPerReference = _toDouble(fat.text) ?? 0
    ..fiberPerReference = _toDouble(fiber.text) ?? 0
    ..sugarPerReference = _toDouble(sugar.text) ?? 0
    ..saltPerReference = _toDouble(salt.text) ?? 0
    ..notes = notes.text.trim();
  ref.read(ingredientRepositoryProvider).save(ingredient);
  _syncIngredientSnapshots(ref, before, ingredient);
  ref.invalidate(ingredientArchiveProvider);
  ref.invalidate(recipeArchiveProvider);
  _invalidateFood(ref);
  if (parentContext.mounted) {
    ScaffoldMessenger.of(parentContext).showSnackBar(
      SnackBar(content: Text('${ingredient.name} aggiornato')),
    );
  }
  return true;
}

void _syncIngredientSnapshots(
  WidgetRef ref,
  _IngredientSourceSnapshot before,
  IngredientEntity ingredient,
) {
  final Store store = ref.read(objectBoxStoreProvider);
  final int now = DateTime.now().millisecondsSinceEpoch;
  store.runInTransaction(TxMode.write, () {
    final Box<MealItemEntity> mealItemBox = store.box<MealItemEntity>();
    final List<MealItemEntity> mealItems = mealItemBox
        .getAll()
        .where(
          (MealItemEntity item) =>
              item.deletedAtEpochMs == null &&
              item.kindCode == 'ingredient' &&
              item.sourceUuid == before.uuid,
        )
        .toList();
    for (final MealItemEntity item in mealItems) {
      final double grams = item.grams ?? ingredient.nutritionReferenceAmount;
      final double factor = ingredient.nutritionReferenceAmount == 0
          ? 0
          : grams / ingredient.nutritionReferenceAmount;
      item
        ..itemNameSnapshot = ingredient.name
        ..kcal = ingredient.kcalPerReference * factor
        ..proteinGrams = ingredient.proteinPerReference * factor
        ..carbsGrams = ingredient.carbsPerReference * factor
        ..fatGrams = ingredient.fatPerReference * factor
        ..fiberGrams = ingredient.fiberPerReference * factor
        ..sugarGrams = ingredient.sugarPerReference * factor
        ..updatedAtEpochMs = now;
    }
    if (mealItems.isNotEmpty) {
      mealItemBox.putMany(mealItems);
    }

    final Box<RecipeIngredientEntity> recipeIngredientBox =
        store.box<RecipeIngredientEntity>();
    final Box<RecipeEntity> recipeBox = store.box<RecipeEntity>();
    final List<RecipeIngredientEntity> recipeIngredients = recipeIngredientBox
        .getAll()
        .where(
          (RecipeIngredientEntity item) =>
              item.deletedAtEpochMs == null &&
              (item.ingredientUuid == before.uuid ||
                  (item.ingredientUuid.trim().isEmpty &&
                      item.nameSnapshot.toLowerCase() ==
                          before.name.toLowerCase())),
        )
        .toList();
    final Set<int> affectedRecipeIds = <int>{};
    for (final RecipeIngredientEntity item in recipeIngredients) {
      final double factor = ingredient.nutritionReferenceAmount == 0
          ? 0
          : item.grams / ingredient.nutritionReferenceAmount;
      item
        ..ingredientUuid = ingredient.uuid
        ..nameSnapshot = ingredient.name
        ..calories = ingredient.kcalPerReference * factor
        ..proteinGrams = ingredient.proteinPerReference * factor
        ..carbsGrams = ingredient.carbsPerReference * factor
        ..fatGrams = ingredient.fatPerReference * factor
        ..fiberGrams = ingredient.fiberPerReference * factor
        ..sugarGrams = ingredient.sugarPerReference * factor
        ..updatedAtEpochMs = now;
      affectedRecipeIds.add(item.recipe.targetId);
    }
    if (recipeIngredients.isNotEmpty) {
      recipeIngredientBox.putMany(recipeIngredients);
    }
    for (final int recipeId in affectedRecipeIds) {
      final RecipeEntity? recipe = recipeBox.get(recipeId);
      if (recipe == null || recipe.deletedAtEpochMs != null) {
        continue;
      }
      final List<RecipeIngredientEntity> ingredients = recipeIngredientBox
          .getAll()
          .where(
            (RecipeIngredientEntity item) =>
                item.recipe.targetId == recipeId &&
                item.deletedAtEpochMs == null,
          )
          .toList();
      _applyRecipeTotals(recipe, ingredients);
      recipe.updatedAtEpochMs = now;
      recipeBox.put(recipe);
    }
  });
}

/*
                    children: <Widget>[
                      Text(
                        ingredient.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (ingredient.brand.isNotEmpty)
                        Text(
                          ingredient.brand,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      _StatusPill(
                        label: ingredient.sourceName.isEmpty
                            ? ingredient.sourceTypeCode
                            : ingredient.sourceName,
                        isWarning: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Nutrizione'),
          const SizedBox(height: AppSpacing.md),
          _MetricGrid(
            metrics: <_Metric>[
              _Metric(
                'Riferimento',
                '${_fmt(ingredient.nutritionReferenceAmount)} ${ingredient.baseUnit}',
              ),
              _Metric('Calorie', _fmtKcal(ingredient.kcalPerReference)),
              _Metric('Proteine', '${_fmt(ingredient.proteinPerReference)} g'),
              _Metric('Carboidrati', '${_fmt(ingredient.carbsPerReference)} g'),
              _Metric('Grassi', '${_fmt(ingredient.fatPerReference)} g'),
              _Metric('Fibre', '${_fmt(ingredient.fiberPerReference)} g'),
              _Metric('Zuccheri', '${_fmt(ingredient.sugarPerReference)} g'),
              _Metric('Sale', '${_fmt(ingredient.saltPerReference)} g'),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Dettagli'),
          const SizedBox(height: AppSpacing.md),
          TtAppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _detailRow('Barcode', ingredient.barcode),
                _detailRow(
                  'Quantità confezione',
                  ingredient.packageQuantity == null
                      ? ''
                      : _fmt(ingredient.packageQuantity!),
                ),
                _detailRow('Categorie', ingredient.categories),
                _detailRow('Fonte', ingredient.sourceUrl),
                _detailRow('Note', ingredient.notes),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> _showIngredientEditDialog(
  BuildContext parentContext,
  WidgetRef ref,
  IngredientEntity ingredient,
) async {
  final TextEditingController name =
      TextEditingController(text: ingredient.name);
  final TextEditingController brand =
      TextEditingController(text: ingredient.brand);
  final TextEditingController barcode =
      TextEditingController(text: ingredient.barcode);
  final TextEditingController image =
      TextEditingController(text: ingredient.imageUrl);
  final TextEditingController quantity =
      TextEditingController(text: ingredient.packageQuantity?.toString() ?? '');
  final TextEditingController unit = TextEditingController(
      text: ingredient.baseUnit.trim().isEmpty ? 'g' : ingredient.baseUnit);
  final TextEditingController sourceName =
      TextEditingController(text: ingredient.sourceName);
  final TextEditingController sourceUrl =
      TextEditingController(text: ingredient.sourceUrl);
  final TextEditingController categories =
      TextEditingController(text: ingredient.categories);
  final TextEditingController notes =
      TextEditingController(text: ingredient.notes);
  final TextEditingController kcal =
      TextEditingController(text: ingredient.kcalPerReference.toString());
  final TextEditingController protein =
      TextEditingController(text: ingredient.proteinPerReference.toString());
  final TextEditingController carbs =
      TextEditingController(text: ingredient.carbsPerReference.toString());
  final TextEditingController fat =
      TextEditingController(text: ingredient.fatPerReference.toString());
  final TextEditingController fiber =
      TextEditingController(text: ingredient.fiberPerReference.toString());
  final TextEditingController sugar =
      TextEditingController(text: ingredient.sugarPerReference.toString());
  final TextEditingController salt =
      TextEditingController(text: ingredient.saltPerReference.toString());
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final bool? saved = await showDialog<bool>(
    context: parentContext,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Modifica ingrediente'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _field(name, 'Nome', isRequired: true),
                _field(brand, 'Brand'),
                _field(
                  barcode,
                  'Barcode',
                  suffixIcon: IconButton(
                    tooltip: 'Apri scanner',
                    onPressed: () {
                      Navigator.of(dialogContext).pop(false);
                      parentContext.push('/food/ingredients/scan');
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                  ),
                ),
                _field(
                  image,
                  'URL o percorso immagine',
                  suffixIcon: IconButton(
                    tooltip: 'Scegli file',
                    onPressed: () {
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Inserisci qui il percorso del file immagine o un URL.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.folder_open_rounded),
                  ),
                ),
                _field(quantity, 'Quantita confezione',
                    keyboardType: TextInputType.number),
                _field(unit, 'Unita base'),
                _field(sourceName, 'Fonte'),
                _field(sourceUrl, 'URL fonte'),
                _field(categories, 'Categorie'),
                _field(kcal, 'Kcal per 100 g',
                    keyboardType: TextInputType.number),
                _field(protein, 'Proteine per 100 g',
                    keyboardType: TextInputType.number),
                _field(carbs, 'Carboidrati per 100 g',
                    keyboardType: TextInputType.number),
                _field(fat, 'Grassi per 100 g',
                    keyboardType: TextInputType.number),
                _field(fiber, 'Fibre per 100 g',
                    keyboardType: TextInputType.number),
                _field(sugar, 'Zuccheri per 100 g',
                    keyboardType: TextInputType.number),
                _field(salt, 'Sale per 100 g',
                    keyboardType: TextInputType.number),
                _field(notes, 'Note', maxLines: 4),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Salva'),
          ),
        ],
      );
    },
  );
  if (saved != true) {
    return false;
  }
  ingredient
    ..name = name.text.trim()
    ..brand = brand.text.trim()
    ..barcode = barcode.text.trim()
    ..imageUrl = image.text.trim()
    ..packageQuantity = _toDouble(quantity.text)
    ..baseUnit = unit.text.trim().isEmpty ? 'g' : unit.text.trim()
    ..sourceName = sourceName.text.trim()
    ..sourceUrl = sourceUrl.text.trim()
    ..categories = categories.text.trim()
    ..kcalPerReference = _toDouble(kcal.text) ?? 0
    ..proteinPerReference = _toDouble(protein.text) ?? 0
    ..carbsPerReference = _toDouble(carbs.text) ?? 0
    ..fatPerReference = _toDouble(fat.text) ?? 0
    ..fiberPerReference = _toDouble(fiber.text) ?? 0
    ..sugarPerReference = _toDouble(sugar.text) ?? 0
    ..saltPerReference = _toDouble(salt.text) ?? 0
    ..notes = notes.text.trim();
  ref.read(ingredientRepositoryProvider).save(ingredient);
  ref.invalidate(ingredientArchiveProvider);
  _invalidateFood(ref);
  if (parentContext.mounted) {
    ScaffoldMessenger.of(parentContext).showSnackBar(
      SnackBar(content: Text('${ingredient.name} aggiornato')),
    );
  }
  return true;
}

*/
class _ManualBarcodeSearchSheet extends StatefulWidget {
  const _ManualBarcodeSearchSheet();

  @override
  State<_ManualBarcodeSearchSheet> createState() =>
      _ManualBarcodeSearchSheetState();
}

class _ManualBarcodeSearchSheetState extends State<_ManualBarcodeSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Cerca tramite barcode',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        'Inserisci manualmente il codice numerico.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.search,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(18),
              ],
              decoration: const InputDecoration(
                labelText: 'Codice a barre',
                prefixIcon: Icon(Icons.qr_code_2_rounded),
                helperText: 'Da 6 a 18 cifre',
              ),
              validator: (String? value) {
                final String clean = value?.trim() ?? '';
                if (!RegExp(r'^\d{6,18}$').hasMatch(clean)) {
                  return 'Inserisci un codice numerico valido';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annulla'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Cerca'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
  final MobileScannerController _scannerController = MobileScannerController();
  bool _handling = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _stopScannerSafely() async {
    try {
      await _scannerController.stop();
    } catch (_) {
      // The controller can already be stopped while a manual search is open.
    }
  }

  Future<void> _startScannerSafely() async {
    try {
      await _scannerController.start();
    } catch (_) {
      // Ignore lifecycle races while the route is closing or resuming.
    }
  }

  Future<void> _processBarcode(String rawCode) async {
    final String code = rawCode.replaceAll(RegExp(r'\s+'), '').trim();
    if (_handling) {
      return;
    }
    if (!RegExp(r'^\d{6,18}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci un codice a barre numerico valido.'),
        ),
      );
      return;
    }

    setState(() => _handling = true);
    await _stopScannerSafely();
    bool completed = false;
    try {
      final OpenFoodFactsProduct? product =
          await ref.read(openFoodFactsServiceProvider).findByBarcode(code);
      if (!mounted) {
        return;
      }
      if (product == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Barcode $code non trovato')),
        );
        return;
      }

      final IngredientEntity ingredient = product.toIngredientEntity();
      final IngredientEntity? existing =
          ref.read(ingredientRepositoryProvider).findByBarcode(product.code);
      if (existing != null) {
        ingredient.id = existing.id;
        ingredient.uuid = existing.uuid;
        ingredient.createdAtEpochMs = existing.createdAtEpochMs;
      }
      ref.read(ingredientRepositoryProvider).save(ingredient);
      ref.invalidate(ingredientArchiveProvider);
      _invalidateFood(ref);
      completed = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${product.name} salvato')),
        );
        context.go('/food/ingredients');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ricerca barcode non riuscita: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _handling = false);
        if (!completed) {
          await _startScannerSafely();
        }
      }
    }
  }

  Future<void> _showManualBarcodeSearch() async {
    if (_handling) {
      return;
    }
    await _stopScannerSafely();
    if (!mounted) {
      return;
    }
    final String? barcode = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return const _ManualBarcodeSearchSheet();
      },
    );
    if (!mounted) {
      return;
    }
    if (barcode == null) {
      await _startScannerSafely();
      return;
    }
    await _processBarcode(barcode);
  }

  @override
  Widget build(BuildContext context) {
    final servicePreferences = ref.watch(foodServicePreferencesProvider);
    if (!servicePreferences.openFoodFactsEnabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scanner barcode')),
        bottomNavigationBar:
            const TtFoodBottomNavBar(activeItem: TtFoodNavItem.none),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: TtAppCard(
              child: Text(
                'Open Food Facts Ã¨ disabilitato nelle impostazioni. '
                'Riabilitalo per usare scanner e ricerca barcode.',
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner barcode'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Cerca inserendo il barcode',
            onPressed: _handling ? null : _showManualBarcodeSearch,
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      bottomNavigationBar:
          const TtFoodBottomNavBar(activeItem: TtFoodNavItem.none),
      body: Stack(
        children: <Widget>[
          MobileScanner(
            controller: _scannerController,
            onDetect: (BarcodeCapture capture) {
              if (_handling) {
                return;
              }
              final String? code = capture.barcodes
                  .map((Barcode item) => item.rawValue)
                  .whereType<String>()
                  .firstOrNull;
              if (code != null && code.trim().isNotEmpty) {
                _processBarcode(code);
              }
            },
          ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.xxxl,
            child: TtAppCard(
              child: Row(
                children: <Widget>[
                  Icon(
                    _handling
                        ? Icons.hourglass_top_rounded
                        : Icons.qr_code_scanner_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      _handling
                          ? 'Ricerca del prodotto su Open Food Facts...'
                          : 'Inquadra il barcode oppure usa la lente in alto '
                              'a destra per inserirlo manualmente.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_handling)
            const Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Color(0x33000000),
                  child: Center(child: CircularProgressIndicator()),
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
      bottomNavigationBar:
          const TtFoodBottomNavBar(activeItem: TtFoodNavItem.none),
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
                onPressed: () => _showCreateRecipeNameDialog(context, ref),
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

Future<void> _showCreateRecipeNameDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final TextEditingController name = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final bool? saved = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Nuova ricetta'),
        content: Form(
          key: formKey,
          child: _field(name, 'Nome ricetta', isRequired: true),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Crea'),
          ),
        ],
      );
    },
  );
  if (saved != true || !context.mounted) {
    return;
  }
  final RecipeEntity recipe = ref.read(recipeRepositoryProvider).save(
        RecipeEntity(
          uuid: '',
          title: name.text.trim(),
          createdAtEpochMs: 0,
          updatedAtEpochMs: 0,
        ),
      );
  ref.invalidate(recipeArchiveProvider);
  context.push('/food/recipes/${recipe.id}');
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
  final TextEditingController _title = TextEditingController();
  final TextEditingController _summary = TextEditingController();
  final TextEditingController _servings = TextEditingController(text: '1');
  final TextEditingController _prep = TextEditingController(text: '0');
  final TextEditingController _cook = TextEditingController(text: '0');
  final TextEditingController _difficulty = TextEditingController(text: 'easy');
  final TextEditingController _kcal = TextEditingController();
  final TextEditingController _yield = TextEditingController();
  final TextEditingController _image = TextEditingController();
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
    _yield.dispose();
    _image.dispose();
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
      _yield.text = _recipe!.yieldGrams?.toString() ?? '';
      _image.text = _recipe!.imagePath;
      _ingredients.text =
          details!.ingredients.map(_encodeRecipeIngredientLine).join('\n');
      _steps.text = details.steps
          .map((RecipeStepEntity step) => step.instruction)
          .join('\n');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id == 'new' ? 'Nuova ricetta' : _title.text),
        actions: <Widget>[
          IconButton(
            tooltip: 'Modifica dati ricetta',
            onPressed: _showRecipeMetaDialog,
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            tooltip: 'Aggiungi ingrediente',
            onPressed: _showAddRecipeIngredientDialog,
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: 'Note e passaggi',
            onPressed: _showRecipeNotesDialog,
            icon: const Icon(Icons.note_alt_outlined),
          ),
          if (_recipe != null)
            IconButton(
              tooltip: 'Elimina ricetta',
              onPressed: _confirmDeleteRecipe,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      bottomNavigationBar:
          const TtFoodBottomNavBar(activeItem: TtFoodNavItem.none),
      body: ListView(
        padding: _screenPadding,
        children: <Widget>[
          TtAppCard(
            child: Row(
              children: <Widget>[
                _FoodThumb(
                  imageUrl: _image.text,
                  fallbackIcon: Icons.menu_book_rounded,
                  size: 84,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _title.text.isEmpty ? 'Ricetta' : _title.text,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (_summary.text.trim().isNotEmpty)
                        Text(
                          _summary.text,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          _MetricGrid(
            metrics: <_Metric>[
              _Metric('Porzioni', _servings.text),
              _Metric(
                'Tempo',
                '${(_toInt(_prep.text) ?? 0) + (_toInt(_cook.text) ?? 0)} min',
              ),
              _Metric('Difficolta', _difficulty.text),
              _Metric(
                'Peso finale',
                _yield.text.trim().isEmpty ? 'n/d' : '${_yield.text} g',
              ),
              _Metric('Kcal totali', _fmtNullableKcal(_recipe?.caloriesTotal)),
              _Metric(
                  'Kcal porzione', _fmtNullableKcal(_recipe?.kcalPerServing)),
              _Metric(
                  'Kcal / 100 g', _fmtNullableKcal(_recipe?.kcalPer100Grams)),
              _Metric(
                'Ingredienti',
                _ingredients.text.trim().isEmpty
                    ? '0'
                    : _ingredients.text.trim().split('\n').length.toString(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Ingredienti'),
          const SizedBox(height: AppSpacing.md),
          if (_ingredients.text.trim().isEmpty)
            const _EmptyInline(message: 'Nessun ingrediente nella ricetta.')
          else
            for (final MapEntry<int, String> entry
                in _ingredients.text.split('\n').asMap().entries)
              if (entry.value.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _RecipeIngredientSnapshotCard(
                    line: entry.value.trim(),
                    imageUrl: _recipeIngredientImage(entry.value.trim()),
                    onTap: () => _showRecipeIngredientActions(
                      entry.key,
                      entry.value.trim(),
                    ),
                  ),
                ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Passaggi'),
          const SizedBox(height: AppSpacing.md),
          if (_steps.text.trim().isEmpty)
            const _EmptyInline(message: 'Nessun passaggio salvato.')
          else
            for (final MapEntry<int, String> entry
                in _steps.text.split('\n').asMap().entries)
              if (entry.value.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: TtAppCard(
                    child: Text('${entry.key + 1}. ${entry.value.trim()}'),
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _showRecipeMetaDialog() async {
    final TextEditingController title =
        TextEditingController(text: _title.text);
    final TextEditingController summary =
        TextEditingController(text: _summary.text);
    final TextEditingController servings =
        TextEditingController(text: _servings.text);
    final TextEditingController prep = TextEditingController(text: _prep.text);
    final TextEditingController cook = TextEditingController(text: _cook.text);
    final TextEditingController difficulty =
        TextEditingController(text: _difficulty.text);
    final TextEditingController yieldController =
        TextEditingController(text: _yield.text);
    final TextEditingController image =
        TextEditingController(text: _image.text);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return _buildRecipeMetaSheet(
          sheetContext: context,
          formKey: formKey,
          title: title,
          summary: summary,
          servings: servings,
          prep: prep,
          cook: cook,
          difficulty: difficulty,
          yieldController: yieldController,
          image: image,
        );
      },
    );
    if (saved != true) {
      return;
    }
    setState(() {
      _title.text = title.text.trim();
      _summary.text = summary.text.trim();
      _servings.text = servings.text.trim();
      _prep.text = prep.text.trim();
      _cook.text = cook.text.trim();
      _difficulty.text = difficulty.text.trim();
      _yield.text = yieldController.text.trim();
      _image.text = image.text.trim();
    });
    _saveRecipe();
  }

  Future<void> _confirmDeleteRecipe() async {
    final RecipeEntity? recipe = _recipe;
    if (recipe == null) {
      return;
    }
    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Elimina ricetta',
                  style: Theme.of(sheetContext).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'La ricetta sparira dall archivio. I pasti dove era gia '
                  'stata inserita manterranno gli snapshot di calorie, macro '
                  'e nome, ma non avranno piu un collegamento apribile.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('Annulla'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Elimina'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    ref.read(recipeRepositoryProvider).softDeleteAndDetachMealItems(recipe);
    ref.invalidate(recipeArchiveProvider);
    _invalidateFood(ref);
    if (mounted) {
      context.go('/food/recipes');
    }
  }

  Future<void> _pickRecipeImage(TextEditingController image) async {
    await _pickAndStoreImage(
      controller: image,
      folderName: 'recipe_images',
      fallbackBaseName: 'recipe',
    );
  }

  Widget _buildRecipeMetaSheet({
    required BuildContext sheetContext,
    required GlobalKey<FormState> formKey,
    required TextEditingController title,
    required TextEditingController summary,
    required TextEditingController servings,
    required TextEditingController prep,
    required TextEditingController cook,
    required TextEditingController difficulty,
    required TextEditingController yieldController,
    required TextEditingController image,
  }) {
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Dati ricetta',
                          style: Theme.of(sheetContext).textTheme.headlineSmall,
                        ),
                        Text(
                          'Modifica titolo, resa e immagine.',
                          style: Theme.of(sheetContext).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chiudi',
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  children: <Widget>[
                    _TrackingSheetSection(
                      emoji: '📘',
                      title: 'Identita',
                      children: <Widget>[
                        _field(title, 'Titolo', isRequired: true),
                        _field(summary, 'Descrizione', maxLines: 3),
                        _ImageSourcePickerField(
                          controller: image,
                          title: 'Immagine ricetta',
                          fallbackIcon: Icons.menu_book_rounded,
                          onPick: () => _pickRecipeImage(image),
                        ),
                      ],
                    ),
                    _TrackingSheetSection(
                      emoji: '⚖️',
                      title: 'Resa e porzioni',
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _field(
                                servings,
                                'Porzioni',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _field(
                                yieldController,
                                'Peso finale g',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    _TrackingSheetSection(
                      emoji: '⏱️',
                      title: 'Preparazione',
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _field(
                                prep,
                                'Preparazione min',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _field(
                                cook,
                                'Cottura min',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        _field(difficulty, 'Difficolta'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('Annulla'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          if (formKey.currentState?.validate() ?? false) {
                            Navigator.of(sheetContext).pop(true);
                          }
                        },
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Applica'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddRecipeIngredientDialog() async {
    final List<IngredientEntity> archive =
        ref.read(ingredientRepositoryProvider).getAllActive();
    if (archive.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun ingrediente disponibile.')),
      );
      return;
    }
    final TextEditingController query = TextEditingController();
    final Set<int> selectedIds = <int>{};
    final Map<int, TextEditingController> gramsControllers =
        <int, TextEditingController>{};
    int step = 0;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final String clean = query.text.trim().toLowerCase();
            final List<IngredientEntity> filtered =
                archive.where((IngredientEntity ingredient) {
              return clean.isEmpty ||
                  ingredient.name.toLowerCase().contains(clean) ||
                  ingredient.brand.toLowerCase().contains(clean);
            }).toList();
            final List<IngredientEntity> selected = archive
                .where((IngredientEntity ingredient) =>
                    selectedIds.contains(ingredient.id))
                .toList();
            for (final IngredientEntity ingredient in selected) {
              gramsControllers.putIfAbsent(
                ingredient.id,
                () => TextEditingController(text: '100'),
              );
            }
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.9,
              minChildSize: 0.35,
              maxChildSize: 0.96,
              builder: (BuildContext context, ScrollController controller) {
                return SafeArea(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              step == 0
                                  ? 'Ingredienti ricetta'
                                  : 'Grammature ricetta',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          _StatusPill(
                            label: '${selectedIds.length} selezionati',
                            isWarning: selectedIds.isEmpty,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                if (step == 1) {
                                  setSheetState(() => step = 0);
                                } else {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                              icon: Icon(step == 1
                                  ? Icons.arrow_back_rounded
                                  : Icons.keyboard_arrow_down),
                              label: Text(step == 1 ? 'Indietro' : 'Chiudi'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: selectedIds.isEmpty
                                  ? null
                                  : () {
                                      if (step == 0) {
                                        setSheetState(() => step = 1);
                                      } else {
                                        _appendRecipeIngredients(
                                          selected,
                                          gramsControllers,
                                        );
                                        Navigator.of(sheetContext).pop();
                                      }
                                    },
                              icon: Icon(step == 0
                                  ? Icons.arrow_forward_rounded
                                  : Icons.check_rounded),
                              label: Text(step == 0 ? 'Continua' : 'Conferma'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (step == 0) ...<Widget>[
                        TextField(
                          controller: query,
                          decoration: const InputDecoration(
                            labelText: 'Cerca archivio ingredienti',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        for (final IngredientEntity ingredient in filtered)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: TtAppCard(
                              onTap: () {
                                setSheetState(() {
                                  if (selectedIds.contains(ingredient.id)) {
                                    selectedIds.remove(ingredient.id);
                                  } else {
                                    selectedIds.add(ingredient.id);
                                    gramsControllers.putIfAbsent(
                                      ingredient.id,
                                      () => TextEditingController(text: '100'),
                                    );
                                  }
                                });
                              },
                              child: Row(
                                children: <Widget>[
                                  _FoodThumb(
                                    imageUrl: ingredient.imageUrl,
                                    fallbackIcon: Icons.inventory_2_outlined,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          ingredient.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        Text(
                                          ingredient.brand,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    selectedIds.contains(ingredient.id)
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    color: selectedIds.contains(ingredient.id)
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.outline,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ] else ...<Widget>[
                        for (final IngredientEntity ingredient in selected)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: TtAppCard(
                              child: Row(
                                children: <Widget>[
                                  Expanded(child: Text(ingredient.name)),
                                  SizedBox(
                                    width: 110,
                                    child: TextField(
                                      controller:
                                          gramsControllers[ingredient.id],
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'g',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: AppSpacing.sectionGap),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                if (step == 1) {
                                  setSheetState(() => step = 0);
                                } else {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                              icon: Icon(step == 1
                                  ? Icons.arrow_back_rounded
                                  : Icons.keyboard_arrow_down),
                              label: Text(step == 1 ? 'Indietro' : 'Chiudi'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: selectedIds.isEmpty
                                  ? null
                                  : () {
                                      if (step == 0) {
                                        setSheetState(() => step = 1);
                                      } else {
                                        _appendRecipeIngredients(
                                          selected,
                                          gramsControllers,
                                        );
                                        Navigator.of(sheetContext).pop();
                                      }
                                    },
                              icon: Icon(step == 0
                                  ? Icons.arrow_forward_rounded
                                  : Icons.check_rounded),
                              label: Text(step == 0 ? 'Continua' : 'Conferma'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _appendRecipeIngredients(
    List<IngredientEntity> selected,
    Map<int, TextEditingController> gramsControllers,
  ) {
    final List<String> lines = <String>[];
    for (final IngredientEntity ingredient in selected) {
      final double gramsValue =
          _toDouble(gramsControllers[ingredient.id]?.text ?? '') ?? 100;
      final double safeGrams = gramsValue <= 0 ? 100 : gramsValue;
      final double factor = ingredient.nutritionReferenceAmount == 0
          ? 0
          : safeGrams / ingredient.nutritionReferenceAmount;
      lines.add(<String>[
        ingredient.name,
        _fmt(safeGrams),
        _fmt(ingredient.kcalPerReference * factor),
        _fmt(ingredient.proteinPerReference * factor),
        _fmt(ingredient.carbsPerReference * factor),
        _fmt(ingredient.fatPerReference * factor),
        ingredient.uuid,
      ].join(' | '));
    }
    setState(() {
      final String current = _ingredients.text.trim();
      _ingredients.text =
          current.isEmpty ? lines.join('\n') : '$current\n${lines.join('\n')}';
    });
    _saveRecipe();
  }

  String _recipeIngredientImage(String line) {
    final RecipeIngredientEntity item = _recipeIngredientFromLine(line);
    if (item.ingredientUuid.trim().isEmpty) {
      return '';
    }
    return ref
            .read(ingredientRepositoryProvider)
            .findByUuid(item.ingredientUuid)
            ?.imageUrl ??
        '';
  }

  Future<void> _showRecipeIngredientActions(int index, String line) async {
    final RecipeIngredientEntity item = _recipeIngredientFromLine(line);
    final IngredientEntity? ingredient = item.ingredientUuid.trim().isNotEmpty
        ? ref.read(ingredientRepositoryProvider).findByUuid(item.ingredientUuid)
        : ref
            .read(ingredientRepositoryProvider)
            .getAllActive()
            .where((IngredientEntity ingredient) {
            return ingredient.name.toLowerCase() ==
                item.nameSnapshot.toLowerCase();
          }).firstOrNull;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.nameSnapshot,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                _ActionSheetCard(
                  icon: Icons.delete_outline_rounded,
                  title: 'Rimuovi',
                  subtitle: 'Elimina questo ingrediente dalla ricetta',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _removeRecipeIngredientAt(index);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                _ActionSheetCard(
                  icon: Icons.scale_outlined,
                  title: 'Modifica quantita',
                  subtitle: '${_fmt(item.grams)} g',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _editRecipeIngredientGrams(index, item);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                _ActionSheetCard(
                  icon: Icons.open_in_new_rounded,
                  title: 'Apri ingrediente',
                  subtitle: ingredient == null
                      ? 'Non trovato nell archivio locale'
                      : ingredient.name,
                  onTap: ingredient == null
                      ? null
                      : () {
                          Navigator.of(sheetContext).pop();
                          context.push('/food/ingredients/${ingredient.id}');
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _removeRecipeIngredientAt(int index) {
    final List<String> lines = _ingredients.text
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();
    if (index < 0 || index >= lines.length) {
      return;
    }
    lines.removeAt(index);
    setState(() => _ingredients.text = lines.join('\n'));
    _saveRecipe();
  }

  Future<void> _editRecipeIngredientGrams(
    int index,
    RecipeIngredientEntity item,
  ) async {
    final TextEditingController grams =
        TextEditingController(text: _fmt(item.grams));
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _field(
                grams,
                'Grammatura',
                keyboardType: TextInputType.number,
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: const Text('Annulla'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: const Text('Salva'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (saved != true) {
      return;
    }
    final double nextGrams = _toDouble(grams.text) ?? item.grams;
    if (nextGrams <= 0 || item.grams <= 0) {
      return;
    }
    final double ratio = nextGrams / item.grams;
    final RecipeIngredientEntity updated = RecipeIngredientEntity(
      uuid: '',
      ingredientUuid: item.ingredientUuid,
      nameSnapshot: item.nameSnapshot,
      grams: nextGrams,
      calories: item.calories * ratio,
      proteinGrams: item.proteinGrams * ratio,
      carbsGrams: item.carbsGrams * ratio,
      fatGrams: item.fatGrams * ratio,
      fiberGrams: item.fiberGrams * ratio,
      sugarGrams: item.sugarGrams * ratio,
      createdAtEpochMs: 0,
      updatedAtEpochMs: 0,
    );
    final List<String> lines = _ingredients.text
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();
    if (index < 0 || index >= lines.length) {
      return;
    }
    lines[index] = _encodeRecipeIngredientLine(updated);
    setState(() => _ingredients.text = lines.join('\n'));
    _saveRecipe();
  }

  Future<void> _showRecipeNotesDialog() async {
    final List<String>? savedSteps = await showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return _RecipeStepsSheet(
          initialSteps: _steps.text
              .split('\n')
              .map((String line) => line.trim())
              .where((String line) => line.isNotEmpty)
              .toList(),
        );
      },
    );
    if (savedSteps != null) {
      setState(() => _steps.text = savedSteps.join('\n'));
      _saveRecipe();
    }
  }

  void _saveRecipe() {
    if (_title.text.trim().isEmpty) {
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
    recipe.yieldGrams = _toDouble(_yield.text);
    recipe.imagePath = _image.text.trim();
    final List<RecipeIngredientEntity> ingredients = _ingredients.text
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .map(_recipeIngredientFromLine)
        .toList();
    _applyRecipeTotals(recipe, ingredients);
    _kcal.text = recipe.kcalPerServing?.toStringAsFixed(0) ?? '';
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
    _recipe = saved.recipe;
    _kcal.text = saved.recipe.kcalPerServing?.toStringAsFixed(0) ?? '';
    ref.invalidate(recipeArchiveProvider);
    if (mounted) {
      setState(() {});
    }
  }
}

String _encodeRecipeIngredientLine(RecipeIngredientEntity item) {
  return <String>[
    item.nameSnapshot,
    _fmt(item.grams),
    _fmt(item.calories),
    _fmt(item.proteinGrams),
    _fmt(item.carbsGrams),
    _fmt(item.fatGrams),
    item.ingredientUuid,
  ].join(' | ');
}

RecipeIngredientEntity _recipeIngredientFromLine(String line) {
  final List<String> parts =
      line.split('|').map((String part) => part.trim()).toList();
  double valueAt(int index) {
    if (index >= parts.length) {
      return 0;
    }
    return _toDouble(parts[index]) ?? 0;
  }

  return RecipeIngredientEntity(
    uuid: '',
    ingredientUuid: parts.length > 6 ? parts[6] : '',
    nameSnapshot: parts.isEmpty ? line : parts.first,
    grams: valueAt(1),
    calories: valueAt(2),
    proteinGrams: valueAt(3),
    carbsGrams: valueAt(4),
    fatGrams: valueAt(5),
    createdAtEpochMs: 0,
    updatedAtEpochMs: 0,
  );
}

void _applyRecipeTotals(
  RecipeEntity recipe,
  List<RecipeIngredientEntity> ingredients,
) {
  double kcal = 0;
  double protein = 0;
  double carbs = 0;
  double fat = 0;
  double fiber = 0;
  double sugar = 0;
  double inputWeight = 0;
  for (final RecipeIngredientEntity ingredient in ingredients) {
    kcal += ingredient.calories;
    protein += ingredient.proteinGrams;
    carbs += ingredient.carbsGrams;
    fat += ingredient.fatGrams;
    fiber += ingredient.fiberGrams;
    sugar += ingredient.sugarGrams;
    inputWeight += ingredient.grams;
  }
  recipe
    ..totalWeightGrams = inputWeight == 0 ? null : inputWeight
    ..caloriesTotal = kcal == 0 ? null : kcal
    ..proteinTotalGrams = protein == 0 ? null : protein
    ..carbsTotalGrams = carbs == 0 ? null : carbs
    ..fatTotalGrams = fat == 0 ? null : fat
    ..fiberTotalGrams = fiber == 0 ? null : fiber
    ..sugarTotalGrams = sugar == 0 ? null : sugar
    ..kcalPerServing =
        kcal == 0 ? null : kcal / (recipe.servings <= 0 ? 1 : recipe.servings);
  final double? yield = recipe.yieldGrams;
  if (yield != null && yield > 0) {
    recipe
      ..kcalPer100Grams = kcal == 0 ? null : kcal / yield * 100
      ..proteinPer100Grams = protein == 0 ? null : protein / yield * 100
      ..carbsPer100Grams = carbs == 0 ? null : carbs / yield * 100
      ..fatPer100Grams = fat == 0 ? null : fat / yield * 100;
  } else {
    recipe
      ..kcalPer100Grams = null
      ..proteinPer100Grams = null
      ..carbsPer100Grams = null
      ..fatPer100Grams = null;
  }
}

class _MonthCalendarCard extends StatefulWidget {
  const _MonthCalendarCard({
    required this.reference,
    required this.days,
    required this.meals,
    required this.adaptiveSummary,
  });

  final DateTime reference;
  final List<DailyRecordEntity> days;
  final List<MealWithItems> meals;
  final WeekAdaptiveSummary adaptiveSummary;

  @override
  State<_MonthCalendarCard> createState() => _MonthCalendarCardState();
}

class _MonthCalendarCardState extends State<_MonthCalendarCard> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(widget.reference.year, widget.reference.month);
  }

  @override
  void didUpdateWidget(covariant _MonthCalendarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference.year != widget.reference.year ||
        oldWidget.reference.month != widget.reference.month) {
      _visibleMonth = DateTime(widget.reference.year, widget.reference.month);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime month = _visibleMonth;
    final DateTime firstDay = DateTime(month.year, month.month);
    final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final int leadingEmptyCells = firstDay.weekday - 1;
    final Map<String, DailyRecordEntity> byDate = <String, DailyRecordEntity>{
      for (final DailyRecordEntity day in widget.days) day.dateKey: day,
    };
    final Map<String, List<MealWithItems>> mealsByDate =
        <String, List<MealWithItems>>{};
    for (final MealWithItems meal in widget.meals) {
      mealsByDate.putIfAbsent(meal.meal.dateKey, () => <MealWithItems>[]);
      mealsByDate[meal.meal.dateKey]!.add(meal);
    }
    return TtAppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '🗓️ Calendario',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Mese precedente',
                onPressed: () {
                  setState(() {
                    _visibleMonth = DateTime(month.year, month.month - 1);
                  });
                },
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                '${month.month.toString().padLeft(2, '0')}/${month.year}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              IconButton(
                tooltip: 'Mese successivo',
                onPressed: () {
                  setState(() {
                    _visibleMonth = DateTime(month.year, month.month + 1);
                  });
                },
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/food/week'),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.view_week_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Settimana corrente',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${_dateKey(widget.adaptiveSummary.monday)} - ${_dateKey(widget.adaptiveSummary.sunday)}',
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
          ),
          const SizedBox(height: AppSpacing.md),
          const Row(
            children: <Widget>[
              _WeekdayHeader('L'),
              _WeekdayHeader('M'),
              _WeekdayHeader('M'),
              _WeekdayHeader('G'),
              _WeekdayHeader('V'),
              _WeekdayHeader('S'),
              _WeekdayHeader('D'),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 0.94,
            children: <Widget>[
              for (int index = 0; index < leadingEmptyCells; index += 1)
                const SizedBox.shrink(),
              for (int dayNumber = 1; dayNumber <= daysInMonth; dayNumber += 1)
                Builder(
                  builder: (BuildContext context) {
                    final DateTime date =
                        DateTime(month.year, month.month, dayNumber);
                    final String dateKey = _dateKey(date);
                    final DailyRecordEntity? day = byDate[dateKey];
                    final List<MealWithItems> meals =
                        mealsByDate[dateKey] ?? const <MealWithItems>[];
                    final bool hasFood = meals.any(
                      (MealWithItems meal) => meal.items.isNotEmpty,
                    );
                    final bool hasFreeMeal = meals.any(
                      (MealWithItems meal) => meal.meal.mealModeCode == 'free',
                    );
                    final bool hasCompleteMeals = _hasAllMealSlotsLogged(meals);
                    return _CalendarDayCell(
                      date: date,
                      day: day,
                      hasFood: hasFood,
                      hasCompleteMeals: hasCompleteMeals,
                      hasFreeMeal: hasFreeMeal,
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              _CalendarLegendItem(color: Colors.green, label: '4/4 pasti'),
              _CalendarLegendItem(color: Colors.amber, label: 'Parziale'),
              _CalendarLegendItem(color: Colors.red, label: 'Pasto libero'),
            ],
          ),
        ],
      ),
    );
  }
}

// Retained temporarily for compatibility with the legacy weekly presentation.

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.day,
    this.hasFood = false,
    this.hasCompleteMeals = false,
    this.hasFreeMeal = false,
  });

  final DateTime date;
  final DailyRecordEntity? day;
  final bool hasFood;
  final bool hasCompleteMeals;
  final bool hasFreeMeal;

  @override
  Widget build(BuildContext context) {
    final String dateKey = _dateKey(date);
    final bool hasData = day != null;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool canColorByNutrition = hasFood || hasFreeMeal;
    final Color fillColor = hasFreeMeal
        ? colors.errorContainer.withValues(alpha: 0.88)
        : canColorByNutrition && hasCompleteMeals
            ? colors.primaryContainer.withValues(alpha: 0.88)
            : canColorByNutrition
                ? Colors.amber.withValues(alpha: 0.34)
                : colors.surfaceContainerHighest.withValues(alpha: 0.72);
    final Color borderColor = hasFreeMeal
        ? colors.error
        : canColorByNutrition && hasCompleteMeals
            ? colors.primary
            : canColorByNutrition
                ? Colors.amber.shade700
                : colors.outlineVariant;
    final Color textColor = hasFreeMeal
        ? colors.onErrorContainer
        : canColorByNutrition && hasCompleteMeals
            ? colors.onPrimaryContainer
            : colors.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/food/days/$dateKey'),
        child: Ink(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.all(6),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    date.day.toString(),
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: hasData ? textColor : colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
              if (hasFood)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox.square(
                    dimension: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: borderColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}

class _CalendarLegendItem extends StatelessWidget {
  const _CalendarLegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox.square(
          dimension: 10,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.82),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
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
    required this.onTap,
  });

  final MealItemEntity item;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      onTap: onTap,
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
                  '${_mealItemQuantityText(item)} - ${_fmtKcal(item.kcal)} - ${_fmt(item.proteinGrams)}P ${_fmt(item.carbsGrams)}C ${_fmt(item.fatGrams)}F',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.more_horiz_rounded),
        ],
      ),
    );
  }
}

class _MealAddActionCard extends StatelessWidget {
  const _MealAddActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            child: Icon(icon),
          ),
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

class _MealNutritionRecap extends StatelessWidget {
  const _MealNutritionRecap({
    required this.meal,
    required this.totals,
    required this.target,
  });

  final MealEntity meal;
  final MealNutritionTotals totals;
  final MealNutrientTarget target;

  @override
  Widget build(BuildContext context) {
    final double? kcalTarget = target.kcal;
    final double kcalProgress = kcalTarget == null || kcalTarget <= 0
        ? 0
        : (totals.kcal / kcalTarget).clamp(0, 1).toDouble();
    return TtAppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                radius: 25,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
                child: Text(
                  _slotEmoji(meal.mealTypeCode),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      meal.title.trim().isEmpty
                          ? _slotLabel(meal.mealTypeCode)
                          : meal.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${_slotLabel(meal.mealTypeCode)} - ${meal.dateKey}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        _StatusPill(
                          label: meal.mealModeCode == 'free'
                              ? 'Pasto libero'
                              : 'Standard',
                          isWarning: meal.mealModeCode == 'free',
                        ),
                        if (target.hasAny)
                          const _StatusPill(
                            label: 'Target attivo',
                            isWarning: false,
                          ),
                        if (meal.mealModeCode == 'free')
                          _StatusPill(
                            label: meal.freeMealTrackingCode.isEmpty
                                ? 'Tracking n/d'
                                : meal.freeMealTrackingCode,
                            isWarning: meal.freeMealTrackingCode == 'untracked',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Calorie${_mealPercentSuffix(target.percentages.kcalPercent)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                kcalTarget == null
                    ? '${totals.kcal.round()} kcal'
                    : '${totals.kcal.round()} / ${kcalTarget.round()} kcal',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          if (kcalTarget != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: kcalProgress,
                minHeight: 10,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const _SummaryDivider(),
          const SizedBox(height: AppSpacing.md),
          _MealMacroRow(
            label: 'Proteine',
            value: totals.proteinGrams,
            target: target.proteinGrams,
            percent: target.percentages.proteinPercent,
          ),
          _MealMacroRow(
            label: 'Carboidrati',
            value: totals.carbsGrams,
            target: target.carbsGrams,
            percent: target.percentages.carbsPercent,
          ),
          _MealMacroRow(
            label: 'Grassi',
            value: totals.fatGrams,
            target: target.fatGrams,
            percent: target.percentages.fatPercent,
          ),
          _MealMacroRow(
            label: 'Fibre',
            value: totals.fiberGrams,
            target: target.fiberGrams,
            percent: target.percentages.fiberPercent,
          ),
          _MealMacroRow(
            label: 'Zuccheri totali · nessun limite automatico',
            value: totals.sugarGrams,
          ),
        ],
      ),
    );
  }
}

String _mealPercentSuffix(double? value) {
  if (value == null) {
    return '';
  }
  final String formatted = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return ' · $formatted%';
}

class _MealMacroRow extends StatelessWidget {
  const _MealMacroRow({
    required this.label,
    required this.value,
    this.target,
    this.percent,
  });

  final String label;
  final double value;
  final double? target;
  final double? percent;

  @override
  Widget build(BuildContext context) {
    final double? cleanTarget = target != null && target! > 0 ? target : null;
    final double progress =
        cleanTarget == null ? 0 : (value / cleanTarget).clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('$label${_mealPercentSuffix(percent)}')),
              Text(
                cleanTarget == null
                    ? '${_fmt(value)} g'
                    : '${_fmt(value)} / ${_fmt(cleanTarget)} g',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (cleanTarget != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecipeMealSelection {
  const _RecipeMealSelection({
    required this.recipe,
    required this.quantityModeCode,
    required this.quantity,
  });

  final RecipeEntity recipe;
  final String quantityModeCode;
  final double quantity;
}

class _RecipeMealPickerSheet extends StatefulWidget {
  const _RecipeMealPickerSheet({required this.recipes});

  final List<RecipeEntity> recipes;

  @override
  State<_RecipeMealPickerSheet> createState() => _RecipeMealPickerSheetState();
}

class _RecipeMealPickerSheetState extends State<_RecipeMealPickerSheet> {
  final TextEditingController _query = TextEditingController();
  final TextEditingController _quantity = TextEditingController(text: '1');
  RecipeEntity? _selected;
  String _difficultyFilter = 'all';
  String _quantityModeCode = 'portions';

  @override
  void dispose() {
    _query.dispose();
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> difficultyFilters = widget.recipes
        .map((RecipeEntity recipe) => recipe.difficultyCode.trim())
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final String clean = _query.text.trim().toLowerCase();
    final List<RecipeEntity> filtered = widget.recipes.where(
      (RecipeEntity recipe) {
        final bool matchesText = clean.isEmpty ||
            recipe.title.toLowerCase().contains(clean) ||
            recipe.subtitle.toLowerCase().contains(clean) ||
            recipe.summary.toLowerCase().contains(clean);
        final bool matchesDifficulty = _difficultyFilter == 'all' ||
            recipe.difficultyCode == _difficultyFilter;
        return matchesText && matchesDifficulty;
      },
    ).toList();
    final List<String> modes = _selected == null
        ? const <String>['portions']
        : _recipeQuantityModes(_selected!);
    final String? visibleQuantityMode = modes.contains(_quantityModeCode)
        ? _quantityModeCode
        : modes.isEmpty
            ? null
            : modes.first;
    final double quantity = _toDouble(_quantity.text) ?? 0;
    final bool canAdd = _selected != null && modes.isNotEmpty && quantity > 0;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.36,
      maxChildSize: 0.96,
      builder: (BuildContext context, ScrollController scrollController) {
        return SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Aggiungi ricetta',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            _selected == null
                                ? 'Scegli una ricetta salvata.'
                                : _selected!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Chiudi',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey<String>(
                              'recipe-meal-mode-${_selected?.id ?? 0}-'
                              '${visibleQuantityMode ?? 'none'}',
                            ),
                            initialValue: visibleQuantityMode,
                            decoration: const InputDecoration(
                              labelText: 'Modalita',
                            ),
                            items: <DropdownMenuItem<String>>[
                              if (modes.contains('portions'))
                                const DropdownMenuItem<String>(
                                  value: 'portions',
                                  child: Text('Porzioni'),
                                ),
                              if (modes.contains('grams'))
                                const DropdownMenuItem<String>(
                                  value: 'grams',
                                  child: Text('Grammi'),
                                ),
                            ],
                            onChanged: modes.isEmpty
                                ? null
                                : (String? value) {
                                    if (value == null) {
                                      return;
                                    }
                                    setState(() {
                                      _quantityModeCode = value;
                                      _quantity.text =
                                          value == 'grams' ? '100' : '1';
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TextField(
                            controller: _quantity,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: _quantityModeCode == 'grams'
                                  ? 'Grammi'
                                  : 'Quantita',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    if (_selected != null && modes.isEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Questa ricetta non ha porzioni valide ne peso finale: non puo essere aggiunta.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: canAdd
                            ? () => Navigator.of(context).pop(
                                  _RecipeMealSelection(
                                    recipe: _selected!,
                                    quantityModeCode: _quantityModeCode,
                                    quantity: quantity,
                                  ),
                                )
                            : null,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Aggiungi'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _query,
                      decoration: const InputDecoration(
                        labelText: 'Cerca per nome o descrizione',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: ChoiceChip(
                        label: const Text('Tutte'),
                        selected: _difficultyFilter == 'all',
                        onSelected: (_) {
                          setState(() => _difficultyFilter = 'all');
                        },
                      ),
                    ),
                    for (final String code in difficultyFilters)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: ChoiceChip(
                          label: Text(_recipeDifficultyLabel(code)),
                          selected: _difficultyFilter == code,
                          onSelected: (_) {
                            setState(() => _difficultyFilter = code);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: _EmptyInline(
                          message: 'Nessuna ricetta trovata.',
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (BuildContext context, int index) {
                          final RecipeEntity recipe = filtered[index];
                          final bool isSelected = _selected?.id == recipe.id;
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: TtAppCard(
                              onTap: () {
                                setState(() {
                                  _selected = recipe;
                                  final List<String> nextModes =
                                      _recipeQuantityModes(recipe);
                                  _quantityModeCode =
                                      nextModes.contains(_quantityModeCode)
                                          ? _quantityModeCode
                                          : nextModes.isEmpty
                                              ? 'portions'
                                              : nextModes.first;
                                  _quantity.text = _quantityModeCode == 'grams'
                                      ? '100'
                                      : '1';
                                });
                              },
                              child: Row(
                                children: <Widget>[
                                  _FoodThumb(
                                    imageUrl: recipe.imagePath,
                                    fallbackIcon: Icons.menu_book_rounded,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          recipe.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        Text(
                                          _recipeQuantitySummary(recipe),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                        Text(
                                          recipe.kcalPerServing == null
                                              ? 'Kcal n/d'
                                              : '${_fmtKcal(recipe.kcalPerServing!)} per porzione',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.outline,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecipeIngredientSnapshotCard extends StatelessWidget {
  const _RecipeIngredientSnapshotCard({
    required this.line,
    required this.imageUrl,
    required this.onTap,
  });

  final String line;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final RecipeIngredientEntity item = _recipeIngredientFromLine(line);
    return TtAppCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          _FoodThumb(
            imageUrl: imageUrl,
            fallbackIcon: Icons.inventory_2_outlined,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.nameSnapshot,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${_fmt(item.grams)} g - ${_fmtKcal(item.calories)} - ${_fmt(item.proteinGrams)}P ${_fmt(item.carbsGrams)}C ${_fmt(item.fatGrams)}F',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.more_horiz_rounded),
        ],
      ),
    );
  }
}

class _ActionSheetCard extends StatelessWidget {
  const _ActionSheetCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      onTap: onTap,
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

Future<void> _pickAndStoreImage({
  required TextEditingController controller,
  required String folderName,
  required String fallbackBaseName,
}) async {
  final FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
    withData: false,
  );
  final String? selectedPath = result?.files.single.path;
  if (selectedPath == null || selectedPath.trim().isEmpty) {
    return;
  }

  final File source = File(selectedPath);
  if (!source.existsSync()) {
    return;
  }

  final Directory documents = await getApplicationDocumentsDirectory();
  final Directory imageDir = Directory(path.join(documents.path, folderName));
  if (!imageDir.existsSync()) {
    imageDir.createSync(recursive: true);
  }

  final String safeName = path
      .basenameWithoutExtension(selectedPath)
      .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
  final String extension = path.extension(selectedPath);
  final String fileName = '${DateTime.now().millisecondsSinceEpoch}_'
      '${safeName.isEmpty ? fallbackBaseName : safeName}$extension';
  final File target = File(path.join(imageDir.path, fileName));
  await source.copy(target.path);
  controller.text = target.path;
}

class _ImageSourcePickerField extends StatelessWidget {
  const _ImageSourcePickerField({
    required this.controller,
    required this.title,
    required this.fallbackIcon,
    required this.onPick,
  });

  final TextEditingController controller;
  final String title;
  final IconData fallbackIcon;
  final Future<void> Function() onPick;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (BuildContext context, TextEditingValue value, _) {
        final String imageSource = value.text.trim();
        final Color errorColor = Theme.of(context).colorScheme.error;
        return TtAppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _FoodThumb(
                    imageUrl: imageSource,
                    fallbackIcon: fallbackIcon,
                    size: 64,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'URL immagine o percorso locale',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  FilledButton.tonalIcon(
                    onPressed: onPick,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Scegli file'),
                  ),
                  if (imageSource.isNotEmpty)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: errorColor,
                        side: BorderSide(color: errorColor),
                      ),
                      onPressed: controller.clear,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Rimuovi immagine'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecipeStepsSheet extends StatefulWidget {
  const _RecipeStepsSheet({required this.initialSteps});

  final List<String> initialSteps;

  @override
  State<_RecipeStepsSheet> createState() => _RecipeStepsSheetState();
}

class _RecipeStepsSheetState extends State<_RecipeStepsSheet> {
  final TextEditingController _newStep = TextEditingController();
  final TextEditingController _editStep = TextEditingController();
  late List<_EditableRecipeStep> _steps;
  int? _editingIndex;
  int _nextStepId = 0;

  @override
  void initState() {
    super.initState();
    _steps = widget.initialSteps
        .map((String text) => _EditableRecipeStep(_nextStepId++, text))
        .toList();
  }

  @override
  void dispose() {
    _newStep.dispose();
    _editStep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Step ricetta',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chiudi',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                children: <Widget>[
                  TtAppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Nuovo step',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _newStep,
                          minLines: 2,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Descrizione step',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _insertStep,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Inserisci step'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_steps.isEmpty)
                    const _EmptyInline(message: 'Nessuno step inserito.')
                  else ...<Widget>[
                    Text(
                      'Doppio tap su uno step per modificarlo o eliminarlo.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: _steps.length,
                      onReorderItem: _reorderItem,
                      itemBuilder: (BuildContext context, int index) {
                        return Padding(
                          key: ValueKey<int>(_steps[index].id),
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _RecipeStepRecord(
                            index: index,
                            text: _steps[index].text,
                            isEditing: _editingIndex == index,
                            editController: _editStep,
                            onDoubleTap: () => _startEditing(index),
                            onConfirmEdit: () => _confirmEdit(index),
                            onDelete: () => _deleteStep(index),
                            dragHandle: ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_handle_rounded),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annulla'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(
                          _steps
                              .map((_EditableRecipeStep step) => step.text)
                              .toList(),
                        ),
                        child: const Text('Applica'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _insertStep() {
    final String text = _newStep.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() {
      _steps.add(_EditableRecipeStep(_nextStepId++, text));
      _newStep.clear();
    });
  }

  void _reorderItem(int oldIndex, int newIndex) {
    setState(() {
      final _EditableRecipeStep item = _steps.removeAt(oldIndex);
      _steps.insert(newIndex, item);
      _editingIndex = null;
    });
  }

  void _startEditing(int index) {
    setState(() {
      _editingIndex = index;
      _editStep.text = _steps[index].text;
    });
  }

  void _confirmEdit(int index) {
    final String text = _editStep.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() {
      _steps[index].text = text;
      _editingIndex = null;
      _editStep.clear();
    });
  }

  void _deleteStep(int index) {
    if (index < 0 || index >= _steps.length) {
      return;
    }
    setState(() {
      _steps.removeAt(index);
      _editingIndex = null;
      _editStep.clear();
    });
  }
}

class _EditableRecipeStep {
  _EditableRecipeStep(this.id, this.text);

  final int id;
  String text;
}

class _RecipeStepRecord extends StatelessWidget {
  const _RecipeStepRecord({
    required this.index,
    required this.text,
    required this.isEditing,
    required this.editController,
    required this.onDoubleTap,
    required this.onConfirmEdit,
    required this.onDelete,
    required this.dragHandle,
  });

  final int index;
  final String text;
  final bool isEditing;
  final TextEditingController editController;
  final VoidCallback onDoubleTap;
  final VoidCallback onConfirmEdit;
  final VoidCallback onDelete;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: TtAppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  child: Text('${index + 1}'),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    text,
                    maxLines: isEditing ? null : 2,
                    overflow: isEditing
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                dragHandle,
              ],
            ),
            if (isEditing) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: editController,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Modifica step',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.error,
                        side: BorderSide(color: colors.error),
                      ),
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Elimina'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onConfirmEdit,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Conferma'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
      onTap: () => context.push('/food/ingredients/${ingredient.id}'),
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
    required this.onTap,
  });

  final OpenFoodFactsProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      onTap: onTap,
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
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _FoodThumb extends StatelessWidget {
  const _FoodThumb({
    required this.imageUrl,
    required this.fallbackIcon,
    this.size = 54,
  });

  final String imageUrl;
  final IconData fallbackIcon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: imageUrl.trim().isEmpty
            ? ColoredBox(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  fallbackIcon,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : _imageProviderWidget(context),
      ),
    );
  }

  Widget _imageProviderWidget(BuildContext context) {
    final String source = imageUrl.trim();
    final Widget fallback = ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(
        fallbackIcon,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Image.network(
        source,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    final File file = File(source);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    return fallback;
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

class _TargetAlertCard extends StatelessWidget {
  const _TargetAlertCard({required this.alert});

  final TargetAlert alert;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool critical =
        alert.severityCode == TargetAlertSeverityCodes.critical;
    final bool warning = alert.severityCode == TargetAlertSeverityCodes.warning;
    final Color accent = critical
        ? colors.error
        : warning
            ? colors.tertiary
            : colors.primary;
    final IconData icon = critical
        ? Icons.error_outline_rounded
        : warning
            ? Icons.warning_amber_rounded
            : Icons.info_outline_rounded;
    return TtAppCard(
      borderColor: accent.withValues(alpha: 0.72),
      backgroundColor: accent.withValues(alpha: 0.08),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  alert.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  alert.message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
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

// ignore: unused_element
void _showInsights(BuildContext context, FoodHubV01Data data) {
  final MealNutritionTotals totals = _totalsForMeals(data.allMeals);
  final int averageDivisor = data.days.isEmpty ? 1 : data.days.length;
  final double averageBalance = data.days.isEmpty
      ? 0
      : data.days.take(7).fold<double>(0, (double sum, DailyRecordEntity day) {
            final double target =
                day.targetKcal ?? data.adaptiveSummary.targetKcal;
            return sum + data.analytics.caloriesForDate(day.dateKey) - target;
          }) /
          data.days.take(7).length;
  final Map<String, int> eaten = <String, int>{};
  for (final MealWithItems meal in data.allMeals) {
    for (final MealItemEntity item in meal.items) {
      eaten[item.itemNameSnapshot] = (eaten[item.itemNameSnapshot] ?? 0) + 1;
    }
  }
  final List<MapEntry<String, int>> topFoods = eaten.entries.toList()
    ..sort((MapEntry<String, int> a, MapEntry<String, int> b) {
      return b.value.compareTo(a.value);
    });
  final List<DailyRecordEntity> recentDays =
      data.days.take(10).toList().reversed.toList();
  final List<TtChartSeries> macroSeries = <TtChartSeries>[
    TtChartSeries(
      label: 'Proteine',
      points: <TtChartPoint>[
        for (final DailyRecordEntity day in recentDays)
          TtChartPoint(
            label: day.dateKey.substring(5),
            value: _totalsForMeals(data.allMeals
                    .where((MealWithItems meal) =>
                        meal.meal.dateKey == day.dateKey)
                    .toList())
                .proteinGrams,
          ),
      ],
    ),
    TtChartSeries(
      label: 'Carboidrati',
      points: <TtChartPoint>[
        for (final DailyRecordEntity day in recentDays)
          TtChartPoint(
            label: day.dateKey.substring(5),
            value: _totalsForMeals(data.allMeals
                    .where((MealWithItems meal) =>
                        meal.meal.dateKey == day.dateKey)
                    .toList())
                .carbsGrams,
          ),
      ],
    ),
    TtChartSeries(
      label: 'Grassi',
      points: <TtChartPoint>[
        for (final DailyRecordEntity day in recentDays)
          TtChartPoint(
            label: day.dateKey.substring(5),
            value: _totalsForMeals(data.allMeals
                    .where((MealWithItems meal) =>
                        meal.meal.dateKey == day.dateKey)
                    .toList())
                .fatGrams,
          ),
      ],
    ),
  ];
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
                      '${_fmt(totals.proteinGrams / averageDivisor)}P ${_fmt(totals.carbsGrams / averageDivisor)}C ${_fmt(totals.fatGrams / averageDivisor)}F'),
                  _Metric('Ingredienti', data.ingredients.length.toString()),
                  _Metric('Ricette', data.recipes.length.toString()),
                  _Metric('Giorni registrati', data.days.length.toString()),
                ],
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              _ChartCard(
                title: 'Calorie',
                subtitle: 'Totale giornaliero calcolato dai pasti',
                child: TtMiniBarChart(points: data.recentCalories),
              ),
              const SizedBox(height: AppSpacing.md),
              _ChartCard(
                title: 'Passi',
                subtitle: 'Trend giornaliero',
                child: TtMiniLineChart(points: data.recentSteps),
              ),
              const SizedBox(height: AppSpacing.md),
              _ChartCard(
                title: 'Macro',
                subtitle: 'Proteine, carboidrati e grassi negli ultimi giorni',
                child: TtMiniMultiLineChart(
                  series: macroSeries,
                  valueSuffix: 'g',
                  height: 190,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
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
            ],
          );
        },
      );
    },
  );
}

// Retained for diagnostic comparison with historical weekly snapshots.
// ignore: unused_element
void _showAdaptiveDetails(BuildContext context, WeekAdaptiveSummary summary) {
  final double intakeFactor =
      ((summary.validIntakeDays - 4) / 10).clamp(0, 1).toDouble();
  final double weightFactor =
      ((summary.validWeightDays - 3) / 8).clamp(0, 1).toDouble();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) {
      return FractionallySizedBox(
        heightFactor: 0.92,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Dettaglio target adattivo',
                    style: Theme.of(sheetContext).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Chiudi',
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TtAppCard(
              child: _MetricGrid(
                metrics: <_Metric>[
                  _Metric('Target settimana', _fmtKcal(summary.targetKcal)),
                  _Metric('TDEE ref', _fmtKcal(summary.tdeeRefKcal)),
                  _Metric('Confidenza',
                      '${(summary.observedConfidence * 100).round()}%'),
                  _Metric('Giorni ref', summary.referenceDaysCount.toString()),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _AdaptiveExplanationBlock(
              title: '1. TDEE teorico',
              body: 'Parte dal metabolismo basale stimato dal profilo e dal '
                  'peso di riferimento. Il metabolismo viene moltiplicato per '
                  'il fattore sedentario e poi si aggiunge l’attivita media '
                  'dei giorni di riferimento.',
              rows: <_Metric>[
                _Metric('RMR', _fmtNullableKcal(summary.rmrKcal)),
                _Metric('Peso ref', _fmtNullable(summary.weightRefKg, 'kg')),
                _Metric('Attivita ref', _fmtKcal(summary.activeRefKcal)),
                _Metric('TDEE teorico', _fmtKcal(summary.tdeeTheoreticalKcal)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _AdaptiveExplanationBlock(
              title: '2. TDEE osservato',
              body: 'Quando ci sono abbastanza giorni alimentari e pesi '
                  'validi, l’app stima il consumo osservato dalla media delle '
                  'calorie assunte e dalla variazione di peso. I pasti liberi '
                  'non tracciati vengono esclusi, quelli stimati pesano meno.',
              rows: <_Metric>[
                _Metric('TDEE osservato',
                    _fmtNullableKcal(summary.tdeeObservedKcal)),
                _Metric(
                    'Media kcal ref', _fmtNullableKcal(summary.avgCalories)),
                _Metric(
                  'Delta peso',
                  summary.deltaWeightKg == null
                      ? 'n/d'
                      : '${_fmt(summary.deltaWeightKg!)} kg',
                ),
                _Metric('Coefficiente peso',
                    '${summary.kcalPerKg.round()} kcal/kg'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _AdaptiveExplanationBlock(
              title: '3. Confidenza osservata',
              body: 'La confidenza non arriva mai al 100%: il massimo e 80%. '
                  'Nel calcolo pesano i giorni con introito valido, i punti '
                  'peso disponibili e l’affidabilita nutrizionale dei pasti.',
              rows: <_Metric>[
                _Metric('Introiti validi', summary.validIntakeDays.toString()),
                _Metric('Pesi validi', summary.validWeightDays.toString()),
                _Metric('Fattore introiti', '${(intakeFactor * 100).round()}%'),
                _Metric('Fattore pesi', '${(weightFactor * 100).round()}%'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _AdaptiveExplanationBlock(
              title: '4. Target finale',
              body: 'Il TDEE teorico e quello osservato vengono miscelati '
                  'usando la confidenza. Poi viene aggiunto il delta tra '
                  'attivita media della settimana corrente e attivita media '
                  'di riferimento.',
              rows: <_Metric>[
                _Metric('Attivita settimana',
                    _fmtKcal(summary.currentWeekActiveKcal)),
                _Metric(
                    'Delta attivita', _signedKcal(summary.activityDeltaKcal)),
                _Metric('Target finale', _fmtKcal(summary.targetKcal)),
                _Metric('Stato', summary.targetStatusCode),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _AdaptiveExplanationBlock extends StatelessWidget {
  const _AdaptiveExplanationBlock({
    required this.title,
    required this.body,
    required this.rows,
  });

  final String title;
  final String body;
  final List<_Metric> rows;

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(body),
          const SizedBox(height: AppSpacing.md),
          _MetricGrid(metrics: rows),
        ],
      ),
    );
  }
}

// ignore: unused_element
void _legacyAdaptiveDetailsDialog(
    BuildContext context, WeekAdaptiveSummary summary) {
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
              _detailRow(
                  'Coefficiente peso', '${summary.kcalPerKg.round()} kcal/kg'),
              _detailRow(
                'Formula osservata',
                'kcal medie - variazione peso * kcal/kg / giorni',
              ),
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
  final String displayValue = value.trim().isEmpty ? 'n/d' : value.trim();
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        SelectableText(
          displayValue,
          style: const TextStyle(height: 1.25),
        ),
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

bool _hasAllMealSlotsLogged(List<MealWithItems> meals) {
  final Set<String> loggedSlots = meals
      .where((MealWithItems meal) => meal.items.isNotEmpty)
      .map((MealWithItems meal) => meal.meal.mealTypeCode)
      .toSet();
  return ObsidianFoodSeedConstants.mealSlots.every(loggedSlots.contains);
}

Widget _field(
  TextEditingController controller,
  String label, {
  bool isRequired = false,
  bool enabled = true,
  String? helperText,
  VoidCallback? onTap,
  Widget? suffixIcon,
  TextInputType? keyboardType,
  int maxLines = 1,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: !enabled,
      onTap: onTap,
      validator: isRequired
          ? (String? value) => value == null || value.trim().isEmpty
              ? 'Campo obbligatorio'
              : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        suffixIcon: suffixIcon,
      ),
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

String _shortWeekdayLabel(DateTime date) {
  const List<String> labels = <String>[
    'Lun',
    'Mar',
    'Mer',
    'Gio',
    'Ven',
    'Sab',
    'Dom',
  ];
  return labels[date.weekday - 1];
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

String _mealItemQuantityText(MealItemEntity item) {
  if (item.quantityModeCode == 'portions') {
    final double portions = item.portions ?? 0;
    return portions <= 0 ? 'Porzioni n/d' : '${_fmt(portions)} porzioni';
  }
  final double grams = item.grams ?? 0;
  return grams <= 0 ? 'Quantità n/d' : '${_fmt(grams)} g';
}

String _recipeDifficultyLabel(String code) {
  return const <String, String>{
        'easy': 'Facile',
        'medium': 'Media',
        'hard': 'Difficile',
      }[code] ??
      (code.trim().isEmpty ? 'Non indicata' : code);
}

double? _recipeWeightGrams(RecipeEntity recipe) {
  final double? value = recipe.yieldGrams ?? recipe.totalWeightGrams;
  if (value == null || value <= 0) {
    return null;
  }
  return value;
}

List<String> _recipeQuantityModes(RecipeEntity recipe) {
  return <String>[
    if (recipe.servings > 0) 'portions',
    if (_recipeWeightGrams(recipe) != null) 'grams',
  ];
}

String _recipeQuantitySummary(RecipeEntity recipe) {
  final List<String> parts = <String>[];
  if (recipe.servings > 0) {
    parts.add('${recipe.servings} porzioni');
  }
  final double? weight = _recipeWeightGrams(recipe);
  if (weight != null) {
    parts.add('${_fmt(weight)} g finali');
  }
  parts.add(_recipeDifficultyLabel(recipe.difficultyCode));
  return parts.join(' - ');
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
