import 'dart:math' as math;

import 'target_model_constants.dart';

class StepEnergyEstimate {
  const StepEnergyEstimate({
    required this.steps,
    required this.weightKg,
    required this.stepLengthMeters,
    required this.distanceKm,
    required this.effectiveKcalPerStep,
    required this.activeKcal,
    required this.stepLengthSourceCode,
    required this.coefficientSourceCode,
    required this.usedLegacyFallback,
  });

  final int steps;
  final double weightKg;
  final double? stepLengthMeters;
  final double? distanceKm;
  final double effectiveKcalPerStep;
  final double activeKcal;
  final String stepLengthSourceCode;
  final String coefficientSourceCode;
  final bool usedLegacyFallback;
}

class TrendPoint {
  const TrendPoint({required this.dayIndex, required this.value});

  final double dayIndex;
  final double value;
}

class DailyBodyCompositionPoint {
  const DailyBodyCompositionPoint({
    required this.dateKey,
    required this.weightKg,
    required this.fatMassKg,
    required this.fatFreeMassKg,
    required this.deviceCode,
    this.waterPercent,
  });

  final String dateKey;
  final double weightKg;
  final double fatMassKg;
  final double fatFreeMassKg;
  final String deviceCode;
  final double? waterPercent;
}

class BodyCompositionMass {
  const BodyCompositionMass({
    required this.fatMassKg,
    required this.fatFreeMassKg,
  });

  final double fatMassKg;
  final double fatFreeMassKg;
}

class BodyCompositionAssessment {
  const BodyCompositionAssessment({
    required this.candidateAvailable,
    required this.selectedLevelCode,
    required this.compositionConfidence,
    required this.fallbackReasonCode,
    required this.validDays,
    required this.fatMassSlopeKgPerDay,
    required this.fatFreeMassSlopeKgPerDay,
    required this.compositionEnergyChangeKcalPerDay,
    required this.qualityNotes,
  });

  final bool candidateAvailable;
  final String selectedLevelCode;
  final double compositionConfidence;
  final String fallbackReasonCode;
  final int validDays;
  final double? fatMassSlopeKgPerDay;
  final double? fatFreeMassSlopeKgPerDay;
  final double? compositionEnergyChangeKcalPerDay;
  final List<String> qualityNotes;
}

class GuardrailResult {
  const GuardrailResult({
    required this.value,
    required this.unclampedValue,
    required this.applied,
    required this.reasonCode,
  });

  final double value;
  final double unclampedValue;
  final bool applied;
  final String reasonCode;
}

class TargetModelMath {
  const TargetModelMath._();

  static StepEnergyEstimate estimateSteps({
    required int steps,
    required double weightKg,
    double? heightCm,
    double? manualStepLengthMeters,
    double? calibratedStepLengthMeters,
    double legacyKcalPerStep = TargetModelConstants.legacyStepKcalCoefficient,
  }) {
    final int safeSteps = math.max(0, steps);
    final double safeWeight = weightKg > 0 && weightKg.isFinite ? weightKg : 70;
    final double? calibrated = _positive(calibratedStepLengthMeters);
    final double? manual = _positive(manualStepLengthMeters);
    final double? estimated =
        heightCm != null && heightCm.isFinite && heightCm > 0
            ? heightCm * TargetModelConstants.stepLengthHeightFactor
            : null;
    final double? stepLength = calibrated ?? manual ?? estimated;
    final String stepLengthSource = calibrated != null
        ? 'personal_calibration'
        : manual != null
            ? 'manual'
            : estimated != null
                ? 'height_fallback'
                : 'legacy_unavailable_height';

    if (stepLength == null) {
      final double coefficient = math.max(0.0, legacyKcalPerStep);
      return StepEnergyEstimate(
        steps: safeSteps,
        weightKg: safeWeight,
        stepLengthMeters: null,
        distanceKm: null,
        effectiveKcalPerStep: coefficient,
        activeKcal: safeSteps * coefficient,
        stepLengthSourceCode: stepLengthSource,
        coefficientSourceCode: 'legacy_fixed_0_020',
        usedLegacyFallback: true,
      );
    }

    final double coefficient = safeWeight *
        stepLength *
        TargetModelConstants.netWalkingCostKcalPerKgKm /
        1000;
    final double distanceKm = safeSteps * stepLength / 1000;
    return StepEnergyEstimate(
      steps: safeSteps,
      weightKg: safeWeight,
      stepLengthMeters: stepLength,
      distanceKm: distanceKm,
      effectiveKcalPerStep: coefficient,
      activeKcal: safeSteps * coefficient,
      stepLengthSourceCode: stepLengthSource,
      coefficientSourceCode: 'weight_height_walking_cost',
      usedLegacyFallback: false,
    );
  }

