import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/domain/adaptive_target_engine.dart';
import 'package:total_tracker/features/profile/domain/profile_codes.dart';

void main() {
  const AdaptiveTargetEngine engine = AdaptiveTargetEngine();
  final DateTime now = DateTime(2026, 7, 2, 12);

  test('missing steps only uses step fallback and is partially provisional',
      () {
    final ResolvedActivityBreakdown result = engine.resolveActivity(
      steps: 0,
      stepGoal: 8000,
      stepKcalCoefficient: 0.025,
      completedWorkoutKcal: 120,
      profileWorkoutDailyKcal: 90,
      fallbackModeCode: ActivityFallbackModeCodes.recordedWithProfileFallback,
      dayDate: DateTime(2026, 7, 2),
      now: now,
    );

    expect(result.effectiveStepKcal, 200);
    expect(result.effectiveWorkoutKcal, 120);
    expect(result.usedStepGoalFallback, isTrue);
    expect(result.usedProfileWorkoutFallback, isFalse);
    expect(result.statusCode, 'partially_provisional');
  });

  test('recorded steps are never replaced when workout is missing', () {
    final ResolvedActivityBreakdown result = engine.resolveActivity(
      steps: 12000,
      stepGoal: 8000,
      stepKcalCoefficient: 0.025,
      completedWorkoutKcal: 0,
      profileWorkoutDailyKcal: 90,
      fallbackModeCode: ActivityFallbackModeCodes.recordedWithProfileFallback,
      dayDate: DateTime(2026, 7, 2),
      now: now,
    );

    expect(result.actualStepKcal, 300);
    expect(result.effectiveStepKcal, 300);
    expect(result.effectiveWorkoutKcal, 90);
    expect(result.usedStepGoalFallback, isFalse);
    expect(result.usedProfileWorkoutFallback, isTrue);
    expect(result.statusCode, 'partially_provisional');
  });

  test('a recorded zero-kcal workout is not replaced by fallback', () {
    final ResolvedActivityBreakdown result = engine.resolveActivity(
      steps: 12000,
      stepGoal: 8000,
      stepKcalCoefficient: 0.025,
      completedWorkoutKcal: 0,
      profileWorkoutDailyKcal: 90,
      fallbackModeCode: ActivityFallbackModeCodes.recordedWithProfileFallback,
      dayDate: DateTime(2026, 7, 2),
      now: now,
      hasRecordedWorkout: true,
    );

    expect(result.effectiveStepKcal, 300);
    expect(result.effectiveWorkoutKcal, 0);
    expect(result.usedProfileWorkoutFallback, isFalse);
    expect(result.statusCode, 'actual');
  });

  test('both missing components use both fallbacks and are provisional', () {
    final ResolvedActivityBreakdown result = engine.resolveActivity(
      steps: 0,
      stepGoal: 8000,
      stepKcalCoefficient: 0.025,
      completedWorkoutKcal: 0,
      profileWorkoutDailyKcal: 90,
      fallbackModeCode: ActivityFallbackModeCodes.recordedWithProfileFallback,
      dayDate: DateTime(2026, 7, 1),
      now: now,
    );

    expect(result.totalKcal, 290);
    expect(result.usedStepGoalFallback, isTrue);
    expect(result.usedProfileWorkoutFallback, isTrue);
    expect(result.statusCode, 'provisional');
  });

  test('legacy profile estimate is component-wise and preserves actual data',
      () {
    final ResolvedActivityBreakdown result = engine.resolveActivity(
      steps: 12000,
      stepGoal: 8000,
      stepKcalCoefficient: 0.025,
      completedWorkoutKcal: 300,
      profileWorkoutDailyKcal: 90,
      fallbackModeCode: ActivityFallbackModeCodes.profileEstimate,
      dayDate: DateTime(2026, 7, 2),
      now: now,
    );

    expect(result.effectiveStepKcal, 300);
    expect(result.effectiveWorkoutKcal, 300);
    expect(result.totalKcal, 600);
    expect(result.statusCode, 'actual');
  });

  test('recorded only mode treats missing data as zero', () {
    final ResolvedActivityBreakdown result = engine.resolveActivity(
      steps: 0,
      stepGoal: 8000,
      stepKcalCoefficient: 0.025,
      completedWorkoutKcal: 0,
      profileWorkoutDailyKcal: 90,
      fallbackModeCode: ActivityFallbackModeCodes.recordedOnly,
      dayDate: DateTime(2026, 7, 2),
      now: now,
    );

    expect(result.totalKcal, 0);
    expect(result.statusCode, 'unavailable');
  });

  test('missing usable weight falls back to profile and disables trend', () {
    final WeightFreshnessResult result = engine.evaluateWeight(
      latestMeasurementWeightKg: null,
      latestMeasurementDate: null,
      latestReliabilityCode: '',
      initialProfileWeightKg: 65,
      referenceDate: DateTime(2026, 7, 2),
    );

    expect(result.effectiveWeightKg, 65);
    expect(result.allowObservedWeightTrend, isFalse);
    expect(result.statusCode, 'profile_fallback');
  });

  test('weight starts warning at 15 days but remains usable', () {
    final WeightFreshnessResult result = engine.evaluateWeight(
      latestMeasurementWeightKg: 64,
      latestMeasurementDate: DateTime(2026, 6, 17),
      latestReliabilityCode: 'normal',
      initialProfileWeightKg: 65,
      referenceDate: DateTime(2026, 7, 2),
    );

    expect(result.daysSinceMeasurement, 15);
    expect(result.effectiveWeightKg, 64);
    expect(result.allowObservedWeightTrend, isTrue);
    expect(result.statusCode, 'aging');
    expect(result.alerts.single.code, 'weight_aging');
  });

  test('weight trend stops at 20 days and falls back to profile weight', () {
    final WeightFreshnessResult result = engine.evaluateWeight(
      latestMeasurementWeightKg: 64,
      latestMeasurementDate: DateTime(2026, 6, 12),
      latestReliabilityCode: 'normal',
      initialProfileWeightKg: 65,
      referenceDate: DateTime(2026, 7, 2),
    );

    expect(result.daysSinceMeasurement, 20);
    expect(result.effectiveWeightKg, 65);
    expect(result.allowObservedWeightTrend, isFalse);
    expect(result.statusCode, 'stale');
    expect(
        result.alerts.single.severityCode, TargetAlertSeverityCodes.critical);
  });
}
