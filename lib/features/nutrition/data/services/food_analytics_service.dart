import 'dart:math' as math;

import '../../../../core/diagnostics/interaction_trace.dart';

import '../../../profile/data/entities/user_profile_entity.dart';
import '../../../profile/domain/profile_codes.dart';
import '../../../profile/domain/profile_nutrition_calculator.dart';
import '../../../workout/data/entities/workout_tracking_entities.dart';
import '../../../workout/data/repositories/workout_session_repository.dart';
import '../../domain/adaptive_target_engine.dart';
import '../../domain/target_model_constants.dart';
import '../../domain/target_model_math.dart';
import '../entities/nutrition_tracking_entities.dart';
import '../repositories/meal_repository.dart';
import '../repositories/measurement_repository.dart';

class ActivityBreakdown {
  const ActivityBreakdown({
    required this.stepEstimate,
    required this.completedWorkoutKcal,
    required this.actualTotalKcal,
    required this.stepWeightSourceCode,
    required this.hasCompletedWorkoutRecord,
  });

  final StepEnergyEstimate stepEstimate;
  final double completedWorkoutKcal;
  final double actualTotalKcal;
  final String stepWeightSourceCode;
  final bool hasCompletedWorkoutRecord;

  double get stepKcal => stepEstimate.activeKcal;
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
    this.deltaWeightKg,
    this.weightSlopeKgPerDay,
    this.avgCalories,
    this.kcalPerKg = TargetModelConstants.energyDensityPriorKcalPerKg,
    this.targetModelVersion = TargetModelConstants.modelVersion,
    this.rmrEquationCode = TargetModelConstants.rmrEquation,
    this.rmrPhysiologicalCoefficientCode = 'unavailable',
    this.rmrFallbackUsed = false,
    this.observedModelLevelCode = 'theoretical_only',
    this.compositionConfidence = 0,
    this.compositionFallbackReasonCode = 'not_evaluated',
    this.compositionCandidateAvailable = false,
    this.compositionValidDays = 0,
    this.compositionCoverageDays = 0,
    this.compositionMaximumGapDays = 0,
    this.compositionQualityNotes = const <String>[],
    this.fatMassSlopeKgPerDay,
    this.fatFreeMassSlopeKgPerDay,
    this.compositionEnergyChangeKcalPerDay,
    this.effectiveBodyEnergyChangeKcalPerDay,
    this.guardrailApplied = false,
    this.guardrailReasonCode = 'none',
    this.unclampedTargetKcal,
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
  final double? deltaWeightKg;
  final double? weightSlopeKgPerDay;
  final double? avgCalories;
  final double kcalPerKg;
  final String targetModelVersion;
  final String rmrEquationCode;
  final String rmrPhysiologicalCoefficientCode;
  final bool rmrFallbackUsed;
  final String observedModelLevelCode;
  final double compositionConfidence;
  final String compositionFallbackReasonCode;
  final bool compositionCandidateAvailable;
  final int compositionValidDays;
  final int compositionCoverageDays;
  final int compositionMaximumGapDays;
  final List<String> compositionQualityNotes;
  final double? fatMassSlopeKgPerDay;
  final double? fatFreeMassSlopeKgPerDay;
  final double? compositionEnergyChangeKcalPerDay;
  final double? effectiveBodyEnergyChangeKcalPerDay;
  final bool guardrailApplied;
  final String guardrailReasonCode;
  final double? unclampedTargetKcal;
}

class ObservedTdeeResult {
  const ObservedTdeeResult({
    required this.tdeeObserved,
    required this.observedConfidence,
    required this.validIntakeDays,
    required this.validWeightDays,
    required this.deltaWeightKg,
    required this.weightSlopeKgPerDay,
    required this.avgCalories,
    required this.modelLevelCode,
    required this.compositionAssessment,
    required this.guardrailApplied,
    required this.guardrailReasonCode,
    required this.unclampedTdeeObserved,
  });

  final double? tdeeObserved;
  final double observedConfidence;
  final int validIntakeDays;
  final int validWeightDays;
  final double? deltaWeightKg;
  final double? weightSlopeKgPerDay;
  final double? avgCalories;
  final String modelLevelCode;
  final BodyCompositionAssessment compositionAssessment;
  final bool guardrailApplied;
  final String guardrailReasonCode;
  final double? unclampedTdeeObserved;
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
    this.weightSlopeKgPerDay,
    this.targetModelVersion = TargetModelConstants.modelVersion,
    this.rmrEquationCode = TargetModelConstants.rmrEquation,
    this.rmrPhysiologicalCoefficientCode = 'unavailable',
    this.rmrFallbackUsed = false,
    this.observedModelLevelCode = 'theoretical_only',
    this.compositionConfidence = 0,
    this.compositionFallbackReasonCode = 'not_evaluated',
    this.compositionCandidateAvailable = false,
    this.compositionValidDays = 0,
    this.compositionCoverageDays = 0,
    this.compositionMaximumGapDays = 0,
    this.compositionQualityNotes = const <String>[],
    this.fatMassSlopeKgPerDay,
    this.fatFreeMassSlopeKgPerDay,
    this.compositionEnergyChangeKcalPerDay,
    this.effectiveBodyEnergyChangeKcalPerDay,
    this.guardrailApplied = false,
    this.guardrailReasonCode = 'none',
    this.unclampedTargetKcal,
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
  final double? weightSlopeKgPerDay;
  final double? avgCalories;
  final double kcalPerKg;
  final List<TargetAlert> alerts;
  final String targetModelVersion;
  final String rmrEquationCode;
  final String rmrPhysiologicalCoefficientCode;
  final bool rmrFallbackUsed;
  final String observedModelLevelCode;
  final double compositionConfidence;
  final String compositionFallbackReasonCode;
  final bool compositionCandidateAvailable;
  final int compositionValidDays;
  final int compositionCoverageDays;
  final int compositionMaximumGapDays;
  final List<String> compositionQualityNotes;
  final double? fatMassSlopeKgPerDay;
  final double? fatFreeMassSlopeKgPerDay;
  final double? compositionEnergyChangeKcalPerDay;
  final double? effectiveBodyEnergyChangeKcalPerDay;
  final bool guardrailApplied;
  final String guardrailReasonCode;
  final double? unclampedTargetKcal;
}