  static double observedTdeeFromWeightSlope({
    required double meanValidEnergyIntake,
    required double weightSlopeKgPerDay,
    double energyDensityPriorKcalPerKg =
        TargetModelConstants.energyDensityPriorKcalPerKg,
  }) {
    return meanValidEnergyIntake -
        weightSlopeKgPerDay * energyDensityPriorKcalPerKg;
  }

  static BodyCompositionMass? deriveBodyCompositionMass({
    required double weightKg,
    required double bodyFatPercent,
  }) {
    if (!weightKg.isFinite ||
        weightKg <= 0 ||
        !bodyFatPercent.isFinite ||
        bodyFatPercent < 0 ||
        bodyFatPercent > 100) {
      return null;
    }
    final double fatMassKg = weightKg * bodyFatPercent / 100;
    return BodyCompositionMass(
      fatMassKg: fatMassKg,
      fatFreeMassKg: weightKg - fatMassKg,
    );
  }

  static double median(Iterable<double> values) {
    final List<double> sorted = values
        .where((double value) => value.isFinite)
        .toList(growable: false)
      ..sort();
    if (sorted.isEmpty) {
      throw ArgumentError('Median requires at least one finite value.');
    }
    final int middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[middle];
    }
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  static double? theilSenSlope(Iterable<TrendPoint> points) {
    final List<TrendPoint> sorted = points
        .where(
          (TrendPoint point) => point.dayIndex.isFinite && point.value.isFinite,
        )
        .toList(growable: false)
      ..sort(
        (TrendPoint a, TrendPoint b) => a.dayIndex.compareTo(b.dayIndex),
      );
    if (sorted.length < 2) {
      return null;
    }
    final List<double> slopes = <double>[];
    for (int i = 0; i < sorted.length - 1; i += 1) {
      for (int j = i + 1; j < sorted.length; j += 1) {
        final double dx = sorted[j].dayIndex - sorted[i].dayIndex;
        if (dx == 0) {
          continue;
        }
        slopes.add((sorted[j].value - sorted[i].value) / dx);
      }
    }
    return slopes.isEmpty ? null : median(slopes);
  }

