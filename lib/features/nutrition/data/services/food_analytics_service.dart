import 'dart:math' as math;

import '../../../profile/data/entities/user_profile_entity.dart';
import '../../../profile/domain/profile_codes.dart';
import '../../../profile/domain/profile_nutrition_calculator.dart';
import '../../../workout/data/entities/workout_tracking_entities.dart';
import '../../../workout/data/repositories/workout_session_repository.dart';
import '../../domain/adaptive_target_engine.dart';
import '../entities/nutrition_tracking_entities.dart';
import '../repositories/meal_repository.dart';
import '../repositories/measurement_repository.dart';

class ActivityBreakdown {
  const ActivityBreakdown({
    required this.stepKcal,
    required this.completedWorkoutKcal,
    required this.actualTotalKcal,
  });

  final double stepKcal;
  final double completedWorkoutKcal;
  final double actualTotalKcal;
}

class TargetDayResult {
  const TargetDayResult({
    required this.targetKcal,
    required this.targetStatusCode,
    required this.tdeeRefKcal,
    required this.tdeeTheoreticalKcal,
    required this.tdeeObservedKcal,
    required this.observedConfidence,
    required this.referenceDaysCount,
    required this.validIntakeDays,
    required this.validWeightDays,
    required this.rmrKcal,
    required this.weightRefKg,
    required this.weightStatusCode,
    required this.weightDaysSinceMeasurement,
    required this.activeRefKcal,
    required this.activity,
    required this.activityDeltaKcal,
    required this.alerts,
  });

  final double targetKcal;
  final String targetStatusCode;
  final double tdeeRefKcal;
  final double tdeeTheoreticalKcal;
  final double? tdeeObservedKcal;
  final double observedConfidence;
  final int referenceDaysCount;
  final int validIntakeDays;
  final int validWeightDays;
  final double? rmrKcal;
  final double? weightRefKg;
  final String weightStatusCode;
  final int? weightDaysSinceMeasurement;
  final double activeRefKcal;
  final ResolvedActivityBreakdown activity;
  final double activityDeltaKcal;
  final List<TargetAlert> alerts;
}

class ObservedTdeeResult {
  const ObservedTdeeResult({
    required this.tdeeObserved,
    required this.observedConfidence,
    required this.validIntakeDays,
    required this.validWeightDays,
    required this.deltaWeightKg,
    required this.avgCalories,
  });

  final double? tdeeObserved;
  final double observedConfidence;
  final int validIntakeDays;
  final int validWeightDays;
  final double? deltaWeightKg;
  final double? avgCalories;
}

class WeekAdaptiveSummary {
  const WeekAdaptiveSummary({
    required this.monday,
    required this.sunday,
    required this.targetKcal,
    required this.targetStatusCode,
    required this.tdeeRefKcal,
    required this.tdeeTheoreticalKcal,
    required this.tdeeObservedKcal,
    required this.observedConfidence,
    required this.referenceDaysCount,
    required this.validIntakeDays,
    required this.validWeightDays,
    required this.rmrKcal,
    required this.weightRefKg,
    required this.weightStatusCode,
    required this.weightDaysSinceMeasurement,
    required this.weightTrendEnabled,
    required this.activeRefKcal,
    required this.activeRefSourceCode,
    required this.currentWeekActiveKcal,
    required this.activityStatusCode,
    required this.activityDeltaKcal,
    required this.deltaWeightKg,
    required this.avgCalories,
    required this.kcalPerKg,
    required this.alerts,
  });

  final DateTime monday;
  final DateTime sunday;
  final double targetKcal;
  final String targetStatusCode;
  final double tdeeRefKcal;
  final double tdeeTheoreticalKcal;
  final double? tdeeObservedKcal;
  final double observedConfidence;
  final int referenceDaysCount;
  final int validIntakeDays;
  final int validWeightDays;
  final double? rmrKcal;
  final double? weightRefKg;
  final String weightStatusCode;
  final int? weightDaysSinceMeasurement;
  final bool weightTrendEnabled;
  final double activeRefKcal;
  final String activeRefSourceCode;
  final double currentWeekActiveKcal;
  final String activityStatusCode;
  final double activityDeltaKcal;
  final double? deltaWeightKg;
  final double? avgCalories;
  final double kcalPerKg;
  final List<TargetAlert> alerts;
}

