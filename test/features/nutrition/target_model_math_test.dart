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

  test('composition candidate is calculated but activation remains stalled',
      () {
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
        DailyBodyCompositionPoint(
          dateKey: '2026-07-02',
          weightKg: 69.9,
          fatMassKg: 13.95,
          fatFreeMassKg: 55.95,
          deviceCode: 'scale-a',
        ),
        DailyBodyCompositionPoint(
          dateKey: '2026-07-03',
          weightKg: 69.8,
          fatMassKg: 13.90,
          fatFreeMassKg: 55.90,
          deviceCode: 'scale-a',
        ),
        DailyBodyCompositionPoint(
          dateKey: '2026-07-04',
          weightKg: 69.7,
          fatMassKg: 13.85,
          fatFreeMassKg: 55.85,
          deviceCode: 'scale-a',
        ),
      ],
    );

    expect(result.candidateAvailable, isTrue);
    expect(result.compositionEnergyChangeKcalPerDay, closeTo(-526, 0.001));
    expect(result.selectedLevelCode, 'weight_only');
    expect(result.compositionConfidence, 0);
    expect(result.fallbackReasonCode, 'threshold_not_approved');
  });

  test('composition candidate supports a positive slope', () {
    final BodyCompositionAssessment result =
        TargetModelMath.assessBodyComposition(
      const <DailyBodyCompositionPoint>[
        DailyBodyCompositionPoint(
          dateKey: '2026-07-01',
          weightKg: 70,
          fatMassKg: 14,
          fatFreeMassKg: 56,
          deviceCode: 'scale-a',
          waterPercent: 55,
        ),
        DailyBodyCompositionPoint(
          dateKey: '2026-07-02',
          weightKg: 70.1,
          fatMassKg: 14.05,
          fatFreeMassKg: 56.05,
          deviceCode: 'scale-a',
          waterPercent: 55.1,
        ),
        DailyBodyCompositionPoint(
          dateKey: '2026-07-03',
          weightKg: 70.2,
          fatMassKg: 14.10,
          fatFreeMassKg: 56.10,
          deviceCode: 'scale-a',
          waterPercent: 54.9,
        ),
        DailyBodyCompositionPoint(
          dateKey: '2026-07-04',
          weightKg: 70.3,
          fatMassKg: 14.15,
          fatFreeMassKg: 56.15,
          deviceCode: 'scale-a',
          waterPercent: 55,
        ),
      ],
    );

    expect(result.candidateAvailable, isTrue);
    expect(result.compositionEnergyChangeKcalPerDay, closeTo(526, 0.001));
    expect(
        result.qualityNotes, contains('water_used_only_as_quality_indicator'));
    expect(
      result.qualityNotes,
      contains('visceral_subcutaneous_muscle_bone_not_summed'),
    );
  });

  test('device change rejects composition and records the reason', () {
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
        DailyBodyCompositionPoint(
          dateKey: '2026-07-02',
          weightKg: 69.9,
          fatMassKg: 13.9,
          fatFreeMassKg: 56,
          deviceCode: 'scale-a',
        ),
        DailyBodyCompositionPoint(
          dateKey: '2026-07-03',
          weightKg: 69.8,
          fatMassKg: 13.8,
          fatFreeMassKg: 56,
          deviceCode: 'scale-b',
        ),
        DailyBodyCompositionPoint(
          dateKey: '2026-07-04',
          weightKg: 69.7,
          fatMassKg: 13.7,
          fatFreeMassKg: 56,
          deviceCode: 'scale-b',
        ),
      ],
    );

    expect(result.candidateAvailable, isFalse);
    expect(result.selectedLevelCode, 'weight_only');
    expect(result.fallbackReasonCode, 'device_changed');
    expect(result.compositionConfidence, 0);
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
}