  static BodyCompositionAssessment assessBodyComposition(
    Iterable<DailyBodyCompositionPoint> rawPoints, {
    int minimumDistinctDays = 4,
  }) {
    final List<String> notes = <String>[];
    final List<DailyBodyCompositionPoint> points =
        rawPoints.where((DailyBodyCompositionPoint point) {
      final bool valid = point.weightKg.isFinite &&
          point.weightKg > 0 &&
          point.fatMassKg.isFinite &&
          point.fatMassKg >= 0 &&
          point.fatFreeMassKg.isFinite &&
          point.fatFreeMassKg >= 0 &&
          (point.fatMassKg + point.fatFreeMassKg - point.weightKg).abs() <
              0.01 &&
          (point.waterPercent == null ||
              (point.waterPercent!.isFinite &&
                  point.waterPercent! >= 0 &&
                  point.waterPercent! <= 100));
      if (!valid) {
        notes.add('measurement_not_mathematically_consistent');
      }
      return valid;
    }).toList(growable: false)
          ..sort(
            (DailyBodyCompositionPoint a, DailyBodyCompositionPoint b) =>
                a.dateKey.compareTo(b.dateKey),
          );

    if (points.length < minimumDistinctDays) {
      return BodyCompositionAssessment(
        candidateAvailable: false,
        selectedLevelCode: 'weight_only',
        compositionConfidence: 0,
        fallbackReasonCode: 'insufficient_composition_days',
        validDays: points.length,
        fatMassSlopeKgPerDay: null,
        fatFreeMassSlopeKgPerDay: null,
        compositionEnergyChangeKcalPerDay: null,
        qualityNotes: List<String>.unmodifiable(notes),
      );
    }

    final Set<String> devices = points
        .map((DailyBodyCompositionPoint point) => point.deviceCode.trim())
        .where((String value) => value.isNotEmpty)
        .toSet();
    if (devices.contains('mixed') || devices.length > 1) {
      notes.add('device_changed');
      return BodyCompositionAssessment(
        candidateAvailable: false,
        selectedLevelCode: 'weight_only',
        compositionConfidence: 0,
        fallbackReasonCode: 'device_changed',
        validDays: points.length,
        fatMassSlopeKgPerDay: null,
        fatFreeMassSlopeKgPerDay: null,
        compositionEnergyChangeKcalPerDay: null,
        qualityNotes: List<String>.unmodifiable(notes),
      );
    }

    final DateTime origin = DateTime.parse(points.first.dateKey);
    final double? fatSlope = theilSenSlope(
      points.map(
        (DailyBodyCompositionPoint point) => TrendPoint(
          dayIndex: DateTime.parse(point.dateKey)
              .difference(origin)
              .inDays
              .toDouble(),
          value: point.fatMassKg,
        ),
      ),
    );
    final double? fatFreeSlope = theilSenSlope(
      points.map(
        (DailyBodyCompositionPoint point) => TrendPoint(
          dayIndex: DateTime.parse(point.dateKey)
              .difference(origin)
              .inDays
              .toDouble(),
          value: point.fatFreeMassKg,
        ),
      ),
    );
    if (fatSlope == null || fatFreeSlope == null) {
      return BodyCompositionAssessment(
        candidateAvailable: false,
        selectedLevelCode: 'weight_only',
        compositionConfidence: 0,
        fallbackReasonCode: 'composition_trend_unavailable',
        validDays: points.length,
        fatMassSlopeKgPerDay: fatSlope,
        fatFreeMassSlopeKgPerDay: fatFreeSlope,
        compositionEnergyChangeKcalPerDay: null,
        qualityNotes: List<String>.unmodifiable(notes),
      );
    }

    final double energyChange = fatSlope *
            TargetModelConstants.fatMassEnergyDensityKcalPerKg +
        fatFreeSlope * TargetModelConstants.fatFreeMassEnergyDensityKcalPerKg;
    notes.add('water_used_only_as_quality_indicator');
    notes.add('visceral_subcutaneous_muscle_bone_not_summed');
    notes.add('composition_thresholds_stalled');

    // The numerical threshold and blending weights are explicitly IN STALLO.
    // The candidate is calculated and audited, but production remains on the
    // weight-only level until an approved threshold exists.
    return BodyCompositionAssessment(
      candidateAvailable: true,
      selectedLevelCode: 'weight_only',
      compositionConfidence: 0,
      fallbackReasonCode: 'threshold_not_approved',
      validDays: points.length,
      fatMassSlopeKgPerDay: fatSlope,
      fatFreeMassSlopeKgPerDay: fatFreeSlope,
      compositionEnergyChangeKcalPerDay: energyChange,
      qualityNotes: List<String>.unmodifiable(notes),
    );
  }

  static GuardrailResult applyGuardrail({
    required double value,
    required double minimum,
    required double maximum,
  }) {
    if (value < minimum) {
      return GuardrailResult(
        value: minimum,
        unclampedValue: value,
        applied: true,
        reasonCode: 'minimum',
      );
    }
    if (value > maximum) {
      return GuardrailResult(
        value: maximum,
        unclampedValue: value,
        applied: true,
        reasonCode: 'maximum',
      );
    }
    return GuardrailResult(
      value: value,
      unclampedValue: value,
      applied: false,
      reasonCode: 'none',
    );
  }

  static double? _positive(double? value) {
    if (value == null || !value.isFinite || value <= 0) {
      return null;
    }
    return value;
  }
}