class FoodAnalyticsService {
  FoodAnalyticsService({
    required MealRepository meals,
    required MeasurementRepository measurements,
    required WorkoutSessionRepository workoutSessions,
  })  : _meals = meals,
        _measurements = measurements,
        _workoutSessions = workoutSessions;

  final MealRepository _meals;
  final MeasurementRepository _measurements;
  final WorkoutSessionRepository _workoutSessions;
  final ProfileNutritionCalculator _profileCalculator =
      const ProfileNutritionCalculator();
  final AdaptiveTargetEngine _targetEngine = const AdaptiveTargetEngine();

  ActivityBreakdown activityForDay(
    DailyRecordEntity day, {
    UserProfileEntity? profile,
  }) {
    final double stepCoeff = profile?.stepKcalCoefficient ?? 0.020;
    final double stepKcal = day.activeKcalSteps ?? day.steps * stepCoeff;
    final double completedWorkout =
        _workoutSessions.completedKcalForDate(day.dateKey);
    final double fallbackCompleted =
        day.activeKcalWorkoutCompleted ?? completedWorkout;
    final double actual = math.max(0, stepKcal + fallbackCompleted);
    return ActivityBreakdown(
      stepKcal: math.max(0, stepKcal),
      completedWorkoutKcal: math.max(0, fallbackCompleted),
      actualTotalKcal: actual,
    );
  }

  ResolvedActivityBreakdown effectiveActivityForDay(
    DailyRecordEntity day, {
    UserProfileEntity? profile,
    DateTime? now,
  }) {
    final ActivityBreakdown actual = activityForDay(day, profile: profile);
    if (profile == null) {
      return _targetEngine.resolveActivity(
        steps: day.steps,
        stepGoal: day.stepGoal,
        stepKcalCoefficient: 0.020,
        completedWorkoutKcal: actual.completedWorkoutKcal,
        profileWorkoutDailyKcal: 0,
        fallbackModeCode: ActivityFallbackModeCodes.recordedOnly,
        dayDate: DateTime.parse(day.dateKey),
        now: now ?? DateTime.now(),
      );
    }
    final DateTime resolvedNow = now ?? DateTime.now();
    final DateTime dayDate = DateTime.parse(day.dateKey);
    final WeightFreshnessResult weight = _weightFreshnessForDate(
      dateKey: day.dateKey,
      profile: profile,
      referenceDate: dayDate.isAfter(resolvedNow) ? resolvedNow : dayDate,
    );
    final ProfileNutritionTargets profileTargets =
        _profileCalculator.calculateFixedTargets(
      profile,
      currentWeightKg: weight.effectiveWeightKg,
      now: now,
    );
    return _targetEngine.resolveActivity(
      steps: day.steps,
      stepGoal: day.stepGoal <= 0 ? profile.defaultStepGoal : day.stepGoal,
      stepKcalCoefficient: profile.stepKcalCoefficient,
      completedWorkoutKcal: actual.completedWorkoutKcal,
      profileWorkoutDailyKcal: profileTargets.workoutDailyKcal,
      fallbackModeCode: profile.activityFallbackModeCode,
      dayDate: dayDate,
      now: resolvedNow,
    );
  }

  double caloriesForDate(String dateKey) {
    return _meals.getMealsWithItemsForDate(dateKey).fold<double>(
          0,
          (double sum, MealWithItems meal) => sum + meal.totals.kcal,
        );
  }

