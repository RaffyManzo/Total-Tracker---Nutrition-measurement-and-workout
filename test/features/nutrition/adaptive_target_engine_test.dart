import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/domain/adaptive_target_engine.dart';
import 'package:total_tracker/features/profile/domain/profile_codes.dart';

void main() {
  const AdaptiveTargetEngine engine = AdaptiveTargetEngine();
  final DateTime now = DateTime(2026, 7, 2, 12);

  test('current day uses profile fallbacks only for missing activity', () {
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
    expect(result.statusCode, 'mixed');
  });

  test('past days never invent missing activity in default mode', () {
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

    expect(result.totalKcal, 0);
    expect(result.usedStepGoalFallback, isFalse);
    expect(result.usedProfileWorkoutFallback, isFalse);
    expect(result.statusCode, 'unavailable');
  });

  test('profile estimate mode always uses configured estimates', () {
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

    expect(result.actualStepKcal, 300);
    expect(result.actualWorkoutKcal, 300);
    expect(result.effectiveStepKcal, 200);
    expect(result.effectiveWorkoutKcal, 90);
    expect(result.totalKcal, 290);
    expect(result.statusCode, 'estimated');
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

  test('missing scale weight uses initial profile weight provisionally', () {
    final WeightFreshnessResult result = engine.evaluateWeight(
      latestMeasurementWeightKg: null,
      latestMeasurementDate: null,
      latestReliabilityCode: '',
      initialProfileWeightKg: 65,
      referenceDate: DateTime(2026, 7, 2),
    );

    expect(result.effectiveWeightKg, 65);
    expect(result.sourceCode, 'initial_profile');
    expect(result.allowObservedWeightTrend, isFalse);
    expect(result.alerts.single.code, 'weight_missing');
  });
}
