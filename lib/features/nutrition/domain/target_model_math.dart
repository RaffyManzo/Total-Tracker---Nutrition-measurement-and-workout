import 'dart:math' as math;

import 'composition_reliability.dart';

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
    required this.coverageDays,
    required this.maximumGapDays,
    required this.fatMassSlopeKgPerDay,
    required this.fatFreeMassSlopeKgPerDay,
    required this.weightSlopeKgPerDay,
    required this.compositionEnergyChangeKcalPerDay,
    required this.weightOnlyEnergyChangeKcalPerDay,
    required this.effectiveEnergyChangeKcalPerDay,
    required this.qualityNotes,
  });

  final bool candidateAvailable;
  final String selectedLevelCode;
  final double compositionConfidence;
  final String fallbackReasonCode;
  final int validDays;
  final int coverageDays;
  final int maximumGapDays;
  final double? fatMassSlopeKgPerDay;
  final double? fatFreeMassSlopeKgPerDay;
  final double? weightSlopeKgPerDay;
  final double? compositionEnergyChangeKcalPerDay;
  final double? weightOnlyEnergyChangeKcalPerDay;
  final double? effectiveEnergyChangeKcalPerDay;
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
    int minimumDistinctDays =
        TargetModelConstants.compositionMinimumDistinctDays,
    int minimumCoverageDays =
        TargetModelConstants.compositionMinimumCoverageDays,
    int maximumGapDays = TargetModelConstants.compositionMaximumGapDays,
    double minimumConfidence =
        TargetModelConstants.compositionMinimumConfidence,
  }) {
    final List<String> notes = <String>[];
    final Map<String, DailyBodyCompositionPoint> distinct =
        <String, DailyBodyCompositionPoint>{};
    for (final DailyBodyCompositionPoint point in rawPoints) {
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
        continue;
      }
      distinct[point.dateKey] = point;
    }
    final List<DailyBodyCompositionPoint> points = distinct.values.toList()
      ..sort(
        (DailyBodyCompositionPoint a, DailyBodyCompositionPoint b) =>
            a.dateKey.compareTo(b.dateKey),
      );

    BodyCompositionAssessment fallback({
      required String reason,
      bool candidateAvailable = false,
      int coverage = 0,
      int maxGap = 0,
      double confidence = 0,
      double? fatSlope,
      double? fatFreeSlope,
      double? weightSlope,
      double? compositionEnergy,
      double? weightEnergy,
    }) {
      return BodyCompositionAssessment(
        candidateAvailable: candidateAvailable,
        selectedLevelCode: 'weight_only',
        compositionConfidence: confidence,
        fallbackReasonCode: reason,
        validDays: points.length,
        coverageDays: coverage,
        maximumGapDays: maxGap,
        fatMassSlopeKgPerDay: fatSlope,
        fatFreeMassSlopeKgPerDay: fatFreeSlope,
        weightSlopeKgPerDay: weightSlope,
        compositionEnergyChangeKcalPerDay: compositionEnergy,
        weightOnlyEnergyChangeKcalPerDay: weightEnergy,
        effectiveEnergyChangeKcalPerDay: weightEnergy,
        qualityNotes: List<String>.unmodifiable(notes),
      );
    }

    if (points.length < 2) {
      notes.add('at_least_two_composition_days_required_for_trend');
      return fallback(reason: 'insufficient_composition_days');
    }

    final List<DateTime> dates = points
        .map((DailyBodyCompositionPoint point) => DateTime.parse(point.dateKey))
        .toList(growable: false);
    final int coverage = dates.last.difference(dates.first).inDays;
    int maxGap = 0;
    for (int index = 1; index < dates.length; index += 1) {
      maxGap = math.max(
        maxGap,
        dates[index].difference(dates[index - 1]).inDays,
      );
    }

    final DateTime origin = dates.first;
    Iterable<TrendPoint> trend(double Function(DailyBodyCompositionPoint) get) {
      return points.map(
        (DailyBodyCompositionPoint point) => TrendPoint(
          dayIndex: DateTime.parse(point.dateKey)
              .difference(origin)
              .inDays
              .toDouble(),
          value: get(point),
        ),
      );
    }

    final double? fatSlope = theilSenSlope(trend((p) => p.fatMassKg));
    final double? fatFreeSlope = theilSenSlope(trend((p) => p.fatFreeMassKg));
    final double? weightSlope = theilSenSlope(trend((p) => p.weightKg));
    if (fatSlope == null || fatFreeSlope == null || weightSlope == null) {
      notes.add('composition_trend_unavailable');
      return fallback(
        reason: 'composition_trend_unavailable',
        candidateAvailable: true,
        coverage: coverage,
        maxGap: maxGap,
        fatSlope: fatSlope,
        fatFreeSlope: fatFreeSlope,
        weightSlope: weightSlope,
      );
    }

    final double compositionEnergy = fatSlope *
            TargetModelConstants.fatMassEnergyDensityKcalPerKg +
        fatFreeSlope * TargetModelConstants.fatFreeMassEnergyDensityKcalPerKg;
    final double weightEnergy =
        weightSlope * TargetModelConstants.energyDensityPriorKcalPerKg;

    if (points.length < minimumDistinctDays) {
      notes.add('distinct_days_below_threshold');
      return fallback(
        reason: 'insufficient_composition_days',
        candidateAvailable: true,
        coverage: coverage,
        maxGap: maxGap,
        fatSlope: fatSlope,
        fatFreeSlope: fatFreeSlope,
        weightSlope: weightSlope,
        compositionEnergy: compositionEnergy,
        weightEnergy: weightEnergy,
      );
    }

    final Set<String> normalizedDeviceCodes = points
        .map((DailyBodyCompositionPoint point) =>
            CompositionReliabilityCalculator.canonicalDeviceCode(
              point.deviceCode,
            ))
        .where((String value) => value.isNotEmpty)
        .toSet();
    final Set<String> knownDeviceCodes = normalizedDeviceCodes
        .where((String value) => value != 'unspecified' && value != 'mixed')
        .toSet();
    if (normalizedDeviceCodes.contains('mixed') ||
        knownDeviceCodes.length > 1) {
      notes.add('device_changed');
      return fallback(
        reason: 'device_changed',
        candidateAvailable: true,
        coverage: coverage,
        maxGap: maxGap,
        fatSlope: fatSlope,
        fatFreeSlope: fatFreeSlope,
        weightSlope: weightSlope,
        compositionEnergy: compositionEnergy,
        weightEnergy: weightEnergy,
      );
    }

    if (coverage < minimumCoverageDays) {
      notes.add('coverage_too_short');
      return fallback(
        reason: 'insufficient_temporal_coverage',
        candidateAvailable: true,
        coverage: coverage,
        maxGap: maxGap,
        fatSlope: fatSlope,
        fatFreeSlope: fatFreeSlope,
        weightSlope: weightSlope,
        compositionEnergy: compositionEnergy,
        weightEnergy: weightEnergy,
      );
    }
    if (maxGap > maximumGapDays) {
      notes.add('measurement_gap_too_large');
      return fallback(
        reason: 'composition_gap_too_large',
        candidateAvailable: true,
        coverage: coverage,
        maxGap: maxGap,
        fatSlope: fatSlope,
        fatFreeSlope: fatFreeSlope,
        weightSlope: weightSlope,
        compositionEnergy: compositionEnergy,
        weightEnergy: weightEnergy,
      );
    }

    if (weightSlope.abs() >
            TargetModelConstants.compositionMaximumWeightSlopeKgPerDay ||
        fatSlope.abs() >
            TargetModelConstants.compositionMaximumFatSlopeKgPerDay ||
        fatFreeSlope.abs() >
            TargetModelConstants.compositionMaximumFatFreeSlopeKgPerDay) {
      notes.add('physiologically_implausible_slope');
      return fallback(
        reason: 'implausible_composition_trend',
        candidateAvailable: true,
        coverage: coverage,
        maxGap: maxGap,
        fatSlope: fatSlope,
        fatFreeSlope: fatFreeSlope,
        weightSlope: weightSlope,
        compositionEnergy: compositionEnergy,
        weightEnergy: weightEnergy,
      );
    }

    final CompositionReliabilityBreakdown reliability =
        CompositionReliabilityCalculator.calculate(
      validDays: points.length,
      coverageDays: coverage,
      maximumGapDays: maxGap,
      maximumWaterRangePercent:
          TargetModelConstants.compositionMaximumWaterRangePercent,
      waterPercentages:
          points.map((DailyBodyCompositionPoint point) => point.waterPercent),
      deviceCodes:
          points.map((DailyBodyCompositionPoint point) => point.deviceCode),
      minimumRequired: minimumConfidence,
    );
    notes.addAll(reliability.toDiagnosticNotes());
    final double confidence = reliability.score;
    if (reliability.hardFailureReasonCode != 'none') {
      notes.add(reliability.hardFailureReasonCode);
      return fallback(
        reason: reliability.hardFailureReasonCode,
        candidateAvailable: true,
        coverage: coverage,
        maxGap: maxGap,
        confidence: confidence,
        fatSlope: fatSlope,
        fatFreeSlope: fatFreeSlope,
        weightSlope: weightSlope,
        compositionEnergy: compositionEnergy,
        weightEnergy: weightEnergy,
      );
    }
    notes.add('water_used_only_as_quality_indicator');
    notes.add('visceral_subcutaneous_muscle_bone_not_summed');
    notes.add('conservative_household_bia_quality_rule');

    if (confidence < minimumConfidence) {
      notes.add('composition_confidence_below_threshold');
      return fallback(
        reason: 'composition_confidence_too_low',
        candidateAvailable: true,
        coverage: coverage,
        maxGap: maxGap,
        confidence: confidence,
        fatSlope: fatSlope,
        fatFreeSlope: fatFreeSlope,
        weightSlope: weightSlope,
        compositionEnergy: compositionEnergy,
        weightEnergy: weightEnergy,
      );
    }

    final double effectiveEnergy =
        compositionEnergy * confidence + weightEnergy * (1 - confidence);
    return BodyCompositionAssessment(
      candidateAvailable: true,
      selectedLevelCode: 'composition_blended',
      compositionConfidence: confidence,
      fallbackReasonCode: 'none',
      validDays: points.length,
      coverageDays: coverage,
      maximumGapDays: maxGap,
      fatMassSlopeKgPerDay: fatSlope,
      fatFreeMassSlopeKgPerDay: fatFreeSlope,
      weightSlopeKgPerDay: weightSlope,
      compositionEnergyChangeKcalPerDay: compositionEnergy,
      weightOnlyEnergyChangeKcalPerDay: weightEnergy,
      effectiveEnergyChangeKcalPerDay: effectiveEnergy,
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
