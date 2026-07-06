import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/services/food_analytics_service.dart';
import 'package:total_tracker/features/nutrition/data/services/tdee_reliability_score.dart';
import 'package:total_tracker/features/nutrition/domain/adaptive_target_engine.dart';

void main() {
  test('complete observed evidence reaches 100 points', () {
    final TdeeReliabilityScore score = TdeeReliabilityScore.fromTarget(
      _target(
        referenceDays: 28,
        intakeDays: 14,
        weightDays: 8,
        weightAge: 0,
        observedTdee: 2200,
        observedConfidence: 0.8,
        deltaWeight: -0.2,
        activityStatus: 'actual',
      ),
    );

    expect(score.total, 100);
    expect(score.bandCode, 'high');
  });

  test('missing observed evidence remains in the low band', () {
    final TdeeReliabilityScore score = TdeeReliabilityScore.fromTarget(
      _target(
        referenceDays: 0,
        intakeDays: 0,
        weightDays: 0,
        weightAge: null,
        observedTdee: null,
        observedConfidence: 0,
        deltaWeight: null,
        activityStatus: 'unavailable',
      ),
    );

    expect(score.total, 0);
    expect(score.bandCode, 'low');
  });
}

TargetDayResult _target({
  required int referenceDays,
  required int intakeDays,
  required int weightDays,
  required int? weightAge,
  required double? observedTdee,
  required double observedConfidence,
  required double? deltaWeight,
  required String activityStatus,
}) {
  return TargetDayResult(
    targetKcal: 2200,
    targetStatusCode: observedTdee == null ? 'provisional' : 'adaptive',
    tdeeRefKcal: 2200,
    tdeeTheoreticalKcal: 2150,
    tdeeObservedKcal: observedTdee,
    observedConfidence: observedConfidence,
    referenceDaysCount: referenceDays,
    validIntakeDays: intakeDays,
    validWeightDays: weightDays,
    rmrKcal: 1500,
    weightRefKg: 64,
    weightStatusCode: weightAge == null ? 'missing' : 'fresh',
    weightDaysSinceMeasurement: weightAge,
    activeRefKcal: 350,
    activity: ResolvedActivityBreakdown(
      actualStepKcal: activityStatus == 'actual' ? 200 : 0,
      effectiveStepKcal: activityStatus == 'actual' ? 200 : 0,
      actualWorkoutKcal: activityStatus == 'actual' ? 150 : 0,
      effectiveWorkoutKcal: activityStatus == 'actual' ? 150 : 0,
      totalKcal: activityStatus == 'actual' ? 350 : 0,
      statusCode: activityStatus,
      usedStepGoalFallback: false,
      usedProfileWorkoutFallback: false,
    ),
    activityDeltaKcal: 0,
    alerts: const <TargetAlert>[],
    deltaWeightKg: deltaWeight,
    avgCalories: observedTdee == null ? null : 2100,
  );
}