  TargetDayResult targetResultForDay({
    required DailyRecordEntity day,
    required List<DailyRecordEntity> allDays,
    UserProfileEntity? profile,
    DateTime? now,
  }) {
    final DateTime resolvedNow = now ?? DateTime.now();
    final ResolvedActivityBreakdown activity = effectiveActivityForDay(
      day,
      profile: profile,
      now: resolvedNow,
    );

    if (profile == null) {
      final double target = day.targetKcal ?? 1980;
      return TargetDayResult(
        targetKcal: target,
        targetStatusCode: 'fallback',
        tdeeRefKcal: target,
        tdeeTheoreticalKcal: target,
        tdeeObservedKcal: null,
        observedConfidence: 0,
        referenceDaysCount: 0,
        validIntakeDays: 0,
        validWeightDays: 0,
        rmrKcal: null,
        weightRefKg: weightForDay(day),
        weightStatusCode: 'unavailable',
        weightDaysSinceMeasurement: null,
        activeRefKcal: activity.totalKcal,
        activity: activity,
        activityDeltaKcal: 0,
        alerts: const <TargetAlert>[
          TargetAlert(
            code: 'profile_missing',
            title: 'Profilo non disponibile',
            message: 'Il target usa il valore salvato nel giorno.',
            severityCode: TargetAlertSeverityCodes.warning,
          ),
        ],
      );
    }

    final WeightFreshnessResult weight = _weightFreshnessForDate(
      dateKey: day.dateKey,
      profile: profile,
      referenceDate: DateTime.parse(day.dateKey).isAfter(resolvedNow)
          ? resolvedNow
          : DateTime.parse(day.dateKey),
    );
    final ProfileNutritionTargets fixed =
        _profileCalculator.calculateFixedTargets(
      profile,
      currentWeightKg: weight.effectiveWeightKg,
      now: resolvedNow,
    );

    if (profile.targetModeCode == TargetModeCodes.fixedUser) {
      return TargetDayResult(
        targetKcal: profile.defaultTargetKcal.toDouble(),
        targetStatusCode: 'fixed_user',
        tdeeRefKcal: profile.defaultTargetKcal.toDouble(),
        tdeeTheoreticalKcal: fixed.sedentaryKcal,
        tdeeObservedKcal: null,
        observedConfidence: 0,
        referenceDaysCount: 0,
        validIntakeDays: 0,
        validWeightDays: 0,
        rmrKcal: fixed.rmrKcal,
        weightRefKg: weight.effectiveWeightKg,
        weightStatusCode: weight.statusCode,
        weightDaysSinceMeasurement: weight.daysSinceMeasurement,
        activeRefKcal: 0,
        activity: activity,
        activityDeltaKcal: 0,
        alerts: const <TargetAlert>[],
      );
    }

    if (profile.targetModeCode == TargetModeCodes.appCalculatedFixed) {
      return TargetDayResult(
        targetKcal: fixed.targetKcal,
        targetStatusCode: 'calculated_fixed',
        tdeeRefKcal: fixed.targetKcal,
        tdeeTheoreticalKcal: fixed.targetKcal,
        tdeeObservedKcal: null,
        observedConfidence: 0,
        referenceDaysCount: 0,
        validIntakeDays: 0,
        validWeightDays: 0,
        rmrKcal: fixed.rmrKcal,
        weightRefKg: weight.effectiveWeightKg,
        weightStatusCode: weight.statusCode,
        weightDaysSinceMeasurement: weight.daysSinceMeasurement,
        activeRefKcal: fixed.profileActivityDailyKcal,
        activity: activity,
        activityDeltaKcal: 0,
        alerts: weight.alerts,
      );
    }

    final DateTime date = DateTime.parse(day.dateKey);
    final DateTime monday = date.subtract(Duration(days: date.weekday - 1));
    final WeekAdaptiveSummary summary = adaptiveSummaryForWeek(
      monday: monday,
      allDays: allDays,
      profile: profile,
      now: resolvedNow,
    );
    final double activityDelta = activity.totalKcal - summary.activeRefKcal;
    final double target = _clamp(
      summary.tdeeRefKcal + activityDelta,
      profile.minimumReasonableTdee,
      profile.maximumReasonableTdee,
    );
    final List<TargetAlert> alerts = <TargetAlert>[...summary.alerts];
    if (activity.usedStepGoalFallback || activity.usedProfileWorkoutFallback) {
      alerts.add(
        TargetAlert(
          code: 'activity_fallback_${day.dateKey}',
          title: 'Attività stimata per il giorno',
          message: _activityFallbackMessage(activity),
          severityCode: TargetAlertSeverityCodes.info,
        ),
      );
    }
    return TargetDayResult(
      targetKcal: target,
      targetStatusCode: summary.targetStatusCode,
      tdeeRefKcal: summary.tdeeRefKcal,
      tdeeTheoreticalKcal: summary.tdeeTheoreticalKcal,
      tdeeObservedKcal: summary.tdeeObservedKcal,
      observedConfidence: summary.observedConfidence,
      referenceDaysCount: summary.referenceDaysCount,
      validIntakeDays: summary.validIntakeDays,
      validWeightDays: summary.validWeightDays,
      rmrKcal: summary.rmrKcal,
      weightRefKg: summary.weightRefKg,
      weightStatusCode: summary.weightStatusCode,
      weightDaysSinceMeasurement: summary.weightDaysSinceMeasurement,
      activeRefKcal: summary.activeRefKcal,
      activity: activity,
      activityDeltaKcal: activityDelta,
      alerts: alerts,
    );
  }

