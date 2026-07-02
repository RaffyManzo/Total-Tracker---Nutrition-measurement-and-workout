import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/profile/domain/profile_activity_estimator.dart';

void main() {
  test('cardio estimate contains only active MET above rest', () {
    const ProfileActivityConfig config = ProfileActivityConfig(
      presetCode: ActivityPresetCodes.cardioContinuous,
      sessionsPerWeek: 1,
      cardioDurationMinutes: 60,
      cardioMachineCode: CardioMachineCodes.generic,
      cardioIntensityCode: ActivityIntensityCodes.moderate,
      cardioAvgHeartRate: 0,
    );
    final ProfileActivityEstimate estimate = ProfileActivityEstimator.estimate(
      config: config,
      weightKg: 70,
    );
    expect(estimate.perSessionKcal, closeTo(350, 1));
    expect(estimate.segments.single.grossMet, 6);
    expect(estimate.segments.single.netMet, 5);
  });

  test('weights plus cardio is split into distinct auditable segments', () {
    const ProfileActivityConfig config = ProfileActivityConfig(
      presetCode: ActivityPresetCodes.weightsCardio,
      sessionsPerWeek: 3,
      weightsDurationMinutes: 60,
      cardioDurationMinutes: 20,
      weightSets: 15,
      cardioMachineCode: CardioMachineCodes.treadmill,
      cardioSpeedKmh: 5,
      cardioInclinePercent: 8,
      weightsAvgHeartRate: 92,
      cardioAvgHeartRate: 128,
    );
    final ProfileActivityEstimate estimate = ProfileActivityEstimator.estimate(
      config: config,
      weightKg: 64,
    );
    expect(
      estimate.segments.any(
        (ActivityEstimateSegment segment) => segment.label.contains('Serie'),
      ),
      isTrue,
    );
    expect(
      estimate.segments.any(
        (ActivityEstimateSegment segment) => segment.label.contains('Cardio'),
      ),
      isTrue,
    );
    expect(estimate.dailyKcal, greaterThan(0));
    expect(estimate.calculationLines, isNotEmpty);
    expect(estimate.impacts, isNotEmpty);
  });

  test('every stored configuration field is exposed in the audit', () {
    const ProfileActivityConfig config = ProfileActivityConfig(
      presetCode: ActivityPresetCodes.weights,
    );
    final ProfileActivityEstimate estimate = ProfileActivityEstimator.estimate(
      config: config,
      weightKg: 64,
    );
    final Set<String> exposedKeys = estimate.parameters
        .map((ActivityParameterAudit item) => item.key)
        .where(ActivityFieldKeys.all.contains)
        .toSet();
    expect(exposedKeys, containsAll(ActivityFieldKeys.all));
    expect(exposedKeys.length, ActivityFieldKeys.all.length);
    expect(
      estimate.parameters.any(
        (ActivityParameterAudit item) => !item.usedInEstimate,
      ),
      isTrue,
    );
  });

  test('mixed circuit keeps separate heart-rate inputs', () {
    const ProfileActivityConfig config = ProfileActivityConfig(
      presetCode: ActivityPresetCodes.mixedCircuit,
      mixedWeightsAvgHeartRate: 105,
      mixedCardioAvgHeartRate: 145,
    );
    final ProfileActivityEstimate estimate = ProfileActivityEstimator.estimate(
      config: config,
      weightKg: 64,
    );
    final ActivityEstimateSegment weights = estimate.segments.firstWhere(
      (ActivityEstimateSegment segment) => segment.label.contains('pesi'),
    );
    final ActivityEstimateSegment cardio = estimate.segments.firstWhere(
      (ActivityEstimateSegment segment) => segment.label.contains('cardio'),
    );
    expect(weights.heartRateFactor, isNot(cardio.heartRateFactor));
    expect(
      estimate.impacts.any(
        (ActivityParameterImpact impact) =>
            impact.key == ActivityFieldKeys.mixedWeightsAvgHeartRate,
      ),
      isTrue,
    );
    expect(
      estimate.impacts.any(
        (ActivityParameterImpact impact) =>
            impact.key == ActivityFieldKeys.mixedCardioAvgHeartRate,
      ),
      isTrue,
    );
  });

  test('field sources survive json serialization', () {
    const ProfileActivityConfig config = ProfileActivityConfig(
      fieldSources: <String, String>{
        ActivityFieldKeys.weightSets: ActivityInputSourceCodes.user,
      },
    );
    final ProfileActivityConfig decoded = ProfileActivityConfig.fromJsonString(
      config.toJsonString(),
      legacyWorkoutTypeCode: 'weights',
      legacyDurationMinutes: 60,
      legacySessionsPerWeek: 3,
    );
    expect(
      decoded.sourceFor(ActivityFieldKeys.weightSets),
      ActivityInputSourceCodes.user,
    );
    expect(
      decoded.sourceFor(ActivityFieldKeys.restSeconds),
      ActivityInputSourceCodes.defaultValue,
    );
  });

  test('legacy mixed profile becomes weights plus cardio', () {
    final ProfileActivityConfig config = ProfileActivityConfig.fromJsonString(
      '',
      legacyWorkoutTypeCode: 'mixed',
      legacyDurationMinutes: 90,
      legacySessionsPerWeek: 3,
    );
    expect(config.presetCode, ActivityPresetCodes.weightsCardio);
    expect(config.totalDurationMinutes, 90);
    expect(
      config.sourceFor(ActivityFieldKeys.presetCode),
      ActivityInputSourceCodes.legacy,
    );
  });
}
