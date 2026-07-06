import 'dart:math' as math;

import '../../profile/domain/profile_codes.dart';

class TargetAlertSeverityCodes {
  const TargetAlertSeverityCodes._();

  static const String info = 'info';
  static const String warning = 'warning';
  static const String critical = 'critical';
}

class TargetAlert {
  const TargetAlert({
    required this.code,
    required this.title,
    required this.message,
    required this.severityCode,
  });

  final String code;
  final String title;
  final String message;
  final String severityCode;
}

class ResolvedActivityBreakdown {
  const ResolvedActivityBreakdown({
    required this.actualStepKcal,
    required this.effectiveStepKcal,
    required this.actualWorkoutKcal,
    required this.effectiveWorkoutKcal,
    required this.totalKcal,
    required this.statusCode,
    required this.usedStepGoalFallback,
    required this.usedProfileWorkoutFallback,
    this.stepLengthMeters,
    this.effectiveStepKcalCoefficient = 0,
    this.stepLengthSourceCode = 'unavailable',
    this.stepCoefficientSourceCode = 'unavailable',
    this.stepWeightSourceCode = 'unavailable',
  });

  final double actualStepKcal;
  final double effectiveStepKcal;
  final double actualWorkoutKcal;
  final double effectiveWorkoutKcal;
  final double totalKcal;
  final String statusCode;
  final bool usedStepGoalFallback;
  final bool usedProfileWorkoutFallback;
  final double? stepLengthMeters;
  final double effectiveStepKcalCoefficient;
  final String stepLengthSourceCode;
  final String stepCoefficientSourceCode;
  final String stepWeightSourceCode;

  bool get isPartiallyProvisional =>
      usedStepGoalFallback != usedProfileWorkoutFallback;

  bool get isFullyProvisional =>
      usedStepGoalFallback && usedProfileWorkoutFallback;
}

class WeightFreshnessResult {
  const WeightFreshnessResult({
    required this.effectiveWeightKg,
    required this.sourceCode,
    required this.statusCode,
    required this.daysSinceMeasurement,
    required this.allowObservedWeightTrend,
    required this.alerts,
  });

  final double? effectiveWeightKg;
  final String sourceCode;
  final String statusCode;
  final int? daysSinceMeasurement;
  final bool allowObservedWeightTrend;
  final List<TargetAlert> alerts;
}

class AdaptiveTargetEngine {
  const AdaptiveTargetEngine();

  static const int weightWarningAfterDays = 15;
  static const int weightStopAfterDays = 20;

  ResolvedActivityBreakdown resolveActivity({
    required int steps,
    required int stepGoal,
    required double stepKcalCoefficient,
    required double completedWorkoutKcal,
    required double profileWorkoutDailyKcal,
    required String fallbackModeCode,
    required DateTime dayDate,
    required DateTime now,
    double? actualStepKcalOverride,
    double? targetStepKcalOverride,
    bool? hasRecordedSteps,
    bool? hasRecordedWorkout,
    double? stepLengthMeters,
    String stepLengthSourceCode = 'unavailable',
    String stepCoefficientSourceCode = 'legacy_fixed',
    String stepWeightSourceCode = 'unavailable',
  }) {
    final double coefficient = math.max(0.0, stepKcalCoefficient);
    final double actualStepKcal = math.max(
      0.0,
      actualStepKcalOverride ?? math.max(0, steps) * coefficient,
    );
    final double targetStepKcal = math.max(
      0.0,
      targetStepKcalOverride ?? math.max(0, stepGoal) * coefficient,
    );
    final double actualWorkoutKcal = math.max(0.0, completedWorkoutKcal);
    final double estimatedWorkoutKcal = math.max(0.0, profileWorkoutDailyKcal);
    final bool recordedSteps = hasRecordedSteps ?? steps > 0;
    final bool recordedWorkout = hasRecordedWorkout ?? actualWorkoutKcal > 0;

    bool useStepFallback = false;
    bool useWorkoutFallback = false;
    double effectiveStepKcal = actualStepKcal;
    double effectiveWorkoutKcal = actualWorkoutKcal;

    // The legacy profileEstimate code is intentionally treated as an alias
    // of the component-wise policy. A recorded component always wins; only
    // the missing component receives its profile fallback.
    final bool allowsFallback =
        fallbackModeCode != ActivityFallbackModeCodes.recordedOnly;
    if (allowsFallback &&
        !recordedSteps &&
        stepGoal > 0 &&
        targetStepKcal > 0) {
      effectiveStepKcal = targetStepKcal;
      useStepFallback = true;
    }
    if (allowsFallback && !recordedWorkout && estimatedWorkoutKcal > 0) {
      effectiveWorkoutKcal = estimatedWorkoutKcal;
      useWorkoutFallback = true;
    }

    final double total = effectiveStepKcal + effectiveWorkoutKcal;
    final bool hasActualSteps = recordedSteps;
    final bool hasActualWorkout = recordedWorkout;
    final bool hasActual = hasActualSteps || hasActualWorkout;
    final String statusCode;
    if (useStepFallback && useWorkoutFallback) {
      statusCode = 'provisional';
    } else if (useStepFallback || useWorkoutFallback) {
      statusCode = 'partially_provisional';
    } else if (hasActual) {
      statusCode = 'actual';
    } else {
      statusCode = 'unavailable';
    }

    return ResolvedActivityBreakdown(
      actualStepKcal: actualStepKcal,
      effectiveStepKcal: effectiveStepKcal,
      actualWorkoutKcal: actualWorkoutKcal,
      effectiveWorkoutKcal: effectiveWorkoutKcal,
      totalKcal: math.max(0.0, total),
      statusCode: statusCode,
      usedStepGoalFallback: useStepFallback,
      usedProfileWorkoutFallback: useWorkoutFallback,
      stepLengthMeters: stepLengthMeters,
      effectiveStepKcalCoefficient: coefficient,
      stepLengthSourceCode: stepLengthSourceCode,
      stepCoefficientSourceCode: stepCoefficientSourceCode,
      stepWeightSourceCode: stepWeightSourceCode,
    );
  }