class FoodAnalyticsService {
  FoodAnalyticsService({
    required MealRepository meals,
    required MeasurementRepository measurements,
    required WorkoutSessionRepository workoutSessions,
    bool diagnosticsEnabled = true,
  })  : _meals = meals,
        _measurements = measurements,
        _workoutSessions = workoutSessions,
        _diagnosticsEnabled = diagnosticsEnabled;

  final MealRepository _meals;
  final MeasurementRepository _measurements;
  final WorkoutSessionRepository _workoutSessions;
  final bool _diagnosticsEnabled;
  final ProfileNutritionCalculator _profileCalculator =
      const ProfileNutritionCalculator();
  final AdaptiveTargetEngine _targetEngine = const AdaptiveTargetEngine();

  /// Nutrition-side adapter for the workout contract `estimated_active_calories`.
  /// The nutrition target engine consumes the value exposed by the completed
  /// workout and does not derive workout calories from exercise details.
  double _estimatedActiveCalories(WorkoutSessionEntity session) {
    return math.max(0.0, session.estimatedKcalBurned ?? 0.0);
  }

  ActivityBreakdown activityForDay(
    DailyRecordEntity day, {
    UserProfileEntity? profile,
  }) {
    final List<WorkoutSessionEntity> completedSessions =
        _workoutSessions.completedForDate(day.dateKey);
    final double completedFromSessions = completedSessions.fold<double>(
      0,
      (double sum, WorkoutSessionEntity session) =>
          sum + _estimatedActiveCalories(session),
    );
    final double cachedCompleted =
        math.max(0.0, day.activeKcalWorkoutCompleted ?? 0.0);
    final double fallbackCompleted =
        math.max(completedFromSessions, cachedCompleted);
    final bool hasCompletedWorkoutRecord =
        completedSessions.isNotEmpty || cachedCompleted > 0;
    if (profile == null) {
      final StepEnergyEstimate legacyEstimate = TargetModelMath.estimateSteps(
        steps: day.steps,
        weightKg: 70,
        legacyKcalPerStep: TargetModelConstants.legacyStepKcalCoefficient,
      );
      return ActivityBreakdown(
        stepEstimate: legacyEstimate,
        completedWorkoutKcal: fallbackCompleted,
        actualTotalKcal: legacyEstimate.activeKcal + fallbackCompleted,
        stepWeightSourceCode: 'fallback_profile_70',
        hasCompletedWorkoutRecord: hasCompletedWorkoutRecord,
      );
    }

    final _DailyScaleAggregate? aggregate =
        _latestScaleAggregateOnOrBefore(day.dateKey);
    final double weightKg =
        aggregate?.weightKg ?? profile.initialWeightKg ?? 70;
    final String weightSource = aggregate != null
        ? (aggregate.dateKey == day.dateKey
            ? 'day_scale_median'
            : 'latest_previous_scale_median')
        : profile.initialWeightKg != null
            ? 'initial_profile'
            : 'fallback_profile_70';
    final StepEnergyEstimate stepEstimate = TargetModelMath.estimateSteps(
      steps: day.steps,
      weightKg: weightKg,
      heightCm: profile.heightCm,
      legacyKcalPerStep: profile.stepKcalCoefficient <= 0
          ? TargetModelConstants.legacyStepKcalCoefficient
          : profile.stepKcalCoefficient,
    );
    return ActivityBreakdown(
      stepEstimate: stepEstimate,
      completedWorkoutKcal: fallbackCompleted,
      actualTotalKcal: stepEstimate.activeKcal + fallbackCompleted,
      stepWeightSourceCode: weightSource,
      hasCompletedWorkoutRecord: hasCompletedWorkoutRecord,
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
        stepKcalCoefficient: actual.stepEstimate.effectiveKcalPerStep,
        actualStepKcalOverride: actual.stepEstimate.activeKcal,
        hasRecordedSteps: day.steps > 0,
        hasRecordedWorkout: actual.hasCompletedWorkoutRecord,
        targetStepKcalOverride: TargetModelMath.estimateSteps(
          steps: day.stepGoal,
          weightKg: actual.stepEstimate.weightKg,
          legacyKcalPerStep: TargetModelConstants.legacyStepKcalCoefficient,
        ).activeKcal,
        completedWorkoutKcal: actual.completedWorkoutKcal,
        profileWorkoutDailyKcal: 0,
        fallbackModeCode: ActivityFallbackModeCodes.recordedOnly,
        dayDate: DateTime.parse(day.dateKey),
        now: now ?? DateTime.now(),
        stepLengthMeters: actual.stepEstimate.stepLengthMeters,
        stepLengthSourceCode: actual.stepEstimate.stepLengthSourceCode,
        stepCoefficientSourceCode: actual.stepEstimate.coefficientSourceCode,
        stepWeightSourceCode: actual.stepWeightSourceCode,
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
    final int fallbackStepGoal =
        day.stepGoal <= 0 ? profile.defaultStepGoal : day.stepGoal;
    final StepEnergyEstimate fallbackSteps = TargetModelMath.estimateSteps(
      steps: fallbackStepGoal,
      weightKg: actual.stepEstimate.weightKg,
      heightCm: profile.heightCm,
      legacyKcalPerStep: profile.stepKcalCoefficient <= 0
          ? TargetModelConstants.legacyStepKcalCoefficient
          : profile.stepKcalCoefficient,
    );
    final String effectiveFallbackMode = profile.activityFallbackModeCode ==
            ActivityFallbackModeCodes.recordedOnly
        ? ActivityFallbackModeCodes.recordedOnly
        : ActivityFallbackModeCodes.recordedWithProfileFallback;
    return _targetEngine.resolveActivity(
      steps: day.steps,
      stepGoal: fallbackStepGoal,
      stepKcalCoefficient: actual.stepEstimate.effectiveKcalPerStep,
      actualStepKcalOverride: actual.stepEstimate.activeKcal,
      targetStepKcalOverride: fallbackSteps.activeKcal,
      hasRecordedSteps: day.steps > 0,
      hasRecordedWorkout: actual.hasCompletedWorkoutRecord,
      completedWorkoutKcal: actual.completedWorkoutKcal,
      profileWorkoutDailyKcal: profileTargets.workoutDailyKcal,
      fallbackModeCode: effectiveFallbackMode,
      dayDate: dayDate,
      now: resolvedNow,
      stepLengthMeters: actual.stepEstimate.stepLengthMeters,
      stepLengthSourceCode: actual.stepEstimate.stepLengthSourceCode,
      stepCoefficientSourceCode: actual.stepEstimate.coefficientSourceCode,
      stepWeightSourceCode: actual.stepWeightSourceCode,
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
    final WeekAdaptiveSummary summary = adaptiveSummaryForDay(
      dayDate: date,
      allDays: allDays,
      profile: profile,
      now: resolvedNow,
    );
    final double activityDelta = activity.totalKcal - summary.activeRefKcal;
    final GuardrailResult dayGuardrail = TargetModelMath.applyGuardrail(
      value: summary.tdeeRefKcal + activityDelta,
      minimum: profile.minimumReasonableTdee,
      maximum: profile.maximumReasonableTdee,
    );
    final double target = dayGuardrail.value;
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
      targetStatusCode: activity.statusCode == 'partially_provisional'
          ? 'partially_provisional'
          : activity.statusCode == 'provisional'
              ? 'provisional'
              : summary.targetStatusCode,
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
      deltaWeightKg: summary.deltaWeightKg,
      weightSlopeKgPerDay: summary.weightSlopeKgPerDay,
      avgCalories: summary.avgCalories,
      kcalPerKg: summary.kcalPerKg,
      targetModelVersion: summary.targetModelVersion,
      rmrEquationCode: summary.rmrEquationCode,
      rmrPhysiologicalCoefficientCode: summary.rmrPhysiologicalCoefficientCode,
      rmrFallbackUsed: summary.rmrFallbackUsed,
      observedModelLevelCode: summary.observedModelLevelCode,
      compositionConfidence: summary.compositionConfidence,
      compositionFallbackReasonCode: summary.compositionFallbackReasonCode,
      compositionCandidateAvailable: summary.compositionCandidateAvailable,
      compositionValidDays: summary.compositionValidDays,
      compositionCoverageDays: summary.compositionCoverageDays,
      compositionMaximumGapDays: summary.compositionMaximumGapDays,
      compositionQualityNotes: summary.compositionQualityNotes,
      fatMassSlopeKgPerDay: summary.fatMassSlopeKgPerDay,
      fatFreeMassSlopeKgPerDay: summary.fatFreeMassSlopeKgPerDay,
      compositionEnergyChangeKcalPerDay:
          summary.compositionEnergyChangeKcalPerDay,
      effectiveBodyEnergyChangeKcalPerDay:
          summary.effectiveBodyEnergyChangeKcalPerDay,
      guardrailApplied: dayGuardrail.applied || summary.guardrailApplied,
      guardrailReasonCode: dayGuardrail.applied
          ? dayGuardrail.reasonCode
          : summary.guardrailReasonCode,
      unclampedTargetKcal: dayGuardrail.unclampedValue,
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
      result.targetModelVersion,
      result.targetStatusCode,
      result.referenceDaysCount,
      result.validIntakeDays,
      result.validWeightDays,
      result.weightStatusCode,
      result.activity.statusCode,
      result.activity.usedStepGoalFallback,
      result.activity.usedProfileWorkoutFallback,
      result.observedModelLevelCode,
      result.compositionFallbackReasonCode,
      result.guardrailReasonCode,
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
    day.activeKcalWorkoutCompleted = math.max(
      workoutByStatus['completed'] ?? 0,
      result.activity.actualWorkoutKcal,
    );
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
    return _scaleAggregateForDate(day.dateKey)?.weightKg ?? day.weightKg;
  }

  /// Builds the adaptive baseline for one specific calendar day.
  ///
  /// The existing weekly routine is reused as the audited mathematical core,
  /// but its window is pinned to [normalizedDay]. Therefore reference records
  /// are strictly earlier than the requested day and the current period
  /// contains only that day. The caller still resolves actual/predicted daily
  /// activity against the real current time.
  WeekAdaptiveSummary adaptiveSummaryForDay({
    required DateTime dayDate,
    required List<DailyRecordEntity> allDays,
    UserProfileEntity? profile,
    DateTime? now,
  }) {
    final DateTime normalizedDay =
        DateTime(dayDate.year, dayDate.month, dayDate.day);
    final String dayKey = _dateKey(normalizedDay);
    final List<DailyRecordEntity> scopedDays = allDays
        .where(
          (DailyRecordEntity day) => day.dateKey.compareTo(dayKey) <= 0,
        )
        .toList(growable: false);
    return adaptiveSummaryForWeek(
      monday: normalizedDay,
      allDays: scopedDays,
      profile: profile,
      now: normalizedDay,
      activityNow: now ?? DateTime.now(),
    );
  }

  WeekAdaptiveSummary adaptiveSummaryForWeek({
    required DateTime monday,
    required List<DailyRecordEntity> allDays,
    UserProfileEntity? profile,
    DateTime? now,
    DateTime? activityNow,
  }) {
    final Stopwatch adaptiveDiagnosticsWatch = Stopwatch()..start();
    final DateTime resolvedNow = now ?? DateTime.now();
    final DateTime resolvedActivityNow = activityNow ?? resolvedNow;
    final DateTime sunday = monday.add(const Duration(days: 6));
    final DateTime referenceDate =
        sunday.isAfter(resolvedNow) ? resolvedNow : sunday;
    final String mondayKey = _dateKey(monday);
    final List<DailyRecordEntity> sorted = List<DailyRecordEntity>.from(allDays)
      ..sort((DailyRecordEntity a, DailyRecordEntity b) {
        return a.dateKey.compareTo(b.dateKey);
      });
    final int referenceLimit = profile?.adaptiveReferenceDays ?? 28;
    final String referenceStartKey = _dateKey(
      monday.subtract(Duration(days: referenceLimit)),
    );
    final List<DailyRecordEntity> reference = sorted
        .where(
          (DailyRecordEntity day) =>
              day.dateKey.compareTo(referenceStartKey) >= 0 &&
              day.dateKey.compareTo(mondayKey) < 0,
        )
        .toList();
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

    final Stopwatch activityHistoryWatch = Stopwatch()..start();
    final List<ResolvedActivityBreakdown> historicalActivity = reference
        .map(
          (DailyRecordEntity day) => effectiveActivityForDay(
            day,
            profile: profile,
            now: resolvedActivityNow,
          ),
        )
        .toList(growable: false);
    final List<double> activeValues = historicalActivity
        .where(
          (ResolvedActivityBreakdown item) => item.statusCode != 'unavailable',
        )
        .map((ResolvedActivityBreakdown item) => item.totalKcal)
        .toList(growable: false);
    activityHistoryWatch.stop();
    final bool allowProfileFallback = profile?.activityFallbackModeCode !=
        ActivityFallbackModeCodes.recordedOnly;
    final bool historyUsesComponentFallback = historicalActivity.any(
      (ResolvedActivityBreakdown item) =>
          item.usedStepGoalFallback || item.usedProfileWorkoutFallback,
    );
    final double activeRef;
    final String activeRefSourceCode;
    if (activeValues.isNotEmpty) {
      activeRef = _average(activeValues) ?? 0;
      activeRefSourceCode = historyUsesComponentFallback
          ? 'component_fallback_history'
          : 'recorded_history';
    } else if (allowProfileFallback) {
      activeRef = profileActivity;
      activeRefSourceCode = 'profile_fallback';
    } else {
      activeRef = 0;
      activeRefSourceCode = 'unavailable';
    }

    final Stopwatch currentActivityWatch = Stopwatch()..start();
    final List<ResolvedActivityBreakdown> currentActivity = currentWeek
        .map(
          (DailyRecordEntity day) => effectiveActivityForDay(
            day,
            profile: profile,
            now: resolvedActivityNow,
          ),
        )
        .toList();
    currentActivityWatch.stop();
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
    final List<_DailyScaleAggregate> measurementAggregates =
        _scaleAggregatesInRange(
      startInclusive: referenceStartKey,
      endExclusive: mondayKey,
    );
    final Stopwatch observedTdeeWatch = Stopwatch()..start();
    final ObservedTdeeResult observed = _calculateObservedTdee(
      reference,
      measurementAggregates: measurementAggregates,
      minimumObservedDays: profile?.adaptiveMinimumObservedDays ?? 7,
      kcalPerKg: TargetModelConstants.energyDensityPriorKcalPerKg,
      minTdee: profile?.minimumReasonableTdee ?? 1300,
      maxTdee: profile?.maximumReasonableTdee ?? 4600,
      allowWeightTrend: weight.allowObservedWeightTrend,
    );
    observedTdeeWatch.stop();
    final double confidence =
        observed.tdeeObserved == null ? 0 : observed.observedConfidence;
    final double calculated = observed.tdeeObserved == null
        ? theoretical
        : confidence * observed.tdeeObserved! + (1 - confidence) * theoretical;
    final GuardrailResult tdeeGuardrail = TargetModelMath.applyGuardrail(
      value: calculated,
      minimum: profile?.minimumReasonableTdee ??
          TargetModelConstants.minimumReasonableTdee,
      maximum: profile?.maximumReasonableTdee ??
          TargetModelConstants.maximumReasonableTdee,
    );
    final double tdeeRef = tdeeGuardrail.value;
    final double activityDelta = currentWeekActive - activeRef;
    final GuardrailResult targetGuardrail = TargetModelMath.applyGuardrail(
      value: tdeeRef + activityDelta,
      minimum: profile?.minimumReasonableTdee ??
          TargetModelConstants.minimumReasonableTdee,
      maximum: profile?.maximumReasonableTdee ??
          TargetModelConstants.maximumReasonableTdee,
    );
    final double target = targetGuardrail.value;
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
    } else if (activeRefSourceCode == 'component_fallback_history') {
      alerts.add(
        const TargetAlert(
          code: 'activity_history_partially_estimated',
          title: 'Attività storica parzialmente stimata',
          message: 'Nei giorni storici ogni componente registrata è stata '
              'mantenuta; il fallback è stato applicato soltanto a passi o '
              'allenamenti mancanti.',
          severityCode: TargetAlertSeverityCodes.info,
        ),
      );
    }
    if (observed.compositionAssessment.selectedLevelCode ==
        'composition_blended') {
      alerts.add(
        TargetAlert(
          code: 'body_composition_active',
          title: 'Composizione corporea integrata',
          message: 'Il trend energetico combina massa grassa, massa priva di '
              'grasso e prior del peso con confidenza '
              '${(observed.compositionAssessment.compositionConfidence * 100).round()}%.',
          severityCode: TargetAlertSeverityCodes.info,
        ),
      );
    } else if (observed.compositionAssessment.candidateAvailable) {
      alerts.add(
        TargetAlert(
          code: 'body_composition_fallback',
          title: 'Composizione corporea non utilizzata',
          message: _compositionFallbackMessage(
            observed.compositionAssessment,
          ),
          severityCode: TargetAlertSeverityCodes.info,
        ),
      );
    }

    adaptiveDiagnosticsWatch.stop();
    if (_diagnosticsEnabled) {
      InteractionTrace.event(
        'tdee.adaptive_summary.breakdown',
        data: <String, Object?>{
          'dayKey': mondayKey,
          'referenceDayCount': reference.length,
          'currentDayCount': currentWeek.length,
          'activityHistoryMs': activityHistoryWatch.elapsedMilliseconds,
          'currentActivityMs': currentActivityWatch.elapsedMilliseconds,
          'observedTdeeMs': observedTdeeWatch.elapsedMilliseconds,
          'totalMs': adaptiveDiagnosticsWatch.elapsedMilliseconds,
          'validIntakeDays': observed.validIntakeDays,
          'validWeightDays': observed.validWeightDays,
          'compositionValidDays': observed.compositionAssessment.validDays,
          'compositionCoverageDays':
              observed.compositionAssessment.coverageDays,
          'compositionMaximumGapDays':
              observed.compositionAssessment.maximumGapDays,
          'compositionFallbackReason':
              observed.compositionAssessment.fallbackReasonCode,
          'observedAvailable': observed.tdeeObserved != null,
          'activityReferenceSource': activeRefSourceCode,
        },
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
      weightSlopeKgPerDay: observed.weightSlopeKgPerDay,
      avgCalories: observed.avgCalories,
      kcalPerKg: TargetModelConstants.energyDensityPriorKcalPerKg,
      alerts: alerts,
      rmrEquationCode: profileTargets?.rmrEquationCode ?? 'unavailable',
      rmrPhysiologicalCoefficientCode:
          profileTargets?.rmrPhysiologicalCoefficientCode ?? 'unavailable',
      rmrFallbackUsed: profileTargets?.rmrFallbackUsed ?? true,
      observedModelLevelCode: observed.modelLevelCode,
      compositionConfidence:
          observed.compositionAssessment.compositionConfidence,
      compositionFallbackReasonCode:
          observed.compositionAssessment.fallbackReasonCode,
      compositionCandidateAvailable:
          observed.compositionAssessment.candidateAvailable,
      compositionValidDays: observed.compositionAssessment.validDays,
      compositionCoverageDays: observed.compositionAssessment.coverageDays,
      compositionMaximumGapDays: observed.compositionAssessment.maximumGapDays,
      compositionQualityNotes: observed.compositionAssessment.qualityNotes,
      fatMassSlopeKgPerDay: observed.compositionAssessment.fatMassSlopeKgPerDay,
      fatFreeMassSlopeKgPerDay:
          observed.compositionAssessment.fatFreeMassSlopeKgPerDay,
      compositionEnergyChangeKcalPerDay:
          observed.compositionAssessment.compositionEnergyChangeKcalPerDay,
      effectiveBodyEnergyChangeKcalPerDay:
          observed.compositionAssessment.effectiveEnergyChangeKcalPerDay,
      guardrailApplied: targetGuardrail.applied || tdeeGuardrail.applied,
      guardrailReasonCode: targetGuardrail.applied
          ? targetGuardrail.reasonCode
          : tdeeGuardrail.reasonCode,
      unclampedTargetKcal: targetGuardrail.unclampedValue,
    );
  }

  ObservedTdeeResult _calculateObservedTdee(
    List<DailyRecordEntity> referenceDays, {
    required List<_DailyScaleAggregate> measurementAggregates,
    required int minimumObservedDays,
    required double kcalPerKg,
    required double minTdee,
    required double maxTdee,
    required bool allowWeightTrend,
  }) {
    final List<_WeightedValue> intakeDays = <_WeightedValue>[];
    final List<_WeightPoint> weightPoints = <_WeightPoint>[];
    final List<DailyBodyCompositionPoint> compositionPoints =
        <DailyBodyCompositionPoint>[];

    for (final DailyRecordEntity day in referenceDays) {
      final String freeMode = freeMealModeForDate(day.dateKey);
      final double intakeReliability = _intakeReliabilityForMode(freeMode);
      final double kcal = caloriesForDate(day.dateKey);
      if (kcal > 0 && intakeReliability > 0) {
        intakeDays.add(_WeightedValue(value: kcal, weight: intakeReliability));
      }
    }

    for (final _DailyScaleAggregate aggregate in measurementAggregates) {
      final DailyBodyCompositionPoint? composition = aggregate.compositionPoint;
      if (composition != null) {
        compositionPoints.add(composition);
      }
    }

    if (allowWeightTrend) {
      final Map<String, _WeightedValue> weightsByDate =
          <String, _WeightedValue>{};
      for (final _DailyScaleAggregate aggregate in measurementAggregates) {
        if (aggregate.weightKg > 0 && aggregate.reliabilityWeight > 0.25) {
          weightsByDate[aggregate.dateKey] = _WeightedValue(
            value: aggregate.weightKg,
            weight: aggregate.reliabilityWeight,
          );
        }
      }

      for (final DailyRecordEntity day in referenceDays) {
        final double? fallbackWeight = day.weightKg;
        if (!weightsByDate.containsKey(day.dateKey) &&
            fallbackWeight != null &&
            fallbackWeight > 0) {
          weightsByDate[day.dateKey] = _WeightedValue(
            value: fallbackWeight,
            weight: 0.75,
          );
        }
      }

      final List<String> weightDates = weightsByDate.keys.toList()..sort();
      if (weightDates.isNotEmpty) {
        final DateTime trendOrigin = DateTime.parse(weightDates.first);
        for (final String dateKey in weightDates) {
          final _WeightedValue candidate = weightsByDate[dateKey]!;
          weightPoints.add(
            _WeightPoint(
              dateKey: dateKey,
              dayIndex: DateTime.parse(dateKey)
                  .difference(trendOrigin)
                  .inDays
                  .toDouble(),
              value: candidate.value,
              weight: candidate.weight,
            ),
          );
        }
      }
    }

    final double? averageCalories =
        intakeDays.isEmpty ? null : _weightedAverage(intakeDays);
    final BodyCompositionAssessment composition =
        TargetModelMath.assessBodyComposition(compositionPoints);

    if (intakeDays.length < minimumObservedDays ||
        weightPoints.length < 4 ||
        averageCalories == null) {
      return ObservedTdeeResult(
        tdeeObserved: null,
        observedConfidence:
            intakeDays.length < minimumObservedDays ? 0.10 : 0.15,
        validIntakeDays: intakeDays.length,
        validWeightDays: weightPoints.length,
        deltaWeightKg: null,
        weightSlopeKgPerDay: null,
        avgCalories: averageCalories,
        modelLevelCode: 'theoretical_only',
        compositionAssessment: composition,
        guardrailApplied: false,
        guardrailReasonCode: 'none',
        unclampedTdeeObserved: null,
      );
    }

    final double? weightSlope = TargetModelMath.theilSenSlope(
      weightPoints.map(
        (_WeightPoint point) => TrendPoint(
          dayIndex: point.dayIndex,
          value: point.value,
        ),
      ),
    );
    if (weightSlope == null) {
      return ObservedTdeeResult(
        tdeeObserved: null,
        observedConfidence: 0.15,
        validIntakeDays: intakeDays.length,
        validWeightDays: weightPoints.length,
        deltaWeightKg: null,
        weightSlopeKgPerDay: null,
        avgCalories: averageCalories,
        modelLevelCode: 'theoretical_only',
        compositionAssessment: composition,
        guardrailApplied: false,
        guardrailReasonCode: 'none',
        unclampedTdeeObserved: null,
      );
    }

    final double elapsedDays = math.max(
      1.0,
      weightPoints.last.dayIndex - weightPoints.first.dayIndex,
    );
    final double deltaWeightKg = weightSlope * elapsedDays;
    final bool compositionActive =
        composition.selectedLevelCode == 'composition_blended' &&
            composition.effectiveEnergyChangeKcalPerDay != null;
    final double bodyEnergyChange = compositionActive
        ? composition.effectiveEnergyChangeKcalPerDay!
        : weightSlope * kcalPerKg;
    final double observed = averageCalories - bodyEnergyChange;
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
    final GuardrailResult guardrail = TargetModelMath.applyGuardrail(
      value: observed,
      minimum: minTdee,
      maximum: maxTdee,
    );
    return ObservedTdeeResult(
      tdeeObserved: guardrail.value,
      observedConfidence: observedConfidence,
      validIntakeDays: intakeDays.length,
      validWeightDays: weightPoints.length,
      deltaWeightKg: deltaWeightKg,
      weightSlopeKgPerDay: weightSlope,
      avgCalories: averageCalories,
      modelLevelCode: compositionActive ? 'composition_blended' : 'weight_only',
      compositionAssessment: composition,
      guardrailApplied: guardrail.applied,
      guardrailReasonCode: guardrail.reasonCode,
      unclampedTdeeObserved: guardrail.unclampedValue,
    );
  }

  WeightFreshnessResult _weightFreshnessForDate({
    required String dateKey,
    required UserProfileEntity profile,
    required DateTime referenceDate,
  }) {
    final _DailyScaleAggregate? latest =
        _latestScaleAggregateOnOrBefore(dateKey);
    return _targetEngine.evaluateWeight(
      latestMeasurementWeightKg: latest?.weightKg,
      latestMeasurementDate:
          latest == null ? null : DateTime.tryParse(latest.dateKey),
      latestReliabilityCode: latest?.reliabilityCode ?? '',
      initialProfileWeightKg: profile.initialWeightKg,
      referenceDate: referenceDate,
    );
  }

  List<_DailyScaleAggregate> _scaleAggregatesInRange({
    required String startInclusive,
    required String endExclusive,
  }) {
    final Map<String, List<ScaleMeasurementEntity>> grouped =
        <String, List<ScaleMeasurementEntity>>{};
    for (final ScaleMeasurementEntity item
        in _measurements.getScaleMeasurements()) {
      if (item.dateKey.compareTo(startInclusive) < 0 ||
          item.dateKey.compareTo(endExclusive) >= 0 ||
          item.weightKg == null ||
          item.weightKg! <= 0) {
        continue;
      }
      grouped
          .putIfAbsent(item.dateKey, () => <ScaleMeasurementEntity>[])
          .add(item);
    }
    final List<String> keys = grouped.keys.toList()..sort();
    return keys
        .map(
          (String dateKey) =>
              _aggregateScaleMeasurements(dateKey, grouped[dateKey]!),
        )
        .whereType<_DailyScaleAggregate>()
        .toList(growable: false);
  }

  _DailyScaleAggregate? _scaleAggregateForDate(String dateKey) {
    final List<ScaleMeasurementEntity> items = _measurements
        .getScaleMeasurements()
        .where(
          (ScaleMeasurementEntity item) =>
              item.dateKey == dateKey &&
              item.weightKg != null &&
              item.weightKg! > 0,
        )
        .toList(growable: false);
    return _aggregateScaleMeasurements(dateKey, items);
  }

  _DailyScaleAggregate? _latestScaleAggregateOnOrBefore(String dateKey) {
    final Map<String, List<ScaleMeasurementEntity>> grouped =
        <String, List<ScaleMeasurementEntity>>{};
    for (final ScaleMeasurementEntity item
        in _measurements.getScaleMeasurements()) {
      if (item.dateKey.compareTo(dateKey) > 0 ||
          item.weightKg == null ||
          item.weightKg! <= 0) {
        continue;
      }
      grouped
          .putIfAbsent(item.dateKey, () => <ScaleMeasurementEntity>[])
          .add(item);
    }
    if (grouped.isEmpty) {
      return null;
    }
    final List<String> keys = grouped.keys.toList()..sort();
    final String latestKey = keys.last;
    return _aggregateScaleMeasurements(latestKey, grouped[latestKey]!);
  }

  _DailyScaleAggregate? _aggregateScaleMeasurements(
    String dateKey,
    List<ScaleMeasurementEntity> items,
  ) {
    final List<ScaleMeasurementEntity> valid = items
        .where(
          (ScaleMeasurementEntity item) =>
              item.weightKg != null && item.weightKg! > 0,
        )
        .toList(growable: false);
    if (valid.isEmpty) {
      return null;
    }
    final double weightKg = TargetModelMath.median(
      valid.map((ScaleMeasurementEntity item) => item.weightKg!),
    );
    final String reliabilityCode = valid.any(
      (ScaleMeasurementEntity item) => item.reliabilityCode == 'low',
    )
        ? 'low'
        : 'normal';
    final List<double> fatMassValues = <double>[];
    final List<double> fatFreeValues = <double>[];
    final List<double> waterValues = <double>[];
    final Set<String> devices = <String>{};
    for (final ScaleMeasurementEntity item in valid) {
      final double? fatPercent = item.bodyFatPercent;
      if (fatPercent != null && fatPercent >= 0 && fatPercent <= 100) {
        final BodyCompositionMass? composition =
            TargetModelMath.deriveBodyCompositionMass(
          weightKg: item.weightKg!,
          bodyFatPercent: fatPercent,
        );
        if (composition != null) {
          fatMassValues.add(composition.fatMassKg);
          fatFreeValues.add(composition.fatFreeMassKg);
        }
      }
      final double? water = item.waterPercent;
      if (water != null && water >= 0 && water <= 100) {
        waterValues.add(water);
      }
      if (item.device.trim().isNotEmpty) {
        devices.add(item.device.trim());
      }
    }
    DailyBodyCompositionPoint? compositionPoint;
    if (fatMassValues.isNotEmpty && fatFreeValues.isNotEmpty) {
      final double fatMassKg = TargetModelMath.median(fatMassValues);
      final double fatFreeMassKg = TargetModelMath.median(fatFreeValues);
      compositionPoint = DailyBodyCompositionPoint(
        dateKey: dateKey,
        weightKg: fatMassKg + fatFreeMassKg,
        fatMassKg: fatMassKg,
        fatFreeMassKg: fatFreeMassKg,
        deviceCode: devices.length == 1
            ? devices.first
            : (devices.isEmpty ? 'unspecified' : 'mixed'),
        waterPercent:
            waterValues.isEmpty ? null : TargetModelMath.median(waterValues),
      );
    }
    return _DailyScaleAggregate(
      dateKey: dateKey,
      weightKg: weightKg,
      reliabilityCode: reliabilityCode,
      measurementCount: valid.length,
      compositionPoint: compositionPoint,
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

  String _compositionFallbackMessage(
    BodyCompositionAssessment assessment,
  ) {
    final String evidence = 'Dati validi: ${assessment.validDays} giorni, '
        'copertura ${assessment.coverageDays} giorni, intervallo massimo '
        '${assessment.maximumGapDays} giorni.';
    final String reason = switch (assessment.fallbackReasonCode) {
      'insufficient_composition_days' =>
        'Servono almeno ${TargetModelConstants.compositionMinimumDistinctDays} '
            'giorni distinti con peso e percentuale di grasso.',
      'device_changed' =>
        'Le misurazioni risultano associate a dispositivi differenti.',
      'insufficient_temporal_coverage' =>
        'Servono almeno ${TargetModelConstants.compositionMinimumCoverageDays} '
            'giorni tra la prima e l’ultima misurazione.',
      'composition_gap_too_large' => 'Tra due misurazioni intercorrono più di '
          '${TargetModelConstants.compositionMaximumGapDays} giorni.',
      'composition_trend_unavailable' =>
        'Non è possibile stimare un trend robusto dai dati disponibili.',
      'implausible_composition_trend' =>
        'Il trend supera i limiti di plausibilità configurati.',
      'water_variation_too_large' =>
        'La variazione dell’acqua corporea è troppo ampia per usare la BIA.',
      'composition_confidence_too_low' =>
        'La confidenza complessiva è inferiore al '
            '${(TargetModelConstants.compositionMinimumConfidence * 100).round()}%.',
      _ => 'La composizione non supera i controlli di qualità configurati.',
    };
    return '$reason $evidence Il sistema usa temporaneamente il trend del peso.';
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
    if (statuses.contains('provisional')) {
      return 'provisional';
    }
    if (statuses.contains('partially_provisional')) {
      return 'partially_provisional';
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
    } else if (result.activity.statusCode == 'partially_provisional') {
      score += 0.2;
    } else if (result.activity.statusCode == 'provisional') {
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
    required this.dayIndex,
    required super.value,
    required super.weight,
  });

  final String dateKey;
  final double dayIndex;
}

class _DailyScaleAggregate {
  const _DailyScaleAggregate({
    required this.dateKey,
    required this.weightKg,
    required this.reliabilityCode,
    required this.measurementCount,
    required this.compositionPoint,
  });

  final String dateKey;
  final double weightKg;
  final String reliabilityCode;
  final int measurementCount;
  final DailyBodyCompositionPoint? compositionPoint;

  double get reliabilityWeight => reliabilityCode == 'low' ? 0.5 : 1;
}