  double targetForDay({
    required DailyRecordEntity day,
    required List<DailyRecordEntity> allDays,
    UserProfileEntity? profile,
    DateTime? now,
  }) {
    return targetResultForDay(
      day: day,
      allDays: allDays,
      profile: profile,
      now: now,
    ).targetKcal;
  }

  void applyTargetSnapshot(
    DailyRecordEntity day,
    TargetDayResult result, {
    int? calculatedAtEpochMs,
  }) {
    day.targetKcal = result.targetKcal;
    day.targetStatusCode = result.targetStatusCode;
    day.targetCalculatedAtEpochMs =
        calculatedAtEpochMs ?? DateTime.now().millisecondsSinceEpoch;
    day.targetSourceHash = <Object?>[
      result.targetStatusCode,
      result.referenceDaysCount,
      result.validIntakeDays,
      result.validWeightDays,
      result.weightStatusCode,
      result.activity.statusCode,
      result.targetKcal.round(),
    ].join('|');
    day.tdeeRefKcal = result.tdeeRefKcal;
    day.tdeeTheoreticalKcal = result.tdeeTheoreticalKcal;
    day.tdeeObservedKcal = result.tdeeObservedKcal;
    day.observedConfidence = result.observedConfidence;
    day.referenceDaysCount = result.referenceDaysCount;
    day.validIntakeDays = result.validIntakeDays;
    day.validWeightDays = result.validWeightDays;
    day.rmrKcal = result.rmrKcal;
    day.weightRefKg = result.weightRefKg;
    day.activeRefKcal = result.activeRefKcal;
    day.activeKcalSteps = result.activity.actualStepKcal;
    final Map<String, double> workoutByStatus =
        _workoutKcalByStatus(day.dateKey);
    day.activeKcalWorkoutCompleted =
        workoutByStatus['completed'] ?? result.activity.actualWorkoutKcal;
    day.activeKcalWorkoutInProgress = workoutByStatus['in_progress'] ?? 0;
    day.activeKcalWorkoutPlanned = workoutByStatus['planned'] ?? 0;
    day.activeKcalWorkoutSkipped = workoutByStatus['skipped'] ?? 0;
    day.activeKcalWorkoutUnknown = workoutByStatus['unknown'] ?? 0;
    day.activeKcalActual =
        result.activity.actualStepKcal + result.activity.actualWorkoutKcal;
    day.activeEffectiveKcal = result.activity.totalKcal;
    day.activityDeltaKcal = result.activityDeltaKcal;
    day.activeStatusCode = result.activity.statusCode;
    day.caloriesInKcal = caloriesForDate(day.dateKey);
    day.energyBalanceKcal = day.caloriesInKcal! - result.targetKcal;
    day.dataCompletenessScore = _dataCompleteness(result);
  }

  ProfileNutritionTargets macroTargetsForDay({
    required DailyRecordEntity day,
    UserProfileEntity? profile,
  }) {
    final UserProfileEntity fallbackProfile = profile ??
        UserProfileEntity(
          uuid: 'fallback',
          createdAtEpochMs: 0,
          updatedAtEpochMs: 0,
        );
    final WeightFreshnessResult weight = _weightFreshnessForDate(
      dateKey: day.dateKey,
      profile: fallbackProfile,
      referenceDate: DateTime.parse(day.dateKey),
    );
    return _profileCalculator.calculateFixedTargets(
      fallbackProfile,
      currentWeightKg: weight.effectiveWeightKg ?? weightForDay(day),
    );
  }

  bool hasPartialNutrition(String dateKey) {
    return _meals.getMealsWithItemsForDate(dateKey).any(
          (MealWithItems meal) => meal.isNutritionPartial,
        );
  }