  WeightFreshnessResult evaluateWeight({
    required double? latestMeasurementWeightKg,
    required DateTime? latestMeasurementDate,
    required String latestReliabilityCode,
    required double? initialProfileWeightKg,
    required DateTime referenceDate,
  }) {
    final double? validInitial = _positive(initialProfileWeightKg);
    final double? validLatest = _positive(latestMeasurementWeightKg);

    if (validLatest == null || latestMeasurementDate == null) {
      return WeightFreshnessResult(
        effectiveWeightKg: validInitial,
        sourceCode: validInitial == null ? 'unavailable' : 'initial_profile',
        statusCode: validInitial == null ? 'missing' : 'profile_fallback',
        daysSinceMeasurement: null,
        allowObservedWeightTrend: false,
        alerts: <TargetAlert>[
          TargetAlert(
            code: 'weight_missing',
            title: 'Peso non disponibile',
            message: validInitial == null
                ? 'Inserisci una misurazione di bilancia o il peso iniziale nel profilo. Il target resta provvisorio.'
                : 'Non ci sono misurazioni di bilancia. Il peso iniziale viene usato solo per la stima teorica.',
            severityCode: validInitial == null
                ? TargetAlertSeverityCodes.critical
                : TargetAlertSeverityCodes.warning,
          ),
        ],
      );
    }

    final int days = math.max(
      0,
      _dateOnly(referenceDate)
          .difference(_dateOnly(latestMeasurementDate))
          .inDays,
    );
    final bool lowReliability =
        latestReliabilityCode.trim().toLowerCase() == 'low';
    final List<TargetAlert> alerts = <TargetAlert>[];

    if (days >= weightStopAfterDays) {
      alerts.add(
        TargetAlert(
          code: 'weight_stale_stopped',
          title: 'Peso non aggiornato da $days giorni',
          message: 'La variazione del peso è esclusa dal target adattivo. '
              'Aggiorna la bilancia; nel frattempo viene usato il peso iniziale '
              'solo per la stima teorica.',
          severityCode: TargetAlertSeverityCodes.critical,
        ),
      );
      return WeightFreshnessResult(
        effectiveWeightKg: validInitial,
        sourceCode: validInitial == null ? 'unavailable' : 'initial_profile',
        statusCode: 'stale',
        daysSinceMeasurement: days,
        allowObservedWeightTrend: false,
        alerts: alerts,
      );
    }

    if (days >= weightWarningAfterDays) {
      alerts.add(
        TargetAlert(
          code: 'weight_aging',
          title: 'Peso non aggiornato da $days giorni',
          message: 'La misurazione è ancora utilizzata, ma deve essere '
              'aggiornata prima dei $weightStopAfterDays giorni per mantenere '
              'attiva la componente osservata del target.',
          severityCode: TargetAlertSeverityCodes.warning,
        ),
      );
    }

    if (lowReliability) {
      alerts.add(
        const TargetAlert(
          code: 'weight_low_reliability',
          title: 'Peso con affidabilità bassa',
          message: 'La misurazione contribuisce con peso ridotto alla stima '
              'osservata. Ripeti la misurazione in condizioni più stabili.',
          severityCode: TargetAlertSeverityCodes.info,
        ),
      );
    }

    return WeightFreshnessResult(
      effectiveWeightKg: validLatest,
      sourceCode: 'scale',
      statusCode: days >= weightWarningAfterDays ? 'aging' : 'fresh',
      daysSinceMeasurement: days,
      allowObservedWeightTrend: true,
      alerts: alerts,
    );
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  double? _positive(double? value) {
    if (value == null || !value.isFinite || value <= 0) {
      return null;
    }
    return value;
  }
}
