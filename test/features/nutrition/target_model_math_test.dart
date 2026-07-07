import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/domain/target_model_math.dart';

void main() {
  test('step formula reacts to weight and exposes distance', () {
    final StepEnergyEstimate light = TargetModelMath.estimateSteps(
      steps: 10000,
      weightKg: 60,
      heightCm: 160,
    );
    final StepEnergyEstimate heavy = TargetModelMath.estimateSteps(
      steps: 10000,
      weightKg: 80,
      heightCm: 160,
    );

    expect(light.stepLengthMeters, closeTo(0.672, 0.000001));
    expect(light.distanceKm, closeTo(6.72, 0.000001));
    expect(light.activeKcal, closeTo(201.6, 0.0001));
    expect(heavy.activeKcal, closeTo(268.8, 0.0001));
  });

  test('legacy step coefficient is used only when height is unavailable', () {
    final StepEnergyEstimate result = TargetModelMath.estimateSteps(
      steps: 1000,
      weightKg: 70,
    );

    expect(result.usedLegacyFallback, isTrue);
    expect(result.activeKcal, 20);
    expect(result.coefficientSourceCode, 'legacy_fixed_0_020');
  });

  test('observed TDEE uses positive and negative weight slopes', () {
    expect(
      TargetModelMath.observedTdeeFromWeightSlope(
        meanValidEnergyIntake: 2000,
        weightSlopeKgPerDay: 0.01,
      ),
      closeTo(1923, 0.0001),
    );
    expect(
      TargetModelMath.observedTdeeFromWeightSlope(
        meanValidEnergyIntake: 2000,
        weightSlopeKgPerDay: -0.01,
      ),
      closeTo(2077, 0.0001),
    );
  });

  test('fat and fat-free mass are derived without double counting', () {
    final BodyCompositionMass? result =
        TargetModelMath.deriveBodyCompositionMass(
      weightKg: 70,
      bodyFatPercent: 20,
    );

    expect(result, isNotNull);
    expect(result!.fatMassKg, closeTo(14, 0.0001));
    expect(result.fatFreeMassKg, closeTo(56, 0.0001));
    expect(result.fatMassKg + result.fatFreeMassKg, closeTo(70, 0.0001));
  });

  test('implausible composition values are rejected', () {
    expect(
      TargetModelMath.deriveBodyCompositionMass(
        weightKg: 70,
        bodyFatPercent: 120,
      ),
      isNull,
    );
    expect(
      TargetModelMath.deriveBodyCompositionMass(
        weightKg: -1,
        bodyFatPercent: 20,
      ),
      isNull,
    );
  });

  test('daily median resists multiple measurements', () {
    expect(TargetModelMath.median(<double>[64, 65, 90]), 65);
    expect(TargetModelMath.median(<double>[64, 66]), 65);
  });

  test('Theil Sen slope resists a central outlier', () {
    final double? slope = TargetModelMath.theilSenSlope(
      const <TrendPoint>[
        TrendPoint(dayIndex: 0, value: 70),
        TrendPoint(dayIndex: 1, value: 69.9),
        TrendPoint(dayIndex: 2, value: 80),
        TrendPoint(dayIndex: 3, value: 69.7),
        TrendPoint(dayIndex: 4, value: 69.6),
      ],
    );

    expect(slope, closeTo(-0.1, 0.0001));
  });

  List<DailyBodyCompositionPoint> validCompositionPoints({
    double waterOffset = 0,
    String secondDevice = '',
  }) {
    const List<int> offsets = <int>[0, 2, 4, 6, 9, 12, 14];
    return offsets.map((int day) {
      final double weight = 70 - day * 0.02;
      final double fatMass = 14 - day * 0.01;
      return DailyBodyCompositionPoint(
        dateKey: DateTime(2026, 7, 1 + day).toIso8601String().split('T').first,
        weightKg: weight,
        fatMassKg: fatMass,
        fatFreeMassKg: weight - fatMass,
        deviceCode:
            secondDevice.isNotEmpty && day >= 9 ? secondDevice : 'scale-a',
        waterPercent: 55 + (day.isEven ? waterOffset : 0),
      );
    }).toList(growable: false);
  }

  test('valid composition is integrated with conservative blending', () {
    final BodyCompositionAssessment result =
        TargetModelMath.assessBodyComposition(validCompositionPoints());

    expect(result.candidateAvailable, isTrue);
    expect(result.selectedLevelCode, 'composition_blended');
    expect(result.fallbackReasonCode, 'none');
    expect(result.validDays, 7);
    expect(result.coverageDays, 14);
    expect(result.maximumGapDays, 3);
    expect(result.compositionConfidence, closeTo(0.725, 0.0001));
    expect(result.compositionEnergyChangeKcalPerDay, closeTo(-105.2, 0.001));
    expect(result.weightOnlyEnergyChangeKcalPerDay, closeTo(-154, 0.001));
    expect(result.effectiveEnergyChangeKcalPerDay, closeTo(-118.62, 0.01));
  });

  test('large water variation keeps the weight-only fallback', () {
    final List<DailyBodyCompositionPoint> points =
        validCompositionPoints(waterOffset: 7);
    final BodyCompositionAssessment result =
        TargetModelMath.assessBodyComposition(points);

    expect(result.candidateAvailable, isTrue);
    expect(result.selectedLevelCode, 'weight_only');
    expect(result.fallbackReasonCode, 'water_variation_too_large');
  });

  test('device change rejects composition and records the reason', () {
    final BodyCompositionAssessment result =
        TargetModelMath.assessBodyComposition(
      validCompositionPoints(secondDevice: 'scale-b'),
    );

    expect(result.candidateAvailable, isTrue);
    expect(result.selectedLevelCode, 'weight_only');
    expect(result.fallbackReasonCode, 'device_changed');
    expect(result.compositionConfidence, 0);
    expect(result.compositionEnergyChangeKcalPerDay, isNotNull);
    expect(result.weightOnlyEnergyChangeKcalPerDay, isNotNull);
  });

  test('insufficient composition falls back with an explicit reason', () {
    final BodyCompositionAssessment result =
        TargetModelMath.assessBodyComposition(
      const <DailyBodyCompositionPoint>[
        DailyBodyCompositionPoint(
          dateKey: '2026-07-01',
          weightKg: 70,
          fatMassKg: 14,
          fatFreeMassKg: 56,
          deviceCode: 'scale-a',
        ),
      ],
    );

    expect(result.candidateAvailable, isFalse);
    expect(result.selectedLevelCode, 'weight_only');
    expect(result.fallbackReasonCode, 'insufficient_composition_days');
  });

  test('guardrail reports original value and reason', () {
    final GuardrailResult result = TargetModelMath.applyGuardrail(
      value: 5000,
      minimum: 1300,
      maximum: 4600,
    );

    expect(result.value, 4600);
    expect(result.unclampedValue, 5000);
    expect(result.applied, isTrue);
    expect(result.reasonCode, 'maximum');
  });

  test('short composition coverage still exposes a diagnostic candidate', () {
    final List<DailyBodyCompositionPoint> points =
        validCompositionPoints().take(5).toList(growable: false);

    final BodyCompositionAssessment result =
        TargetModelMath.assessBodyComposition(points);

    expect(result.selectedLevelCode, 'weight_only');
    expect(result.fallbackReasonCode, 'insufficient_composition_days');
    expect(result.candidateAvailable, isTrue);
    expect(result.compositionEnergyChangeKcalPerDay, isNotNull);
    expect(result.weightOnlyEnergyChangeKcalPerDay, isNotNull);
  });
}