  String freeMealModeForDate(String dateKey) {
    final List<MealWithItems> meals = _meals.getMealsWithItemsForDate(dateKey);
    final bool hasFree =
        meals.any((MealWithItems meal) => meal.meal.mealModeCode == 'free');
    if (!hasFree) {
      return 'none';
    }
    if (meals.any(
      (MealWithItems meal) => meal.meal.freeMealTrackingCode == 'untracked',
    )) {
      return 'untracked';
    }
    if (meals.any(
      (MealWithItems meal) => meal.meal.freeMealTrackingCode == 'estimated',
    )) {
      return 'estimated';
    }
    return 'tracked';
  }

  double? weightForDay(DailyRecordEntity day) {
    return _measurements.findScaleByDate(day.dateKey)?.weightKg ?? day.weightKg;
  }

  WeekAdaptiveSummary adaptiveSummaryForWeek({
    required DateTime monday,
    required List<DailyRecordEntity> allDays,
    UserProfileEntity? profile,
    DateTime? now,
  }) {
    final DateTime resolvedNow = now ?? DateTime.now();
    final DateTime sunday = monday.add(const Duration(days: 6));
    final DateTime referenceDate =
        sunday.isAfter(resolvedNow) ? resolvedNow : sunday;
    final String mondayKey = _dateKey(monday);
    final List<DailyRecordEntity> sorted = List<DailyRecordEntity>.from(allDays)
      ..sort((DailyRecordEntity a, DailyRecordEntity b) {
        return a.dateKey.compareTo(b.dateKey);
      });
    final int referenceLimit = profile?.adaptiveReferenceDays ?? 28;
    final List<DailyRecordEntity> reference = sorted
        .where((DailyRecordEntity day) => day.dateKey.compareTo(mondayKey) < 0)
        .toList()
        .takeLast(referenceLimit);
    final List<DailyRecordEntity> currentWeek = sorted.where(
      (DailyRecordEntity day) {
        final DateTime parsed = DateTime.parse(day.dateKey);
        return !parsed.isBefore(monday) &&
            !parsed.isAfter(sunday) &&
            !parsed.isAfter(resolvedNow);
      },
    ).toList();

    final WeightFreshnessResult weight = profile == null
        ? const WeightFreshnessResult(
            effectiveWeightKg: null,
            sourceCode: 'unavailable',
            statusCode: 'missing',
            daysSinceMeasurement: null,
            allowObservedWeightTrend: false,
            alerts: <TargetAlert>[],
          )
        : _weightFreshnessForDate(
            dateKey: _dateKey(referenceDate),
            profile: profile,
            referenceDate: referenceDate,
          );
    final ProfileNutritionTargets? profileTargets = profile == null
        ? null
        : _profileCalculator.calculateFixedTargets(
            profile,
            currentWeightKg: weight.effectiveWeightKg,
            now: resolvedNow,
          );
    final double profileActivity =
        profileTargets?.profileActivityDailyKcal ?? 0;

    final List<double> activeValues = reference
        .map((DailyRecordEntity day) => activityForDay(day, profile: profile))
        .map((ActivityBreakdown item) => item.actualTotalKcal)
        .where((double value) => value > 0)
        .toList();
    final bool forceProfileEstimate = profile?.activityFallbackModeCode ==
        ActivityFallbackModeCodes.profileEstimate;
    final bool allowProfileFallback = profile?.activityFallbackModeCode !=
        ActivityFallbackModeCodes.recordedOnly;
    final double activeRef;
    final String activeRefSourceCode;
    if (forceProfileEstimate) {
      activeRef = profileActivity;
      activeRefSourceCode = 'profile_estimate';
    } else if (activeValues.isNotEmpty) {
      activeRef = _average(activeValues) ?? 0;
      activeRefSourceCode = 'recorded_history';
    } else if (allowProfileFallback) {
      activeRef = profileActivity;
      activeRefSourceCode = 'profile_fallback';
    } else {
      activeRef = 0;
      activeRefSourceCode = 'unavailable';
    }

    final List<ResolvedActivityBreakdown> currentActivity = currentWeek
        .map(
          (DailyRecordEntity day) => effectiveActivityForDay(
            day,
            profile: profile,
            now: resolvedNow,
          ),
        )
        .toList();
    final double currentWeekActive = _average(
          currentActivity
              .map((ResolvedActivityBreakdown item) => item.totalKcal)
              .toList(),
        ) ??
        activeRef;
    final String activityStatusCode = _summaryActivityStatus(currentActivity);
    final double? rmr = profileTargets?.rmrKcal;
    final double theoretical = profileTargets == null
        ? 1980
        : profileTargets.sedentaryKcal + activeRef;
    final ObservedTdeeResult observed = _calculateObservedTdee(
      reference,
      minimumObservedDays: profile?.adaptiveMinimumObservedDays ?? 7,
      kcalPerKg: profile?.kcalPerKg ?? 7700,
      minTdee: profile?.minimumReasonableTdee ?? 1300,
      maxTdee: profile?.maximumReasonableTdee ?? 4600,
      allowWeightTrend: weight.allowObservedWeightTrend,
    );
    final double confidence =
        observed.tdeeObserved == null ? 0 : observed.observedConfidence;
    final double calculated = observed.tdeeObserved == null
        ? theoretical
        : confidence * observed.tdeeObserved! + (1 - confidence) * theoretical;
    final double tdeeRef = _clamp(
      calculated,
      profile?.minimumReasonableTdee ?? 1300,
      profile?.maximumReasonableTdee ?? 4600,
    );
    final double activityDelta = currentWeekActive - activeRef;
    final double target = _clamp(
      tdeeRef + activityDelta,
      profile?.minimumReasonableTdee ?? 1300,
      profile?.maximumReasonableTdee ?? 4600,
    );
    final List<TargetAlert> alerts = <TargetAlert>[...weight.alerts];
    final int minimumObserved = profile?.adaptiveMinimumObservedDays ?? 7;
    if (reference.length < minimumObserved) {
      alerts.add(
        TargetAlert(
          code: 'reference_days_insufficient',
          title: 'Target ancora provvisorio',
          message: 'Sono disponibili ${reference.length} giorni precedenti; '
              'ne servono almeno $minimumObserved per attivare la componente '
              'osservata.',
          severityCode: TargetAlertSeverityCodes.info,
        ),
      );
    } else if (observed.validIntakeDays < minimumObserved) {
      alerts.add(
        TargetAlert(
          code: 'intake_days_insufficient',
          title: 'Dati alimentari insufficienti',
          message: 'Solo ${observed.validIntakeDays} giorni hanno calorie '
              'utilizzabili. I pasti non quantificati non vengono trattati '
              'come giornate complete.',
          severityCode: TargetAlertSeverityCodes.warning,
        ),
      );
    }
    if (activeRefSourceCode == 'profile_fallback') {
      alerts.add(
        const TargetAlert(
          code: 'activity_history_missing',
          title: 'Attività storica stimata',
          message: 'Non ci sono giorni precedenti con attività utilizzabile. '
              'La base usa target passi e allenamenti medi del profilo.',
          severityCode: TargetAlertSeverityCodes.info,
        ),
      );
    }

    return WeekAdaptiveSummary(
      monday: monday,
      sunday: sunday,
      targetKcal: target,
      targetStatusCode: observed.tdeeObserved != null && confidence >= 0.35
          ? 'adaptive'
          : 'provisional',
      tdeeRefKcal: tdeeRef,
      tdeeTheoreticalKcal: theoretical,
      tdeeObservedKcal: observed.tdeeObserved,
      observedConfidence: confidence,
      referenceDaysCount: reference.length,
      validIntakeDays: observed.validIntakeDays,
      validWeightDays: observed.validWeightDays,
      rmrKcal: rmr,
      weightRefKg: weight.effectiveWeightKg,
      weightStatusCode: weight.statusCode,
      weightDaysSinceMeasurement: weight.daysSinceMeasurement,
      weightTrendEnabled: weight.allowObservedWeightTrend,
      activeRefKcal: activeRef,
      activeRefSourceCode: activeRefSourceCode,
      currentWeekActiveKcal: currentWeekActive,
      activityStatusCode: activityStatusCode,
      activityDeltaKcal: activityDelta,
      deltaWeightKg: observed.deltaWeightKg,
      avgCalories: observed.avgCalories,
      kcalPerKg: profile?.kcalPerKg ?? 7700,
      alerts: alerts,
    );
  }

  ObservedTdeeResult _calculateObservedTdee(
    List<DailyRecordEntity> referenceDays, {
    required int minimumObservedDays,
    required double kcalPerKg,
    required double minTdee,
    required double maxTdee,
    required bool allowWeightTrend,
  }) {
    if (referenceDays.length < minimumObservedDays) {
      return const ObservedTdeeResult(
        tdeeObserved: null,
        observedConfidence: 0,
        validIntakeDays: 0,
        validWeightDays: 0,
        deltaWeightKg: null,
        avgCalories: null,
      );
    }
    final List<_WeightedValue> intakeDays = <_WeightedValue>[];
    final List<_WeightPoint> weightPoints = <_WeightPoint>[];
    for (final DailyRecordEntity day in referenceDays) {
      final String freeMode = freeMealModeForDate(day.dateKey);
      final double intakeReliability = _intakeReliabilityForMode(freeMode);
      final double kcal = caloriesForDate(day.dateKey);
      if (kcal > 0 && intakeReliability > 0) {
        intakeDays.add(_WeightedValue(value: kcal, weight: intakeReliability));
      }
      if (allowWeightTrend) {
        final ScaleMeasurementEntity? measurement =
            _measurements.findScaleByDate(day.dateKey);
        final double? weight = measurement?.weightKg ?? day.weightKg;
        final double reliability = measurement == null
            ? (weight == null ? 0 : 0.75)
            : measurement.reliabilityCode == 'low'
                ? 0.5
                : 1;
        if (weight != null && weight > 0 && reliability > 0.25) {
          weightPoints.add(
            _WeightPoint(
              dateKey: day.dateKey,
              value: weight,
              weight: reliability,
            ),
          );
        }
      }
    }
    if (intakeDays.length < minimumObservedDays) {
      return ObservedTdeeResult(
        tdeeObserved: null,
        observedConfidence: 0.10,
        validIntakeDays: intakeDays.length,
        validWeightDays: weightPoints.length,
        deltaWeightKg: null,
        avgCalories: intakeDays.isEmpty ? null : _weightedAverage(intakeDays),
      );
    }
    final double avgCalories = _weightedAverage(intakeDays);
    if (weightPoints.length < 4) {
      return ObservedTdeeResult(
        tdeeObserved: null,
        observedConfidence: 0.15,
        validIntakeDays: intakeDays.length,
        validWeightDays: weightPoints.length,
        deltaWeightKg: null,
        avgCalories: avgCalories,
      );
    }
    final int splitSize = math.max(2, weightPoints.length ~/ 2);
    final List<_WeightPoint> firstWindow =
        weightPoints.take(splitSize).toList();
    final List<_WeightPoint> lastWindow = weightPoints
        .skip(math.max(0, weightPoints.length - splitSize))
        .toList();
    final double startWeight = _weightedAverage(firstWindow);
    final double endWeight = _weightedAverage(lastWindow);
    final int elapsedDays = math.max(
      1,
      DateTime.parse(lastWindow.last.dateKey)
          .difference(DateTime.parse(firstWindow.first.dateKey))
          .inDays,
    );
    final double deltaWeightKg = endWeight - startWeight;
    final double observed =
        avgCalories - ((deltaWeightKg * kcalPerKg) / elapsedDays);
    final double dayFactor = _clamp((intakeDays.length - 4) / 10, 0, 1);
    final double weightFactor = _clamp((weightPoints.length - 3) / 8, 0, 1);
    final double intakeReliability = _average(
          intakeDays.map((_WeightedValue item) => item.weight).toList(),
        ) ??
        0;
    final double observedConfidence = _clamp(
      dayFactor * 0.42 + weightFactor * 0.28 + intakeReliability * 0.30,
      0,
      0.80,
    );
    return ObservedTdeeResult(
      tdeeObserved: _clamp(observed, minTdee, maxTdee),
      observedConfidence: observedConfidence,
      validIntakeDays: intakeDays.length,
      validWeightDays: weightPoints.length,
      deltaWeightKg: deltaWeightKg,
      avgCalories: avgCalories,
    );
  }

  WeightFreshnessResult _weightFreshnessForDate({
    required String dateKey,
    required UserProfileEntity profile,
    required DateTime referenceDate,
  }) {
    final ScaleMeasurementEntity? latest =
        _measurements.latestScaleOnOrBefore(dateKey);
    return _targetEngine.evaluateWeight(
      latestMeasurementWeightKg: latest?.weightKg,
      latestMeasurementDate:
          latest == null ? null : DateTime.tryParse(latest.dateKey),
      latestReliabilityCode: latest?.reliabilityCode ?? '',
      initialProfileWeightKg: profile.initialWeightKg,
      referenceDate: referenceDate,
    );
  }

  Map<String, double> _workoutKcalByStatus(String dateKey) {
    final Map<String, double> result = <String, double>{
      'planned': 0,
      'in_progress': 0,
      'completed': 0,
      'skipped': 0,
      'unknown': 0,
    };
    for (final WorkoutSessionEntity session
        in _workoutSessions.getAllActive()) {
      if (session.sessionDateKey != dateKey) {
        continue;
      }
      final String status = result.containsKey(session.statusCode)
          ? session.statusCode
          : 'unknown';
      result[status] = result[status]! + (session.estimatedKcalBurned ?? 0);
    }
    return result;
  }

  String _activityFallbackMessage(ResolvedActivityBreakdown activity) {
    if (activity.usedStepGoalFallback && activity.usedProfileWorkoutFallback) {
      return 'Non sono ancora disponibili passi o allenamenti completati: '
          'vengono usati target passi e attività media del profilo.';
    }
    if (activity.usedStepGoalFallback) {
      return 'I passi non sono ancora disponibili: viene usato il target '
          'passi configurato nel profilo.';
    }
    return 'Non risultano allenamenti completati: viene usata la quota media '
        'giornaliera configurata nel profilo.';
  }

  String _summaryActivityStatus(
    List<ResolvedActivityBreakdown> activities,
  ) {
    if (activities.isEmpty) {
      return 'unavailable';
    }
    final Set<String> statuses = activities
        .map((ResolvedActivityBreakdown item) => item.statusCode)
        .toSet();
    if (statuses.length == 1) {
      return statuses.first;
    }
    if (statuses.contains('estimated') || statuses.contains('mixed')) {
      return 'mixed';
    }
    return 'actual';
  }

  double _dataCompleteness(TargetDayResult result) {
    double score = 0;
    if (result.referenceDaysCount > 0) {
      score += 0.2;
    }
    if (result.validIntakeDays > 0) {
      score += 0.25;
    }
    if (result.validWeightDays > 0 || result.weightRefKg != null) {
      score += 0.25;
    }
    if (result.activity.statusCode == 'actual') {
      score += 0.3;
    } else if (result.activity.statusCode == 'mixed') {
      score += 0.2;
    } else if (result.activity.statusCode == 'estimated') {
      score += 0.1;
    }
    return score.clamp(0, 1).toDouble();
  }

  double _intakeReliabilityForMode(String mode) {
    if (mode == 'untracked') {
      return 0;
    }
    if (mode == 'estimated') {
      return 0.6;
    }
    return 1;
  }

  double? _average(List<double> values) {
    if (values.isEmpty) {
      return null;
    }
    return values.reduce((double a, double b) => a + b) / values.length;
  }

  double _weightedAverage(Iterable<_WeightedValue> values) {
    final List<_WeightedValue> valueList = values.toList();
    final double weightSum =
        valueList.fold<double>(0, (double sum, _WeightedValue item) {
      return sum + item.weight;
    });
    if (weightSum <= 0) {
      return 0;
    }
    return valueList.fold<double>(
          0,
          (double sum, _WeightedValue item) => sum + item.value * item.weight,
        ) /
        weightSum;
  }

  double _clamp(double value, double min, double max) {
    return math.max(min, math.min(max, value));
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class _WeightedValue {
  const _WeightedValue({
    required this.value,
    required this.weight,
  });

  final double value;
  final double weight;
}

class _WeightPoint extends _WeightedValue {
  const _WeightPoint({
    required this.dateKey,
    required super.value,
    required super.weight,
  });

  final String dateKey;
}

extension _TakeLast<T> on List<T> {
  List<T> takeLast(int count) {
    if (length <= count) {
      return List<T>.from(this);
    }
    return sublist(length - count);
  }
}
