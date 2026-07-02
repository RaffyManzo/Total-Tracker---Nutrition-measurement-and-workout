import 'dart:convert';

import 'profile_codes.dart';

class ActivityPresetCodes {
  static const String weights = 'weights';
  static const String cardioContinuous = 'cardio_continuous';
  static const String cardioIntervals = 'cardio_intervals';
  static const String weightsCardio = 'weights_cardio';
  static const String mixedCircuit = 'mixed_circuit';
  static const String freeActivity = 'free_activity';

  static const Set<String> values = <String>{
    weights,
    cardioContinuous,
    cardioIntervals,
    weightsCardio,
    mixedCircuit,
    freeActivity,
  };
}

class ActivityIntensityCodes {
  static const String light = 'light';
  static const String moderate = 'moderate';
  static const String vigorous = 'vigorous';

  static const Set<String> values = <String>{light, moderate, vigorous};
}

class CardioMachineCodes {
  static const String treadmill = 'treadmill';
  static const String bike = 'bike';
  static const String elliptical = 'elliptical';
  static const String rower = 'rower';
  static const String stairClimber = 'stair_climber';
  static const String outdoorWalk = 'outdoor_walk';
  static const String outdoorRun = 'outdoor_run';
  static const String generic = 'generic';

  static const Set<String> values = <String>{
    treadmill,
    bike,
    elliptical,
    rower,
    stairClimber,
    outdoorWalk,
    outdoorRun,
    generic,
  };
}

class WeightOrganizationCodes {
  static const String traditional = 'traditional';
  static const String supersets = 'supersets';
  static const String giantSets = 'giant_sets';
  static const String circuit = 'circuit';

  static const Set<String> values = <String>{
    traditional,
    supersets,
    giantSets,
    circuit,
  };
}

class ActivityInputSourceCodes {
  static const String user = 'user';
  static const String legacy = 'legacy';
  static const String defaultValue = 'default';
  static const String profile = 'profile';
  static const String derived = 'derived';

  static const Set<String> values = <String>{
    user,
    legacy,
    defaultValue,
    profile,
    derived,
  };
}

class ActivityFieldKeys {
  static const String presetCode = 'presetCode';
  static const String sessionsPerWeek = 'sessionsPerWeek';
  static const String weightsDurationMinutes = 'weightsDurationMinutes';
  static const String weightSets = 'weightSets';
  static const String restSeconds = 'restSeconds';
  static const String setDurationSeconds = 'setDurationSeconds';
  static const String averageRir = 'averageRir';
  static const String weightsAvgHeartRate = 'weightsAvgHeartRate';
  static const String inactiveMinutes = 'inactiveMinutes';
  static const String weightsOrganizationCode = 'weightsOrganizationCode';
  static const String cardioDurationMinutes = 'cardioDurationMinutes';
  static const String cardioMachineCode = 'cardioMachineCode';
  static const String cardioIntensityCode = 'cardioIntensityCode';
  static const String cardioAvgHeartRate = 'cardioAvgHeartRate';
  static const String cardioPauseMinutes = 'cardioPauseMinutes';
  static const String cardioSpeedKmh = 'cardioSpeedKmh';
  static const String cardioInclinePercent = 'cardioInclinePercent';
  static const String cardioWatts = 'cardioWatts';
  static const String intervalCount = 'intervalCount';
  static const String activeIntervalSeconds = 'activeIntervalSeconds';
  static const String recoveryIntervalSeconds = 'recoveryIntervalSeconds';
  static const String mixedDurationMinutes = 'mixedDurationMinutes';
  static const String mixedRounds = 'mixedRounds';
  static const String mixedWeightPhaseSeconds = 'mixedWeightPhaseSeconds';
  static const String mixedCardioPhaseSeconds = 'mixedCardioPhaseSeconds';
  static const String mixedRestSeconds = 'mixedRestSeconds';
  static const String mixedWeightsAvgHeartRate = 'mixedWeightsAvgHeartRate';
  static const String mixedCardioAvgHeartRate = 'mixedCardioAvgHeartRate';
  static const String freeDurationMinutes = 'freeDurationMinutes';
  static const String freePauseMinutes = 'freePauseMinutes';
  static const String freeAvgHeartRate = 'freeAvgHeartRate';
  static const String freeIntensityCode = 'freeIntensityCode';

  static const List<String> all = <String>[
    presetCode,
    sessionsPerWeek,
    weightsDurationMinutes,
    weightSets,
    restSeconds,
    setDurationSeconds,
    averageRir,
    weightsAvgHeartRate,
    inactiveMinutes,
    weightsOrganizationCode,
    cardioDurationMinutes,
    cardioMachineCode,
    cardioIntensityCode,
    cardioAvgHeartRate,
    cardioPauseMinutes,
    cardioSpeedKmh,
    cardioInclinePercent,
    cardioWatts,
    intervalCount,
    activeIntervalSeconds,
    recoveryIntervalSeconds,
    mixedDurationMinutes,
    mixedRounds,
    mixedWeightPhaseSeconds,
    mixedCardioPhaseSeconds,
    mixedRestSeconds,
    mixedWeightsAvgHeartRate,
    mixedCardioAvgHeartRate,
    freeDurationMinutes,
    freePauseMinutes,
    freeAvgHeartRate,
    freeIntensityCode,
  ];
}

class ProfileActivityConfig {
  const ProfileActivityConfig({
    this.version = 2,
    this.presetCode = ActivityPresetCodes.weights,
    this.sessionsPerWeek = 3,
    this.weightsDurationMinutes = 60,
    this.weightSets = 16,
    this.restSeconds = 150,
    this.setDurationSeconds = 40,
    this.averageRir = 2,
    this.weightsAvgHeartRate = 0,
    this.inactiveMinutes = 0,
    this.weightsOrganizationCode = WeightOrganizationCodes.traditional,
    this.cardioDurationMinutes = 25,
    this.cardioMachineCode = CardioMachineCodes.treadmill,
    this.cardioIntensityCode = ActivityIntensityCodes.moderate,
    this.cardioAvgHeartRate = 0,
    this.cardioPauseMinutes = 0,
    this.cardioSpeedKmh = 0,
    this.cardioInclinePercent = 0,
    this.cardioWatts = 0,
    this.intervalCount = 8,
    this.activeIntervalSeconds = 60,
    this.recoveryIntervalSeconds = 90,
    this.mixedDurationMinutes = 45,
    this.mixedRounds = 8,
    this.mixedWeightPhaseSeconds = 90,
    this.mixedCardioPhaseSeconds = 90,
    this.mixedRestSeconds = 60,
    this.mixedWeightsAvgHeartRate = 0,
    this.mixedCardioAvgHeartRate = 0,
    this.freeDurationMinutes = 45,
    this.freePauseMinutes = 0,
    this.freeAvgHeartRate = 0,
    this.freeIntensityCode = ActivityIntensityCodes.moderate,
    this.fieldSources = const <String, String>{},
  });

  final int version;
  final String presetCode;
  final double sessionsPerWeek;

  final int weightsDurationMinutes;
  final int weightSets;
  final int restSeconds;
  final int setDurationSeconds;
  final int averageRir;
  final int weightsAvgHeartRate;
  final int inactiveMinutes;
  final String weightsOrganizationCode;

  final int cardioDurationMinutes;
  final String cardioMachineCode;
  final String cardioIntensityCode;
  final int cardioAvgHeartRate;
  final int cardioPauseMinutes;
  final double cardioSpeedKmh;
  final double cardioInclinePercent;
  final int cardioWatts;
  final int intervalCount;
  final int activeIntervalSeconds;
  final int recoveryIntervalSeconds;

  final int mixedDurationMinutes;
  final int mixedRounds;
  final int mixedWeightPhaseSeconds;
  final int mixedCardioPhaseSeconds;
  final int mixedRestSeconds;
  final int mixedWeightsAvgHeartRate;
  final int mixedCardioAvgHeartRate;

  final int freeDurationMinutes;
  final int freePauseMinutes;
  final int freeAvgHeartRate;
  final String freeIntensityCode;

  final Map<String, String> fieldSources;

  String sourceFor(String key) =>
      fieldSources[key] ?? ActivityInputSourceCodes.defaultValue;

  int get totalDurationMinutes {
    if (presetCode == ActivityPresetCodes.weights) {
      return weightsDurationMinutes;
    }
    if (presetCode == ActivityPresetCodes.cardioContinuous ||
        presetCode == ActivityPresetCodes.cardioIntervals) {
      return cardioDurationMinutes;
    }
    if (presetCode == ActivityPresetCodes.weightsCardio) {
      return weightsDurationMinutes + cardioDurationMinutes;
    }
    if (presetCode == ActivityPresetCodes.mixedCircuit) {
      return mixedDurationMinutes;
    }
    return freeDurationMinutes;
  }

  String get legacyWorkoutTypeCode {
    if (presetCode == ActivityPresetCodes.weights) {
      return WorkoutActivityTypeCodes.weights;
    }
    if (presetCode == ActivityPresetCodes.cardioContinuous ||
        presetCode == ActivityPresetCodes.cardioIntervals ||
        presetCode == ActivityPresetCodes.freeActivity) {
      return WorkoutActivityTypeCodes.cardio;
    }
    return WorkoutActivityTypeCodes.mixed;
  }

  ProfileActivityConfig copyWith({
    String? presetCode,
    double? sessionsPerWeek,
    int? weightsDurationMinutes,
    int? weightSets,
    int? restSeconds,
    int? setDurationSeconds,
    int? averageRir,
    int? weightsAvgHeartRate,
    int? inactiveMinutes,
    String? weightsOrganizationCode,
    int? cardioDurationMinutes,
    String? cardioMachineCode,
    String? cardioIntensityCode,
    int? cardioAvgHeartRate,
    int? cardioPauseMinutes,
    double? cardioSpeedKmh,
    double? cardioInclinePercent,
    int? cardioWatts,
    int? intervalCount,
    int? activeIntervalSeconds,
    int? recoveryIntervalSeconds,
    int? mixedDurationMinutes,
    int? mixedRounds,
    int? mixedWeightPhaseSeconds,
    int? mixedCardioPhaseSeconds,
    int? mixedRestSeconds,
    int? mixedWeightsAvgHeartRate,
    int? mixedCardioAvgHeartRate,
    int? freeDurationMinutes,
    int? freePauseMinutes,
    int? freeAvgHeartRate,
    String? freeIntensityCode,
    Map<String, String>? fieldSources,
  }) {
    return ProfileActivityConfig(
      version: version,
      presetCode: presetCode ?? this.presetCode,
      sessionsPerWeek: sessionsPerWeek ?? this.sessionsPerWeek,
      weightsDurationMinutes:
          weightsDurationMinutes ?? this.weightsDurationMinutes,
      weightSets: weightSets ?? this.weightSets,
      restSeconds: restSeconds ?? this.restSeconds,
      setDurationSeconds: setDurationSeconds ?? this.setDurationSeconds,
      averageRir: averageRir ?? this.averageRir,
      weightsAvgHeartRate: weightsAvgHeartRate ?? this.weightsAvgHeartRate,
      inactiveMinutes: inactiveMinutes ?? this.inactiveMinutes,
      weightsOrganizationCode:
          weightsOrganizationCode ?? this.weightsOrganizationCode,
      cardioDurationMinutes:
          cardioDurationMinutes ?? this.cardioDurationMinutes,
      cardioMachineCode: cardioMachineCode ?? this.cardioMachineCode,
      cardioIntensityCode: cardioIntensityCode ?? this.cardioIntensityCode,
      cardioAvgHeartRate: cardioAvgHeartRate ?? this.cardioAvgHeartRate,
      cardioPauseMinutes: cardioPauseMinutes ?? this.cardioPauseMinutes,
      cardioSpeedKmh: cardioSpeedKmh ?? this.cardioSpeedKmh,
      cardioInclinePercent: cardioInclinePercent ?? this.cardioInclinePercent,
      cardioWatts: cardioWatts ?? this.cardioWatts,
      intervalCount: intervalCount ?? this.intervalCount,
      activeIntervalSeconds:
          activeIntervalSeconds ?? this.activeIntervalSeconds,
      recoveryIntervalSeconds:
          recoveryIntervalSeconds ?? this.recoveryIntervalSeconds,
      mixedDurationMinutes: mixedDurationMinutes ?? this.mixedDurationMinutes,
      mixedRounds: mixedRounds ?? this.mixedRounds,
      mixedWeightPhaseSeconds:
          mixedWeightPhaseSeconds ?? this.mixedWeightPhaseSeconds,
      mixedCardioPhaseSeconds:
          mixedCardioPhaseSeconds ?? this.mixedCardioPhaseSeconds,
      mixedRestSeconds: mixedRestSeconds ?? this.mixedRestSeconds,
      mixedWeightsAvgHeartRate:
          mixedWeightsAvgHeartRate ?? this.mixedWeightsAvgHeartRate,
      mixedCardioAvgHeartRate:
          mixedCardioAvgHeartRate ?? this.mixedCardioAvgHeartRate,
      freeDurationMinutes: freeDurationMinutes ?? this.freeDurationMinutes,
      freePauseMinutes: freePauseMinutes ?? this.freePauseMinutes,
      freeAvgHeartRate: freeAvgHeartRate ?? this.freeAvgHeartRate,
      freeIntensityCode: freeIntensityCode ?? this.freeIntensityCode,
      fieldSources: fieldSources ?? this.fieldSources,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        ActivityFieldKeys.presetCode: presetCode,
        ActivityFieldKeys.sessionsPerWeek: sessionsPerWeek,
        ActivityFieldKeys.weightsDurationMinutes: weightsDurationMinutes,
        ActivityFieldKeys.weightSets: weightSets,
        ActivityFieldKeys.restSeconds: restSeconds,
        ActivityFieldKeys.setDurationSeconds: setDurationSeconds,
        ActivityFieldKeys.averageRir: averageRir,
        ActivityFieldKeys.weightsAvgHeartRate: weightsAvgHeartRate,
        ActivityFieldKeys.inactiveMinutes: inactiveMinutes,
        ActivityFieldKeys.weightsOrganizationCode: weightsOrganizationCode,
        ActivityFieldKeys.cardioDurationMinutes: cardioDurationMinutes,
        ActivityFieldKeys.cardioMachineCode: cardioMachineCode,
        ActivityFieldKeys.cardioIntensityCode: cardioIntensityCode,
        ActivityFieldKeys.cardioAvgHeartRate: cardioAvgHeartRate,
        ActivityFieldKeys.cardioPauseMinutes: cardioPauseMinutes,
        ActivityFieldKeys.cardioSpeedKmh: cardioSpeedKmh,
        ActivityFieldKeys.cardioInclinePercent: cardioInclinePercent,
        ActivityFieldKeys.cardioWatts: cardioWatts,
        ActivityFieldKeys.intervalCount: intervalCount,
        ActivityFieldKeys.activeIntervalSeconds: activeIntervalSeconds,
        ActivityFieldKeys.recoveryIntervalSeconds: recoveryIntervalSeconds,
        ActivityFieldKeys.mixedDurationMinutes: mixedDurationMinutes,
        ActivityFieldKeys.mixedRounds: mixedRounds,
        ActivityFieldKeys.mixedWeightPhaseSeconds: mixedWeightPhaseSeconds,
        ActivityFieldKeys.mixedCardioPhaseSeconds: mixedCardioPhaseSeconds,
        ActivityFieldKeys.mixedRestSeconds: mixedRestSeconds,
        ActivityFieldKeys.mixedWeightsAvgHeartRate: mixedWeightsAvgHeartRate,
        ActivityFieldKeys.mixedCardioAvgHeartRate: mixedCardioAvgHeartRate,
        ActivityFieldKeys.freeDurationMinutes: freeDurationMinutes,
        ActivityFieldKeys.freePauseMinutes: freePauseMinutes,
        ActivityFieldKeys.freeAvgHeartRate: freeAvgHeartRate,
        ActivityFieldKeys.freeIntensityCode: freeIntensityCode,
        'fieldSources': fieldSources,
      };

  String toJsonString() => jsonEncode(toJson());

  factory ProfileActivityConfig.fromJsonString(
    String raw, {
    required String legacyWorkoutTypeCode,
    required int legacyDurationMinutes,
    required int legacySessionsPerWeek,
  }) {
    final ProfileActivityConfig fallback = _legacyFallback(
      legacyWorkoutTypeCode,
      legacyDurationMinutes,
      legacySessionsPerWeek,
    );
    if (raw.trim().isEmpty) return fallback;
    try {
      final Object? decodedObject = jsonDecode(raw);
      if (decodedObject is! Map<String, dynamic>) return fallback;
      final Map<String, dynamic> decoded = decodedObject;

      String stringValue(String key, String fallbackValue, Set<String> values) {
        final String value = decoded[key]?.toString() ?? fallbackValue;
        return values.contains(value) ? value : fallbackValue;
      }

      int intValue(String key, int fallbackValue) {
        final Object? value = decoded[key];
        return value is num
            ? value.round()
            : int.tryParse('$value') ?? fallbackValue;
      }

      double doubleValue(String key, double fallbackValue) {
        final Object? value = decoded[key];
        return value is num
            ? value.toDouble()
            : double.tryParse('$value') ?? fallbackValue;
      }

      final Map<String, String> sources = <String, String>{};
      final Object? rawSources = decoded['fieldSources'];
      if (rawSources is Map) {
        for (final MapEntry<Object?, Object?> entry in rawSources.entries) {
          final String key = '${entry.key}';
          final String value = '${entry.value}';
          if (ActivityFieldKeys.all.contains(key) &&
              ActivityInputSourceCodes.values.contains(value)) {
            sources[key] = value;
          }
        }
      } else {
        for (final String key in ActivityFieldKeys.all) {
          if (decoded.containsKey(key)) {
            sources[key] = ActivityInputSourceCodes.user;
          }
        }
      }

      return ProfileActivityConfig(
        version: intValue('version', 2),
        presetCode: stringValue(
          ActivityFieldKeys.presetCode,
          fallback.presetCode,
          ActivityPresetCodes.values,
        ),
        sessionsPerWeek: doubleValue(
          ActivityFieldKeys.sessionsPerWeek,
          fallback.sessionsPerWeek,
        ),
        weightsDurationMinutes: intValue(
          ActivityFieldKeys.weightsDurationMinutes,
          fallback.weightsDurationMinutes,
        ),
        weightSets: intValue(ActivityFieldKeys.weightSets, fallback.weightSets),
        restSeconds: intValue(
          ActivityFieldKeys.restSeconds,
          fallback.restSeconds,
        ),
        setDurationSeconds: intValue(
          ActivityFieldKeys.setDurationSeconds,
          fallback.setDurationSeconds,
        ),
        averageRir: intValue(ActivityFieldKeys.averageRir, fallback.averageRir),
        weightsAvgHeartRate: intValue(
          ActivityFieldKeys.weightsAvgHeartRate,
          fallback.weightsAvgHeartRate,
        ),
        inactiveMinutes: intValue(
          ActivityFieldKeys.inactiveMinutes,
          fallback.inactiveMinutes,
        ),
        weightsOrganizationCode: stringValue(
          ActivityFieldKeys.weightsOrganizationCode,
          fallback.weightsOrganizationCode,
          WeightOrganizationCodes.values,
        ),
        cardioDurationMinutes: intValue(
          ActivityFieldKeys.cardioDurationMinutes,
          fallback.cardioDurationMinutes,
        ),
        cardioMachineCode: stringValue(
          ActivityFieldKeys.cardioMachineCode,
          fallback.cardioMachineCode,
          CardioMachineCodes.values,
        ),
        cardioIntensityCode: stringValue(
          ActivityFieldKeys.cardioIntensityCode,
          fallback.cardioIntensityCode,
          ActivityIntensityCodes.values,
        ),
        cardioAvgHeartRate: intValue(
          ActivityFieldKeys.cardioAvgHeartRate,
          fallback.cardioAvgHeartRate,
        ),
        cardioPauseMinutes: intValue(
          ActivityFieldKeys.cardioPauseMinutes,
          fallback.cardioPauseMinutes,
        ),
        cardioSpeedKmh: doubleValue(
          ActivityFieldKeys.cardioSpeedKmh,
          fallback.cardioSpeedKmh,
        ),
        cardioInclinePercent: doubleValue(
          ActivityFieldKeys.cardioInclinePercent,
          fallback.cardioInclinePercent,
        ),
        cardioWatts: intValue(
          ActivityFieldKeys.cardioWatts,
          fallback.cardioWatts,
        ),
        intervalCount: intValue(
          ActivityFieldKeys.intervalCount,
          fallback.intervalCount,
        ),
        activeIntervalSeconds: intValue(
          ActivityFieldKeys.activeIntervalSeconds,
          fallback.activeIntervalSeconds,
        ),
        recoveryIntervalSeconds: intValue(
          ActivityFieldKeys.recoveryIntervalSeconds,
          fallback.recoveryIntervalSeconds,
        ),
        mixedDurationMinutes: intValue(
          ActivityFieldKeys.mixedDurationMinutes,
          fallback.mixedDurationMinutes,
        ),
        mixedRounds: intValue(
          ActivityFieldKeys.mixedRounds,
          fallback.mixedRounds,
        ),
        mixedWeightPhaseSeconds: intValue(
          ActivityFieldKeys.mixedWeightPhaseSeconds,
          fallback.mixedWeightPhaseSeconds,
        ),
        mixedCardioPhaseSeconds: intValue(
          ActivityFieldKeys.mixedCardioPhaseSeconds,
          fallback.mixedCardioPhaseSeconds,
        ),
        mixedRestSeconds: intValue(
          ActivityFieldKeys.mixedRestSeconds,
          fallback.mixedRestSeconds,
        ),
        mixedWeightsAvgHeartRate: intValue(
          ActivityFieldKeys.mixedWeightsAvgHeartRate,
          intValue('mixedAvgHeartRate', fallback.mixedWeightsAvgHeartRate),
        ),
        mixedCardioAvgHeartRate: intValue(
          ActivityFieldKeys.mixedCardioAvgHeartRate,
          intValue('mixedAvgHeartRate', fallback.mixedCardioAvgHeartRate),
        ),
        freeDurationMinutes: intValue(
          ActivityFieldKeys.freeDurationMinutes,
          fallback.freeDurationMinutes,
        ),
        freePauseMinutes: intValue(
          ActivityFieldKeys.freePauseMinutes,
          fallback.freePauseMinutes,
        ),
        freeAvgHeartRate: intValue(
          ActivityFieldKeys.freeAvgHeartRate,
          fallback.freeAvgHeartRate,
        ),
        freeIntensityCode: stringValue(
          ActivityFieldKeys.freeIntensityCode,
          fallback.freeIntensityCode,
          ActivityIntensityCodes.values,
        ),
        fieldSources: Map<String, String>.unmodifiable(sources),
      );
    } catch (_) {
      return fallback;
    }
  }

  static ProfileActivityConfig _legacyFallback(
    String legacyType,
    int legacyDuration,
    int legacySessions,
  ) {
    final int duration = legacyDuration.clamp(10, 240).toInt();
    final int sessions = legacySessions.clamp(0, 14).toInt();
    final Map<String, String> sources = <String, String>{
      ActivityFieldKeys.presetCode: ActivityInputSourceCodes.legacy,
      ActivityFieldKeys.sessionsPerWeek: ActivityInputSourceCodes.legacy,
    };
    if (legacyType == WorkoutActivityTypeCodes.cardio) {
      sources[ActivityFieldKeys.cardioDurationMinutes] =
          ActivityInputSourceCodes.legacy;
      return ProfileActivityConfig(
        presetCode: ActivityPresetCodes.cardioContinuous,
        sessionsPerWeek: sessions.toDouble(),
        cardioDurationMinutes: duration,
        fieldSources: sources,
      );
    }
    if (legacyType == WorkoutActivityTypeCodes.mixed) {
      sources[ActivityFieldKeys.weightsDurationMinutes] =
          ActivityInputSourceCodes.legacy;
      sources[ActivityFieldKeys.cardioDurationMinutes] =
          ActivityInputSourceCodes.legacy;
      return ProfileActivityConfig(
        presetCode: ActivityPresetCodes.weightsCardio,
        sessionsPerWeek: sessions.toDouble(),
        weightsDurationMinutes: (duration * 0.72).round(),
        cardioDurationMinutes: (duration * 0.28).round(),
        fieldSources: sources,
      );
    }
    sources[ActivityFieldKeys.weightsDurationMinutes] =
        ActivityInputSourceCodes.legacy;
    return ProfileActivityConfig(
      presetCode: ActivityPresetCodes.weights,
      sessionsPerWeek: sessions.toDouble(),
      weightsDurationMinutes: duration,
      fieldSources: sources,
    );
  }
}

class ActivityEstimateSegment {
  const ActivityEstimateSegment({
    required this.label,
    required this.minutes,
    required this.grossMet,
    required this.netMet,
    required this.weightKg,
    required this.heartRateFactor,
    required this.baseActiveKcal,
    required this.activeKcal,
    required this.source,
    required this.formula,
  });

  final String label;
  final double minutes;
  final double grossMet;
  final double netMet;
  final double weightKg;
  final double heartRateFactor;
  final double baseActiveKcal;
  final double activeKcal;
  final String source;
  final String formula;

  double get heartRateAdjustmentKcal => activeKcal - baseActiveKcal;
}

class ActivityParameterAudit {
  const ActivityParameterAudit({
    required this.key,
    required this.section,
    required this.label,
    required this.rawValue,
    required this.usedValue,
    required this.sourceCode,
    required this.usedInEstimate,
    required this.role,
    required this.formula,
    required this.effect,
  });

  final String key;
  final String section;
  final String label;
  final String rawValue;
  final String usedValue;
  final String sourceCode;
  final bool usedInEstimate;
  final String role;
  final String formula;
  final String effect;

  String get sourceLabel => switch (sourceCode) {
        ActivityInputSourceCodes.user => 'Inserito dall’utente',
        ActivityInputSourceCodes.legacy => 'Importato dal profilo precedente',
        ActivityInputSourceCodes.profile => 'Letto dal profilo',
        ActivityInputSourceCodes.derived => 'Derivato dal calcolo',
        _ => 'Valore predefinito / stimato',
      };
}

class ActivityImpactScenario {
  const ActivityImpactScenario({
    required this.label,
    required this.resultPerSessionKcal,
    required this.deltaPerSessionKcal,
    required this.resultDailyKcal,
    required this.deltaDailyKcal,
  });

  final String label;
  final double resultPerSessionKcal;
  final double deltaPerSessionKcal;
  final double resultDailyKcal;
  final double deltaDailyKcal;
}

class ActivityParameterImpact {
  const ActivityParameterImpact({
    required this.key,
    required this.label,
    required this.currentValue,
    required this.note,
    required this.scenarios,
  });

  final String key;
  final String label;
  final String currentValue;
  final String note;
  final List<ActivityImpactScenario> scenarios;
}

class ActivityConfidenceEntry {
  const ActivityConfidenceEntry({
    required this.label,
    required this.points,
    required this.reason,
  });

  final String label;
  final int points;
  final String reason;
}

class ActivityCalculationLine {
  const ActivityCalculationLine({
    required this.label,
    required this.expression,
    required this.result,
  });

  final String label;
  final String expression;
  final String result;
}

class ProfileActivityEstimate {
  const ProfileActivityEstimate({
    required this.perSessionKcal,
    required this.weeklyKcal,
    required this.dailyKcal,
    required this.lowEstimateKcal,
    required this.highEstimateKcal,
    required this.confidenceScore,
    required this.segments,
    required this.parameters,
    required this.impacts,
    required this.confidenceEntries,
    required this.calculationLines,
    required this.assumptions,
  });

  final double perSessionKcal;
  final double weeklyKcal;
  final double dailyKcal;
  final double lowEstimateKcal;
  final double highEstimateKcal;
  final int confidenceScore;
  final List<ActivityEstimateSegment> segments;
  final List<ActivityParameterAudit> parameters;
  final List<ActivityParameterImpact> impacts;
  final List<ActivityConfidenceEntry> confidenceEntries;
  final List<ActivityCalculationLine> calculationLines;
  final List<String> assumptions;

  String get confidenceLabel {
    if (confidenceScore >= 75) return 'Alta';
    if (confidenceScore >= 50) return 'Media';
    return 'Bassa';
  }

  ProfileActivityEstimate withImpacts(List<ActivityParameterImpact> value) {
    return ProfileActivityEstimate(
      perSessionKcal: perSessionKcal,
      weeklyKcal: weeklyKcal,
      dailyKcal: dailyKcal,
      lowEstimateKcal: lowEstimateKcal,
      highEstimateKcal: highEstimateKcal,
      confidenceScore: confidenceScore,
      segments: segments,
      parameters: parameters,
      impacts: List<ActivityParameterImpact>.unmodifiable(value),
      confidenceEntries: confidenceEntries,
      calculationLines: calculationLines,
      assumptions: assumptions,
    );
  }
}

class ProfileActivityEstimator {
  const ProfileActivityEstimator._();

  static ProfileActivityEstimate estimate({
    required ProfileActivityConfig config,
    required double weightKg,
  }) {
    final ProfileActivityEstimate core = _estimateCore(
      config: config,
      weightKg: weightKg,
      collectDetails: true,
    );
    return core.withImpacts(
      _buildImpacts(config: config, weightKg: weightKg, current: core),
    );
  }

  static ProfileActivityEstimate _estimateCore({
    required ProfileActivityConfig config,
    required double weightKg,
    required bool collectDetails,
  }) {
    final double safeWeight = weightKg.clamp(35, 250).toDouble();
    final List<ActivityEstimateSegment> segments = <ActivityEstimateSegment>[];
    final List<ActivityParameterAudit> parameters = <ActivityParameterAudit>[];
    final List<ActivityConfidenceEntry> confidenceEntries =
        <ActivityConfidenceEntry>[
      const ActivityConfidenceEntry(
        label: 'Base modello',
        points: 30,
        reason: 'Punteggio iniziale prima della qualità degli input.',
      ),
    ];
    final List<ActivityCalculationLine> calculationLines =
        <ActivityCalculationLine>[];
    final List<String> assumptions = <String>[];
    int confidence = 30;

    void addConfidence(String label, int points, String reason) {
      confidence += points;
      if (collectDetails) {
        confidenceEntries.add(
          ActivityConfidenceEntry(label: label, points: points, reason: reason),
        );
      }
    }

    double addSegment({
      required String label,
      required double minutes,
      required double grossMet,
      required String source,
      double heartRateFactor = 1,
    }) {
      final double safeMinutes = minutes.clamp(0, 480).toDouble();
      final double safeGrossMet = grossMet.clamp(1, 18).toDouble();
      final double netMet = (safeGrossMet - 1).clamp(0, 17).toDouble();
      if (safeMinutes <= 0 || netMet <= 0) return 0;
      final double baseKcal = netMet * safeWeight * safeMinutes / 60;
      final double kcal = baseKcal * heartRateFactor;
      segments.add(
        ActivityEstimateSegment(
          label: label,
          minutes: safeMinutes,
          grossMet: safeGrossMet,
          netMet: netMet,
          weightKg: safeWeight,
          heartRateFactor: heartRateFactor,
          baseActiveKcal: baseKcal,
          activeKcal: kcal,
          source: source,
          formula: '(${safeGrossMet.toStringAsFixed(2)} − 1) × '
              '${safeWeight.toStringAsFixed(1)} kg × '
              '${safeMinutes.toStringAsFixed(1)} min ÷ 60 × '
              '${heartRateFactor.toStringAsFixed(3)}',
        ),
      );
      return kcal;
    }

    double heartRateFactor(int bpm, String label) {
      if (bpm <= 0) {
        assumptions.add('$label non indicato: fattore cardiaco neutro 1,000.');
        return 1;
      }
      final int safeBpm = bpm.clamp(40, 220).toInt();
      if (safeBpm != bpm) {
        assumptions.add('$label $bpm bpm limitato a $safeBpm bpm.');
      }
      addConfidence(
        label,
        8,
        'Battito medio disponibile come controllo limitato.',
      );
      if (safeBpm < 90) return 0.94;
      if (safeBpm < 110) return 0.98;
      if (safeBpm < 140) return 1.03;
      if (safeBpm < 165) return 1.07;
      return 1.10;
    }

    double weightsGrossMet({required bool circuitBias}) {
      double gross;
      if (config.averageRir >= 4) {
        gross = 4.0;
      } else if (config.averageRir >= 2) {
        gross = 5.0;
      } else if (config.averageRir == 1) {
        gross = 5.7;
      } else {
        gross = 6.2;
      }
      gross += switch (config.weightsOrganizationCode) {
        WeightOrganizationCodes.supersets => 0.7,
        WeightOrganizationCodes.giantSets => 1.1,
        WeightOrganizationCodes.circuit => 1.4,
        _ => 0,
      };
      if (circuitBias) gross += 0.5;
      return gross.clamp(3.5, 7.8).toDouble();
    }

    double cardioGrossMet() {
      final String intensity = config.cardioIntensityCode;
      final double fallback = switch (config.cardioMachineCode) {
        CardioMachineCodes.elliptical =>
          intensity == ActivityIntensityCodes.light
              ? 5
              : intensity == ActivityIntensityCodes.vigorous
                  ? 9
                  : 7,
        CardioMachineCodes.rower => intensity == ActivityIntensityCodes.light
            ? 4.8
            : intensity == ActivityIntensityCodes.vigorous
                ? 9
                : 7,
        CardioMachineCodes.stairClimber =>
          intensity == ActivityIntensityCodes.light
              ? 6
              : intensity == ActivityIntensityCodes.vigorous
                  ? 10
                  : 8,
        CardioMachineCodes.outdoorWalk =>
          intensity == ActivityIntensityCodes.light
              ? 3
              : intensity == ActivityIntensityCodes.vigorous
                  ? 5.5
                  : 4,
        CardioMachineCodes.outdoorRun =>
          intensity == ActivityIntensityCodes.light
              ? 6
              : intensity == ActivityIntensityCodes.vigorous
                  ? 11
                  : 8.5,
        _ => intensity == ActivityIntensityCodes.light
            ? 3.5
            : intensity == ActivityIntensityCodes.vigorous
                ? 9
                : 6,
      };

      if (config.cardioMachineCode == CardioMachineCodes.treadmill &&
          config.cardioSpeedKmh > 0) {
        final double speedMMin = config.cardioSpeedKmh * 1000 / 60;
        final double grade = config.cardioInclinePercent.clamp(0, 30) / 100;
        final bool running = config.cardioSpeedKmh >= 8;
        final double vo2 = running
            ? 0.2 * speedMMin + 0.9 * speedMMin * grade + 3.5
            : 0.1 * speedMMin + 1.8 * speedMMin * grade + 3.5;
        addConfidence(
          'Velocità e pendenza tapis roulant',
          18,
          'MET derivato da velocità e pendenza invece del solo livello.',
        );
        return (vo2 / 3.5).clamp(2, 18).toDouble();
      }
      if ((config.cardioMachineCode == CardioMachineCodes.bike ||
              config.cardioMachineCode == CardioMachineCodes.elliptical ||
              config.cardioMachineCode == CardioMachineCodes.rower) &&
          config.cardioWatts > 0) {
        addConfidence(
          'Potenza cardio',
          18,
          'MET derivato dai watt e dal peso.',
        );
        final double vo2 = 10.8 * config.cardioWatts / safeWeight + 7;
        return (vo2 / 3.5).clamp(2, 18).toDouble();
      }
      assumptions.add(
        'Dati macchina insufficienti: MET ricavato da tipo e intensità.',
      );
      return fallback;
    }

    void estimateWeights({
      required int durationMinutes,
      required int bpm,
      bool circuitBias = false,
    }) {
      final double total = durationMinutes.clamp(0, 300).toDouble();
      final double inactive =
          config.inactiveMinutes.clamp(0, total.round()).toDouble();
      final double available = (total - inactive).clamp(0, total).toDouble();
      final int sets = config.weightSets.clamp(0, 80).toInt();
      final int setSeconds = config.setDurationSeconds.clamp(15, 120).toInt();
      final int restSeconds = config.restSeconds.clamp(15, 600).toInt();
      final double workMinutes =
          (sets * setSeconds / 60).clamp(0, available).toDouble();
      final double plannedRest = ((sets - 1).clamp(0, 79) * restSeconds / 60)
          .clamp(0, (available - workMinutes).clamp(0, available))
          .toDouble();
      final double transition = (available - workMinutes - plannedRest)
          .clamp(0, available)
          .toDouble();
      final double gross = weightsGrossMet(circuitBias: circuitBias);
      final double hrFactor = heartRateFactor(bpm, 'Battito medio pesi');
      final double restGross =
          config.weightsOrganizationCode == WeightOrganizationCodes.traditional
              ? 1.75
              : 2.05;

      addSegment(
        label: 'Serie con i pesi',
        minutes: workMinutes,
        grossMet: gross,
        source: 'Serie × durata serie; MET da RIR e organizzazione',
        heartRateFactor: hrFactor,
      );
      addSegment(
        label: 'Recuperi fisiologici',
        minutes: plannedRest,
        grossMet: restGross,
        source: '(serie − 1) × recupero medio',
        heartRateFactor: hrFactor,
      );
      addSegment(
        label: 'Transizioni e preparazione',
        minutes: transition,
        grossMet: 2.0,
        source: 'Durata residua dopo serie, recuperi e inattività',
        heartRateFactor: hrFactor,
      );

      if (inactive > 0) {
        assumptions.add(
          '${inactive.toStringAsFixed(1)} min inattivi esclusi completamente.',
        );
        addConfidence(
          'Tempo inattivo dichiarato',
          8,
          'Riduce il rischio di conteggiare conversazioni e attese.',
        );
      }
      if (sets > 0) {
        addConfidence(
          'Numero serie',
          12,
          'Consente di stimare il lavoro effettivo.',
        );
      }
      if (config.restSeconds > 0) {
        addConfidence('Recupero medio', 8, 'Separa lavoro e recuperi.');
      }
      if (config.setDurationSeconds > 0) {
        addConfidence(
          'Durata serie',
          6,
          'Definisce il tempo attivo sotto carico.',
        );
      }

      if (collectDetails) {
        parameters.addAll(<ActivityParameterAudit>[
          ActivityParameterAudit(
            key: 'derived.weights.availableMinutes',
            section: 'Pesi · tempi derivati',
            label: 'Tempo metabolicamente disponibile',
            rawValue: '${total.toStringAsFixed(1)} min totali',
            usedValue: '${available.toStringAsFixed(1)} min',
            sourceCode: ActivityInputSourceCodes.derived,
            usedInEstimate: true,
            role: 'Durata totale meno tempo inattivo.',
            formula:
                '${total.toStringAsFixed(1)} − ${inactive.toStringAsFixed(1)}',
            effect: 'Limita la somma di serie, recuperi e transizioni.',
          ),
          ActivityParameterAudit(
            key: 'derived.weights.workMinutes',
            section: 'Pesi · tempi derivati',
            label: 'Minuti effettivi delle serie',
            rawValue: '$sets serie × $setSeconds s',
            usedValue: '${workMinutes.toStringAsFixed(1)} min',
            sourceCode: ActivityInputSourceCodes.derived,
            usedInEstimate: true,
            role: 'Tempo al MET più alto del blocco pesi.',
            formula: '$sets × $setSeconds ÷ 60',
            effect:
                'Aumenta linearmente le calorie delle serie finché non raggiunge la durata disponibile.',
          ),
          ActivityParameterAudit(
            key: 'derived.weights.restMinutes',
            section: 'Pesi · tempi derivati',
            label: 'Minuti di recupero',
            rawValue: '${(sets - 1).clamp(0, 79)} recuperi × $restSeconds s',
            usedValue: '${plannedRest.toStringAsFixed(1)} min',
            sourceCode: ActivityInputSourceCodes.derived,
            usedInEstimate: true,
            role: 'Tempo conteggiato a MET basso, non come serie.',
            formula: '(serie − 1) × recupero ÷ 60',
            effect:
                'Sostituisce parte delle transizioni con recupero a intensità inferiore.',
          ),
          ActivityParameterAudit(
            key: 'derived.weights.transitionMinutes',
            section: 'Pesi · tempi derivati',
            label: 'Minuti di transizione',
            rawValue: 'Tempo residuo',
            usedValue: '${transition.toStringAsFixed(1)} min',
            sourceCode: ActivityInputSourceCodes.derived,
            usedInEstimate: true,
            role: 'Preparazione attrezzi e spostamenti non inattivi.',
            formula: 'disponibile − serie − recuperi',
            effect: 'Conteggiato a 2,0 MET lordi.',
          ),
          ActivityParameterAudit(
            key: 'derived.weights.grossMet',
            section: 'Pesi · intensità derivata',
            label: 'MET lordo delle serie',
            rawValue: 'RIR + organizzazione',
            usedValue: gross.toStringAsFixed(2),
            sourceCode: ActivityInputSourceCodes.derived,
            usedInEstimate: true,
            role: 'Intensità della fase sotto carico.',
            formula:
                'MET base RIR + bonus organizzazione${circuitBias ? ' + bonus circuito' : ''}',
            effect:
                'Il calcolo usa MET netto ${(gross - 1).toStringAsFixed(2)} dopo la sottrazione del riposo.',
          ),
          ActivityParameterAudit(
            key: 'derived.weights.hrFactor',
            section: 'Pesi · intensità derivata',
            label: 'Fattore cardiaco pesi',
            rawValue: bpm > 0 ? '$bpm bpm' : 'Non indicato',
            usedValue: hrFactor.toStringAsFixed(3),
            sourceCode: ActivityInputSourceCodes.derived,
            usedInEstimate: true,
            role: 'Correzione limitata, non formula principale.',
            formula: 'Fascia del battito medio',
            effect:
                '${((hrFactor - 1) * 100).toStringAsFixed(1)}% sulle componenti del blocco pesi.',
          ),
        ]);
      }
    }

    void estimateCardio({required bool intervals}) {
      final double total =
          config.cardioDurationMinutes.clamp(0, 300).toDouble();
      final double pause =
          config.cardioPauseMinutes.clamp(0, total.round()).toDouble();
      final double available = (total - pause).clamp(0, total).toDouble();
      final double gross = cardioGrossMet();
      final double hrFactor = heartRateFactor(
        config.cardioAvgHeartRate,
        'Battito medio cardio',
      );

      double activeMinutes = 0;
      double recoveryMinutes = 0;
      double residual = 0;
      if (intervals) {
        final int count = config.intervalCount.clamp(1, 80).toInt();
        activeMinutes =
            (count * config.activeIntervalSeconds.clamp(10, 900) / 60)
                .clamp(0, available)
                .toDouble();
        recoveryMinutes =
            (count * config.recoveryIntervalSeconds.clamp(10, 900) / 60)
                .clamp(0, (available - activeMinutes).clamp(0, available))
                .toDouble();
        residual = (available - activeMinutes - recoveryMinutes)
            .clamp(0, available)
            .toDouble();
        addSegment(
          label: 'Intervalli attivi',
          minutes: activeMinutes,
          grossMet: (gross + 1.2).clamp(1, 18).toDouble(),
          source: 'Tipo cardio, dati macchina, intensità e intervalli',
          heartRateFactor: hrFactor,
        );
        addSegment(
          label: 'Recuperi cardio',
          minutes: recoveryMinutes,
          grossMet: 2.4,
          source: 'Numero e durata dei recuperi',
          heartRateFactor: hrFactor,
        );
        addSegment(
          label: 'Cardio residuo',
          minutes: residual,
          grossMet: gross,
          source: 'Tempo disponibile non assegnato agli intervalli',
          heartRateFactor: hrFactor,
        );
        addConfidence(
          'Struttura intervalli',
          12,
          'Numero, lavoro e recupero separati.',
        );
      } else {
        addSegment(
          label: 'Cardio continuo',
          minutes: available,
          grossMet: gross,
          source: 'Macchinario, intensità e dati prestazione',
          heartRateFactor: hrFactor,
        );
      }
      addSegment(
        label: 'Pause cardio',
        minutes: pause,
        grossMet: 1.45,
        source: 'Pause dichiarate',
      );
      if (pause <= 0) {
        assumptions.add('Pause cardio non indicate: considerate nulle.');
      }
      if (config.cardioDurationMinutes > 0) {
        addConfidence('Durata cardio', 8, 'Durata totale disponibile.');
      }

      if (collectDetails) {
        parameters.addAll(<ActivityParameterAudit>[
          ActivityParameterAudit(
            key: 'derived.cardio.availableMinutes',
            section: 'Cardio · tempi derivati',
            label: 'Tempo cardio disponibile',
            rawValue: '${total.toStringAsFixed(1)} min totali',
            usedValue: '${available.toStringAsFixed(1)} min',
            sourceCode: ActivityInputSourceCodes.derived,
            usedInEstimate: true,
            role: 'Durata cardio meno pause.',
            formula:
                '${total.toStringAsFixed(1)} − ${pause.toStringAsFixed(1)}',
            effect: 'Limita il tempo assegnato ai segmenti cardio.',
          ),
          ActivityParameterAudit(
            key: 'derived.cardio.grossMet',
            section: 'Cardio · intensità derivata',
            label: 'MET lordo cardio',
            rawValue: 'Macchinario + intensità + dati prestazione',
            usedValue: gross.toStringAsFixed(2),
            sourceCode: ActivityInputSourceCodes.derived,
            usedInEstimate: true,
            role: 'Intensità prima della sottrazione del riposo.',
            formula: _cardioFormulaDescription(config, safeWeight),
            effect:
                'Il calcolo usa MET netto ${(gross - 1).toStringAsFixed(2)}.',
          ),
          ActivityParameterAudit(
            key: 'derived.cardio.hrFactor',
            section: 'Cardio · intensità derivata',
            label: 'Fattore cardiaco cardio',
            rawValue: config.cardioAvgHeartRate > 0
                ? '${config.cardioAvgHeartRate} bpm'
                : 'Non indicato',
            usedValue: hrFactor.toStringAsFixed(3),
            sourceCode: ActivityInputSourceCodes.derived,
            usedInEstimate: true,
            role: 'Correzione limitata della stima cardio.',
            formula: 'Fascia del battito medio',
            effect:
                '${((hrFactor - 1) * 100).toStringAsFixed(1)}% sui segmenti cardio.',
          ),
          if (intervals) ...<ActivityParameterAudit>[
            ActivityParameterAudit(
              key: 'derived.cardio.activeMinutes',
              section: 'Cardio · tempi derivati',
              label: 'Minuti intervalli attivi',
              rawValue:
                  '${config.intervalCount} × ${config.activeIntervalSeconds} s',
              usedValue: '${activeMinutes.toStringAsFixed(1)} min',
              sourceCode: ActivityInputSourceCodes.derived,
              usedInEstimate: true,
              role: 'Fase al MET più elevato.',
              formula: 'intervalli × secondi attivi ÷ 60',
              effect: 'Sposta tempo verso il segmento ad alta intensità.',
            ),
            ActivityParameterAudit(
              key: 'derived.cardio.recoveryMinutes',
              section: 'Cardio · tempi derivati',
              label: 'Minuti recuperi intervalli',
              rawValue:
                  '${config.intervalCount} × ${config.recoveryIntervalSeconds} s',
              usedValue: '${recoveryMinutes.toStringAsFixed(1)} min',
              sourceCode: ActivityInputSourceCodes.derived,
              usedInEstimate: true,
              role: 'Fase a intensità ridotta.',
              formula: 'intervalli × secondi recupero ÷ 60',
              effect: 'Sposta tempo dal cardio residuo ai recuperi.',
            ),
            ActivityParameterAudit(
              key: 'derived.cardio.residualMinutes',
              section: 'Cardio · tempi derivati',
              label: 'Minuti cardio residui',
              rawValue: 'Tempo non assegnato',
              usedValue: '${residual.toStringAsFixed(1)} min',
              sourceCode: ActivityInputSourceCodes.derived,
              usedInEstimate: true,
              role: 'Cardio al MET base.',
              formula: 'disponibile − attivi − recuperi',
              effect: 'Evita che minuti non classificati vengano persi.',
            ),
          ],
        ]);
      }
    }

    switch (config.presetCode) {
      case ActivityPresetCodes.weights:
        estimateWeights(
          durationMinutes: config.weightsDurationMinutes,
          bpm: config.weightsAvgHeartRate,
        );
        break;
      case ActivityPresetCodes.cardioContinuous:
        estimateCardio(intervals: false);
        break;
      case ActivityPresetCodes.cardioIntervals:
        estimateCardio(intervals: true);
        break;
      case ActivityPresetCodes.weightsCardio:
        estimateWeights(
          durationMinutes: config.weightsDurationMinutes,
          bpm: config.weightsAvgHeartRate,
        );
        estimateCardio(intervals: false);
        addConfidence(
          'Blocchi separati pesi + cardio',
          6,
          'Le due componenti sono calcolate indipendentemente.',
        );
        break;
      case ActivityPresetCodes.mixedCircuit:
        final int rounds = config.mixedRounds.clamp(1, 60).toInt();
        final double rawWeightMinutes =
            rounds * config.mixedWeightPhaseSeconds.clamp(10, 900) / 60;
        final double rawCardioMinutes =
            rounds * config.mixedCardioPhaseSeconds.clamp(10, 900) / 60;
        final double rawRestMinutes =
            rounds * config.mixedRestSeconds.clamp(0, 600) / 60;
        final double total =
            config.mixedDurationMinutes.clamp(0, 300).toDouble();
        final double planned =
            rawWeightMinutes + rawCardioMinutes + rawRestMinutes;
        final double scale = planned > total && total > 0 ? total / planned : 1;
        final double weightMinutes = rawWeightMinutes * scale;
        final double cardioMinutes = rawCardioMinutes * scale;
        final double restMinutes = rawRestMinutes * scale;
        final double residual =
            (total - weightMinutes - cardioMinutes - restMinutes)
                .clamp(0, total)
                .toDouble();
        final double weightsHrFactor = heartRateFactor(
          config.mixedWeightsAvgHeartRate,
          'Battito medio fasi pesi del circuito',
        );
        final double cardioHrFactor = heartRateFactor(
          config.mixedCardioAvgHeartRate,
          'Battito medio fasi cardio del circuito',
        );
        final double weightGross = weightsGrossMet(circuitBias: true);
        final double cardioGross = cardioGrossMet();

        addSegment(
          label: 'Fasi pesi del circuito',
          minutes: weightMinutes,
          grossMet: weightGross,
          source: 'Round, fase pesi, RIR e organizzazione',
          heartRateFactor: weightsHrFactor,
        );
        addSegment(
          label: 'Fasi cardio del circuito',
          minutes: cardioMinutes,
          grossMet: cardioGross,
          source: 'Round, fase cardio, macchinario e intensità',
          heartRateFactor: cardioHrFactor,
        );
        addSegment(
          label: 'Recuperi del circuito',
          minutes: restMinutes,
          grossMet: 1.9,
          source: 'Round e recupero medio',
        );
        addSegment(
          label: 'Transizioni del circuito',
          minutes: residual,
          grossMet: 2.2,
          source: 'Tempo residuo della durata dichiarata',
        );
        addConfidence(
          'Circuito segmentato',
          20,
          'Fasi pesi, cardio e recupero sono separate.',
        );
        if (collectDetails) {
          parameters.addAll(<ActivityParameterAudit>[
            ActivityParameterAudit(
              key: 'derived.mixed.scale',
              section: 'Misto · tempi derivati',
              label: 'Fattore di adattamento alla durata',
              rawValue: '${planned.toStringAsFixed(1)} min pianificati',
              usedValue: scale.toStringAsFixed(3),
              sourceCode: ActivityInputSourceCodes.derived,
              usedInEstimate: true,
              role: 'Evita che i round superino la durata totale.',
              formula: planned > total && total > 0
                  ? '${total.toStringAsFixed(1)} ÷ ${planned.toStringAsFixed(1)}'
                  : '1,000',
              effect: 'Moltiplica tutte le durate derivate del circuito.',
            ),
            ActivityParameterAudit(
              key: 'derived.mixed.weightMinutes',
              section: 'Misto · tempi derivati',
              label: 'Minuti pesi circuito',
              rawValue: '$rounds × ${config.mixedWeightPhaseSeconds} s',
              usedValue: '${weightMinutes.toStringAsFixed(1)} min',
              sourceCode: ActivityInputSourceCodes.derived,
              usedInEstimate: true,
              role: 'Fase pesi del circuito.',
              formula: 'round × fase pesi ÷ 60 × scala',
              effect: 'Calcolata al MET pesi derivato da RIR e organizzazione.',
            ),
            ActivityParameterAudit(
              key: 'derived.mixed.cardioMinutes',
              section: 'Misto · tempi derivati',
              label: 'Minuti cardio circuito',
              rawValue: '$rounds × ${config.mixedCardioPhaseSeconds} s',
              usedValue: '${cardioMinutes.toStringAsFixed(1)} min',
              sourceCode: ActivityInputSourceCodes.derived,
              usedInEstimate: true,
              role: 'Fase aerobica del circuito.',
              formula: 'round × fase cardio ÷ 60 × scala',
              effect: 'Calcolata al MET del cardio selezionato.',
            ),
            ActivityParameterAudit(
              key: 'derived.mixed.restMinutes',
              section: 'Misto · tempi derivati',
              label: 'Minuti recupero circuito',
              rawValue: '$rounds × ${config.mixedRestSeconds} s',
              usedValue: '${restMinutes.toStringAsFixed(1)} min',
              sourceCode: ActivityInputSourceCodes.derived,
              usedInEstimate: true,
              role: 'Recupero tra i round.',
              formula: 'round × recupero ÷ 60 × scala',
              effect: 'Conteggiato a 1,9 MET lordi.',
            ),
            ActivityParameterAudit(
              key: 'derived.mixed.weightsHrFactor',
              section: 'Misto · intensità derivata',
              label: 'Fattore cardiaco fasi pesi',
              rawValue: config.mixedWeightsAvgHeartRate > 0
                  ? '${config.mixedWeightsAvgHeartRate} bpm'
                  : 'Non indicato',
              usedValue: weightsHrFactor.toStringAsFixed(3),
              sourceCode: ActivityInputSourceCodes.derived,
              usedInEstimate: true,
              role: 'Correzione limitata della sola fase pesi.',
              formula: 'Fascia del battito medio pesi',
              effect:
                  '${((weightsHrFactor - 1) * 100).toStringAsFixed(1)}% sul segmento pesi.',
            ),
            ActivityParameterAudit(
              key: 'derived.mixed.cardioHrFactor',
              section: 'Misto · intensità derivata',
              label: 'Fattore cardiaco fasi cardio',
              rawValue: config.mixedCardioAvgHeartRate > 0
                  ? '${config.mixedCardioAvgHeartRate} bpm'
                  : 'Non indicato',
              usedValue: cardioHrFactor.toStringAsFixed(3),
              sourceCode: ActivityInputSourceCodes.derived,
              usedInEstimate: true,
              role: 'Correzione limitata della sola fase aerobica.',
              formula: 'Fascia del battito medio cardio',
              effect:
                  '${((cardioHrFactor - 1) * 100).toStringAsFixed(1)}% sul segmento cardio.',
            ),
          ]);
        }
        break;
      case ActivityPresetCodes.freeActivity:
        final double total =
            config.freeDurationMinutes.clamp(0, 300).toDouble();
        final double pause =
            config.freePauseMinutes.clamp(0, total.round()).toDouble();
        final double gross = switch (config.freeIntensityCode) {
          ActivityIntensityCodes.light => 3.5,
          ActivityIntensityCodes.vigorous => 8.5,
          _ => 5.5,
        };
        final double hrFactor = heartRateFactor(
          config.freeAvgHeartRate,
          'Battito medio attività',
        );
        addSegment(
          label: 'Attività libera',
          minutes: total - pause,
          grossMet: gross,
          source: 'Durata e intensità percepita',
          heartRateFactor: hrFactor,
        );
        addSegment(
          label: 'Pause attività',
          minutes: pause,
          grossMet: 1.45,
          source: 'Pause dichiarate',
        );
        if (collectDetails) {
          parameters.addAll(<ActivityParameterAudit>[
            ActivityParameterAudit(
              key: 'derived.free.availableMinutes',
              section: 'Attività libera · derivati',
              label: 'Minuti attivi',
              rawValue:
                  '${total.toStringAsFixed(1)} − ${pause.toStringAsFixed(1)}',
              usedValue: '${(total - pause).toStringAsFixed(1)} min',
              sourceCode: ActivityInputSourceCodes.derived,
              usedInEstimate: true,
              role: 'Durata a cui applicare il MET.',
              formula: 'durata − pause',
              effect: 'Le pause non ricevono il MET dell’attività.',
            ),
            ActivityParameterAudit(
              key: 'derived.free.grossMet',
              section: 'Attività libera · derivati',
              label: 'MET lordo attività libera',
              rawValue: _intensityLabel(config.freeIntensityCode),
              usedValue: gross.toStringAsFixed(2),
              sourceCode: ActivityInputSourceCodes.derived,
              usedInEstimate: true,
              role: 'Fallback generico per attività non specificata.',
              formula: 'MET per intensità percepita',
              effect:
                  'Il calcolo usa MET netto ${(gross - 1).toStringAsFixed(2)}.',
            ),
          ]);
        }
        break;
    }

    final double perSession = segments.fold<double>(
      0,
      (double total, ActivityEstimateSegment segment) =>
          total + segment.activeKcal,
    );
    final double sessions = config.sessionsPerWeek.clamp(0, 14).toDouble();
    final double weekly = perSession * sessions;
    final double daily = weekly / 7;
    if (sessions > 0) {
      addConfidence(
        'Frequenza settimanale',
        5,
        'Permette la conversione da sessione a media giornaliera.',
      );
    }
    final int finalConfidence = confidence.clamp(20, 95).toInt();
    if (collectDetails) {
      confidenceEntries.add(
        ActivityConfidenceEntry(
          label: 'Normalizzazione finale',
          points: 0,
          reason:
              'Somma grezza $confidence; punteggio mostrato limitato a 20–95: $finalConfidence.',
        ),
      );
    }
    final double uncertainty = finalConfidence >= 75
        ? 0.10
        : finalConfidence >= 50
            ? 0.18
            : 0.28;

    if (collectDetails) {
      parameters.insertAll(
        0,
        _buildRawParameterAudits(
          config: config,
          rawWeightKg: weightKg,
          safeWeightKg: safeWeight,
        ),
      );
      calculationLines.addAll(<ActivityCalculationLine>[
        for (final ActivityEstimateSegment segment in segments)
          ActivityCalculationLine(
            label: segment.label,
            expression: segment.formula,
            result: '${segment.activeKcal.toStringAsFixed(2)} kcal attive',
          ),
        ActivityCalculationLine(
          label: 'Totale per sessione',
          expression: 'Somma di ${segments.length} segmenti',
          result: '${perSession.toStringAsFixed(2)} kcal',
        ),
        ActivityCalculationLine(
          label: 'Totale settimanale',
          expression:
              '${perSession.toStringAsFixed(2)} × ${sessions.toStringAsFixed(2)}',
          result: '${weekly.toStringAsFixed(2)} kcal/settimana',
        ),
        ActivityCalculationLine(
          label: 'Media giornaliera',
          expression: '${weekly.toStringAsFixed(2)} ÷ 7',
          result: '${daily.toStringAsFixed(2)} kcal/giorno',
        ),
        ActivityCalculationLine(
          label: 'Intervallo indicativo',
          expression:
              'sessione ± ${(uncertainty * 100).round()}% da confidenza',
          result:
              '${(perSession * (1 - uncertainty)).toStringAsFixed(0)}–${(perSession * (1 + uncertainty)).toStringAsFixed(0)} kcal',
        ),
      ]);
    }

    return ProfileActivityEstimate(
      perSessionKcal: perSession,
      weeklyKcal: weekly,
      dailyKcal: daily,
      lowEstimateKcal: perSession * (1 - uncertainty),
      highEstimateKcal: perSession * (1 + uncertainty),
      confidenceScore: finalConfidence,
      segments: List<ActivityEstimateSegment>.unmodifiable(segments),
      parameters: List<ActivityParameterAudit>.unmodifiable(parameters),
      impacts: const <ActivityParameterImpact>[],
      confidenceEntries: List<ActivityConfidenceEntry>.unmodifiable(
        confidenceEntries,
      ),
      calculationLines: List<ActivityCalculationLine>.unmodifiable(
        calculationLines,
      ),
      assumptions: List<String>.unmodifiable(assumptions.toSet()),
    );
  }

  static List<ActivityParameterImpact> _buildImpacts({
    required ProfileActivityConfig config,
    required double weightKg,
    required ProfileActivityEstimate current,
  }) {
    final List<ActivityParameterImpact> impacts = <ActivityParameterImpact>[];

    ActivityImpactScenario scenario(
      String label, {
      ProfileActivityConfig? variant,
      double? variantWeight,
    }) {
      final ProfileActivityEstimate result = _estimateCore(
        config: variant ?? config,
        weightKg: variantWeight ?? weightKg,
        collectDetails: false,
      );
      return ActivityImpactScenario(
        label: label,
        resultPerSessionKcal: result.perSessionKcal,
        deltaPerSessionKcal: result.perSessionKcal - current.perSessionKcal,
        resultDailyKcal: result.dailyKcal,
        deltaDailyKcal: result.dailyKcal - current.dailyKcal,
      );
    }

    void addImpact({
      required String key,
      required String label,
      required String currentValue,
      required String note,
      required List<ActivityImpactScenario> scenarios,
    }) {
      impacts.add(
        ActivityParameterImpact(
          key: key,
          label: label,
          currentValue: currentValue,
          note: note,
          scenarios: List<ActivityImpactScenario>.unmodifiable(scenarios),
        ),
      );
    }

    addImpact(
      key: 'profileWeightKg',
      label: 'Peso usato',
      currentValue: '${weightKg.toStringAsFixed(1)} kg',
      note: 'Tutte le componenti MET scalano quasi linearmente con il peso.',
      scenarios: <ActivityImpactScenario>[
        scenario(
          '−1 kg',
          variantWeight: (weightKg - 1).clamp(35, 250).toDouble(),
        ),
        scenario(
          '+1 kg',
          variantWeight: (weightKg + 1).clamp(35, 250).toDouble(),
        ),
      ],
    );
    addImpact(
      key: ActivityFieldKeys.sessionsPerWeek,
      label: 'Sessioni settimanali',
      currentValue: config.sessionsPerWeek.toStringAsFixed(1),
      note:
          'Non cambia la singola sessione; cambia linearmente la media giornaliera.',
      scenarios: <ActivityImpactScenario>[
        scenario(
          '−1 sessione/settimana',
          variant: config.copyWith(
            sessionsPerWeek:
                (config.sessionsPerWeek - 1).clamp(0, 14).toDouble(),
          ),
        ),
        scenario(
          '+1 sessione/settimana',
          variant: config.copyWith(
            sessionsPerWeek:
                (config.sessionsPerWeek + 1).clamp(0, 14).toDouble(),
          ),
        ),
      ],
    );
    addImpact(
      key: ActivityFieldKeys.presetCode,
      label: 'Tipo di sessione',
      currentValue: _presetLabel(config.presetCode),
      note:
          'Confronto con gli altri preset usando i valori memorizzati nei rispettivi campi.',
      scenarios: <ActivityImpactScenario>[
        for (final String code in ActivityPresetCodes.values)
          if (code != config.presetCode)
            scenario(
              _presetLabel(code),
              variant: config.copyWith(presetCode: code),
            ),
      ],
    );

    final bool hasWeights = config.presetCode == ActivityPresetCodes.weights ||
        config.presetCode == ActivityPresetCodes.weightsCardio;
    final bool hasCardio =
        config.presetCode == ActivityPresetCodes.cardioContinuous ||
            config.presetCode == ActivityPresetCodes.cardioIntervals ||
            config.presetCode == ActivityPresetCodes.weightsCardio;

    if (hasWeights) {
      addImpact(
        key: ActivityFieldKeys.weightsDurationMinutes,
        label: 'Durata pesi',
        currentValue: '${config.weightsDurationMinutes} min',
        note:
            'A durata fissa, serie e recuperi hanno priorità; il residuo diventa transizione.',
        scenarios: <ActivityImpactScenario>[
          scenario(
            '−5 min',
            variant: config.copyWith(
              weightsDurationMinutes:
                  (config.weightsDurationMinutes - 5).clamp(0, 300).toInt(),
            ),
          ),
          scenario(
            '+5 min',
            variant: config.copyWith(
              weightsDurationMinutes:
                  (config.weightsDurationMinutes + 5).clamp(0, 300).toInt(),
            ),
          ),
        ],
      );
      addImpact(
        key: ActivityFieldKeys.weightSets,
        label: 'Numero serie',
        currentValue: '${config.weightSets}',
        note:
            'Aumenta il tempo sotto carico e i recuperi, entro la durata disponibile.',
        scenarios: <ActivityImpactScenario>[
          scenario(
            '−1 serie',
            variant: config.copyWith(
              weightSets: (config.weightSets - 1).clamp(0, 80).toInt(),
            ),
          ),
          scenario(
            '+1 serie',
            variant: config.copyWith(
              weightSets: (config.weightSets + 1).clamp(0, 80).toInt(),
            ),
          ),
        ],
      );
      addImpact(
        key: ActivityFieldKeys.restSeconds,
        label: 'Recupero medio',
        currentValue: '${config.restSeconds} s',
        note:
            'Sposta tempo dalle transizioni ai recuperi, che hanno un MET inferiore.',
        scenarios: <ActivityImpactScenario>[
          scenario(
            '−30 s',
            variant: config.copyWith(
              restSeconds: (config.restSeconds - 30).clamp(15, 600).toInt(),
            ),
          ),
          scenario(
            '+30 s',
            variant: config.copyWith(
              restSeconds: (config.restSeconds + 30).clamp(15, 600).toInt(),
            ),
          ),
        ],
      );
      addImpact(
        key: ActivityFieldKeys.setDurationSeconds,
        label: 'Durata media serie',
        currentValue: '${config.setDurationSeconds} s',
        note: 'Sposta tempo verso la fase al MET più alto.',
        scenarios: <ActivityImpactScenario>[
          scenario(
            '−5 s',
            variant: config.copyWith(
              setDurationSeconds:
                  (config.setDurationSeconds - 5).clamp(15, 120).toInt(),
            ),
          ),
          scenario(
            '+5 s',
            variant: config.copyWith(
              setDurationSeconds:
                  (config.setDurationSeconds + 5).clamp(15, 120).toInt(),
            ),
          ),
        ],
      );
      addImpact(
        key: ActivityFieldKeys.averageRir,
        label: 'Vicinanza al cedimento',
        currentValue: _rirLabel(config.averageRir),
        note: 'Modifica il MET delle serie, non quello delle pause.',
        scenarios: <ActivityImpactScenario>[
          for (final int rir in <int>[5, 3, 1, 0])
            if (rir != config.averageRir)
              scenario(
                _rirLabel(rir),
                variant: config.copyWith(averageRir: rir),
              ),
        ],
      );
      addImpact(
        key: ActivityFieldKeys.weightsOrganizationCode,
        label: 'Organizzazione serie',
        currentValue: _organizationLabel(config.weightsOrganizationCode),
        note: 'Superserie, giant set e circuito aumentano la densità stimata.',
        scenarios: <ActivityImpactScenario>[
          for (final String code in WeightOrganizationCodes.values)
            if (code != config.weightsOrganizationCode)
              scenario(
                _organizationLabel(code),
                variant: config.copyWith(weightsOrganizationCode: code),
              ),
        ],
      );
      addImpact(
        key: ActivityFieldKeys.inactiveMinutes,
        label: 'Tempo inattivo escluso',
        currentValue: '${config.inactiveMinutes} min',
        note:
            'Viene sottratto prima di distribuire serie, recuperi e transizioni.',
        scenarios: <ActivityImpactScenario>[
          scenario(
            '−5 min',
            variant: config.copyWith(
              inactiveMinutes:
                  (config.inactiveMinutes - 5).clamp(0, 240).toInt(),
            ),
          ),
          scenario(
            '+5 min',
            variant: config.copyWith(
              inactiveMinutes:
                  (config.inactiveMinutes + 5).clamp(0, 240).toInt(),
            ),
          ),
        ],
      );
      addImpact(
        key: ActivityFieldKeys.weightsAvgHeartRate,
        label: 'Battito medio pesi',
        currentValue: config.weightsAvgHeartRate > 0
            ? '${config.weightsAvgHeartRate} bpm'
            : 'Non indicato',
        note:
            'Correzione limitata a fasce; non sostituisce i dati della seduta.',
        scenarios: config.weightsAvgHeartRate > 0
            ? <ActivityImpactScenario>[
                scenario(
                  '−10 bpm',
                  variant: config.copyWith(
                    weightsAvgHeartRate: (config.weightsAvgHeartRate - 10)
                        .clamp(40, 220)
                        .toInt(),
                  ),
                ),
                scenario(
                  '+10 bpm',
                  variant: config.copyWith(
                    weightsAvgHeartRate: (config.weightsAvgHeartRate + 10)
                        .clamp(40, 220)
                        .toInt(),
                  ),
                ),
              ]
            : <ActivityImpactScenario>[
                scenario(
                  'Se fosse 100 bpm',
                  variant: config.copyWith(weightsAvgHeartRate: 100),
                ),
                scenario(
                  'Se fosse 130 bpm',
                  variant: config.copyWith(weightsAvgHeartRate: 130),
                ),
              ],
      );
    }

    if (hasCardio) {
      _addCardioImpacts(
        impacts: impacts,
        config: config,
        scenario: scenario,
        includeIntervals:
            config.presetCode == ActivityPresetCodes.cardioIntervals,
      );
    }

    if (config.presetCode == ActivityPresetCodes.mixedCircuit) {
      addImpact(
        key: ActivityFieldKeys.mixedDurationMinutes,
        label: 'Durata totale circuito',
        currentValue: '${config.mixedDurationMinutes} min',
        note:
            'Se i round eccedono la durata, tutte le fasi vengono ridimensionate.',
        scenarios: <ActivityImpactScenario>[
          scenario(
            '−5 min',
            variant: config.copyWith(
              mixedDurationMinutes:
                  (config.mixedDurationMinutes - 5).clamp(0, 300).toInt(),
            ),
          ),
          scenario(
            '+5 min',
            variant: config.copyWith(
              mixedDurationMinutes:
                  (config.mixedDurationMinutes + 5).clamp(0, 300).toInt(),
            ),
          ),
        ],
      );
      addImpact(
        key: ActivityFieldKeys.mixedRounds,
        label: 'Round circuito',
        currentValue: '${config.mixedRounds}',
        note:
            'Aumenta tutte le fasi finché non interviene il ridimensionamento alla durata.',
        scenarios: <ActivityImpactScenario>[
          scenario(
            '−1 round',
            variant: config.copyWith(
              mixedRounds: (config.mixedRounds - 1).clamp(1, 60).toInt(),
            ),
          ),
          scenario(
            '+1 round',
            variant: config.copyWith(
              mixedRounds: (config.mixedRounds + 1).clamp(1, 60).toInt(),
            ),
          ),
        ],
      );
      for (final ({
        String key,
        String label,
        int current,
        ProfileActivityConfig Function(int) change,
      }) item in <({
        String key,
        String label,
        int current,
        ProfileActivityConfig Function(int) change,
      })>[
        (
          key: ActivityFieldKeys.mixedWeightPhaseSeconds,
          label: 'Fase pesi per round',
          current: config.mixedWeightPhaseSeconds,
          change: (int value) =>
              config.copyWith(mixedWeightPhaseSeconds: value),
        ),
        (
          key: ActivityFieldKeys.mixedCardioPhaseSeconds,
          label: 'Fase cardio per round',
          current: config.mixedCardioPhaseSeconds,
          change: (int value) =>
              config.copyWith(mixedCardioPhaseSeconds: value),
        ),
        (
          key: ActivityFieldKeys.mixedRestSeconds,
          label: 'Recupero per round',
          current: config.mixedRestSeconds,
          change: (int value) => config.copyWith(mixedRestSeconds: value),
        ),
      ]) {
        addImpact(
          key: item.key,
          label: item.label,
          currentValue: '${item.current} s',
          note: 'Modifica la quota temporale della fase corrispondente.',
          scenarios: <ActivityImpactScenario>[
            scenario(
              '−15 s',
              variant: item.change((item.current - 15).clamp(0, 900).toInt()),
            ),
            scenario(
              '+15 s',
              variant: item.change((item.current + 15).clamp(0, 900).toInt()),
            ),
          ],
        );
      }
      addImpact(
        key: ActivityFieldKeys.averageRir,
        label: 'Vicinanza al cedimento nel circuito',
        currentValue: _rirLabel(config.averageRir),
        note: 'Modifica il MET della sola fase pesi.',
        scenarios: <ActivityImpactScenario>[
          for (final int rir in <int>[5, 3, 1, 0])
            if (rir != config.averageRir)
              scenario(
                _rirLabel(rir),
                variant: config.copyWith(averageRir: rir),
              ),
        ],
      );
      for (final ({
        String key,
        String label,
        int bpm,
        ProfileActivityConfig Function(int) change,
      }) item in <({
        String key,
        String label,
        int bpm,
        ProfileActivityConfig Function(int) change,
      })>[
        (
          key: ActivityFieldKeys.mixedWeightsAvgHeartRate,
          label: 'Battito medio fasi pesi',
          bpm: config.mixedWeightsAvgHeartRate,
          change: (int value) =>
              config.copyWith(mixedWeightsAvgHeartRate: value),
        ),
        (
          key: ActivityFieldKeys.mixedCardioAvgHeartRate,
          label: 'Battito medio fasi cardio',
          bpm: config.mixedCardioAvgHeartRate,
          change: (int value) =>
              config.copyWith(mixedCardioAvgHeartRate: value),
        ),
      ]) {
        addImpact(
          key: item.key,
          label: item.label,
          currentValue: item.bpm > 0 ? '${item.bpm} bpm' : 'Non indicato',
          note:
              'Correzione limitata applicata soltanto alla fase corrispondente.',
          scenarios: item.bpm > 0
              ? <ActivityImpactScenario>[
                  scenario(
                    '−10 bpm',
                    variant: item.change(
                      (item.bpm - 10).clamp(40, 220).toInt(),
                    ),
                  ),
                  scenario(
                    '+10 bpm',
                    variant: item.change(
                      (item.bpm + 10).clamp(40, 220).toInt(),
                    ),
                  ),
                ]
              : <ActivityImpactScenario>[
                  scenario('Se fosse 110 bpm', variant: item.change(110)),
                  scenario('Se fosse 140 bpm', variant: item.change(140)),
                ],
        );
      }
      _addCardioImpacts(
        impacts: impacts,
        config: config,
        scenario: scenario,
        includeDuration: false,
        includePause: false,
        includeHeartRate: false,
        includeIntervals: false,
      );
    }

    if (config.presetCode == ActivityPresetCodes.freeActivity) {
      addImpact(
        key: ActivityFieldKeys.freeDurationMinutes,
        label: 'Durata attività libera',
        currentValue: '${config.freeDurationMinutes} min',
        note: 'Scala il tempo a cui applicare il MET.',
        scenarios: <ActivityImpactScenario>[
          scenario(
            '−5 min',
            variant: config.copyWith(
              freeDurationMinutes:
                  (config.freeDurationMinutes - 5).clamp(0, 300).toInt(),
            ),
          ),
          scenario(
            '+5 min',
            variant: config.copyWith(
              freeDurationMinutes:
                  (config.freeDurationMinutes + 5).clamp(0, 300).toInt(),
            ),
          ),
        ],
      );
      addImpact(
        key: ActivityFieldKeys.freePauseMinutes,
        label: 'Pause attività libera',
        currentValue: '${config.freePauseMinutes} min',
        note: 'Sposta minuti dalla fase attiva alla pausa a 1,45 MET lordi.',
        scenarios: <ActivityImpactScenario>[
          scenario(
            '−5 min',
            variant: config.copyWith(
              freePauseMinutes:
                  (config.freePauseMinutes - 5).clamp(0, 240).toInt(),
            ),
          ),
          scenario(
            '+5 min',
            variant: config.copyWith(
              freePauseMinutes:
                  (config.freePauseMinutes + 5).clamp(0, 240).toInt(),
            ),
          ),
        ],
      );
      addImpact(
        key: ActivityFieldKeys.freeIntensityCode,
        label: 'Intensità attività libera',
        currentValue: _intensityLabel(config.freeIntensityCode),
        note: 'Seleziona il MET fallback dell’attività generica.',
        scenarios: <ActivityImpactScenario>[
          for (final String code in ActivityIntensityCodes.values)
            if (code != config.freeIntensityCode)
              scenario(
                _intensityLabel(code),
                variant: config.copyWith(freeIntensityCode: code),
              ),
        ],
      );
      addImpact(
        key: ActivityFieldKeys.freeAvgHeartRate,
        label: 'Battito medio attività libera',
        currentValue: config.freeAvgHeartRate > 0
            ? '${config.freeAvgHeartRate} bpm'
            : 'Non indicato',
        note: 'Correzione limitata sul segmento attivo.',
        scenarios: config.freeAvgHeartRate > 0
            ? <ActivityImpactScenario>[
                scenario(
                  '−10 bpm',
                  variant: config.copyWith(
                    freeAvgHeartRate:
                        (config.freeAvgHeartRate - 10).clamp(40, 220).toInt(),
                  ),
                ),
                scenario(
                  '+10 bpm',
                  variant: config.copyWith(
                    freeAvgHeartRate:
                        (config.freeAvgHeartRate + 10).clamp(40, 220).toInt(),
                  ),
                ),
              ]
            : <ActivityImpactScenario>[
                scenario(
                  'Se fosse 110 bpm',
                  variant: config.copyWith(freeAvgHeartRate: 110),
                ),
                scenario(
                  'Se fosse 140 bpm',
                  variant: config.copyWith(freeAvgHeartRate: 140),
                ),
              ],
      );
    }

    return List<ActivityParameterImpact>.unmodifiable(impacts);
  }

  static void _addCardioImpacts({
    required List<ActivityParameterImpact> impacts,
    required ProfileActivityConfig config,
    required ActivityImpactScenario Function(
      String label, {
      ProfileActivityConfig? variant,
      double? variantWeight,
    }) scenario,
    bool includeDuration = true,
    bool includePause = true,
    bool includeHeartRate = true,
    bool includeIntervals = false,
  }) {
    void add(ActivityParameterImpact impact) => impacts.add(impact);

    if (includeDuration) {
      add(
        ActivityParameterImpact(
          key: ActivityFieldKeys.cardioDurationMinutes,
          label: 'Durata cardio',
          currentValue: '${config.cardioDurationMinutes} min',
          note: 'Scala il tempo cardio dopo la sottrazione delle pause.',
          scenarios: <ActivityImpactScenario>[
            scenario(
              '−5 min',
              variant: config.copyWith(
                cardioDurationMinutes:
                    (config.cardioDurationMinutes - 5).clamp(0, 300).toInt(),
              ),
            ),
            scenario(
              '+5 min',
              variant: config.copyWith(
                cardioDurationMinutes:
                    (config.cardioDurationMinutes + 5).clamp(0, 300).toInt(),
              ),
            ),
          ],
        ),
      );
    }
    if (includePause) {
      add(
        ActivityParameterImpact(
          key: ActivityFieldKeys.cardioPauseMinutes,
          label: 'Pause cardio',
          currentValue: '${config.cardioPauseMinutes} min',
          note: 'Sposta minuti dal cardio alla pausa a 1,45 MET lordi.',
          scenarios: <ActivityImpactScenario>[
            scenario(
              '−5 min',
              variant: config.copyWith(
                cardioPauseMinutes:
                    (config.cardioPauseMinutes - 5).clamp(0, 240).toInt(),
              ),
            ),
            scenario(
              '+5 min',
              variant: config.copyWith(
                cardioPauseMinutes:
                    (config.cardioPauseMinutes + 5).clamp(0, 240).toInt(),
              ),
            ),
          ],
        ),
      );
    }
    add(
      ActivityParameterImpact(
        key: ActivityFieldKeys.cardioMachineCode,
        label: 'Tipo cardio / macchinario',
        currentValue: _machineLabel(config.cardioMachineCode),
        note:
            'Cambia il MET fallback; velocità/pendenza o watt prevalgono quando disponibili.',
        scenarios: <ActivityImpactScenario>[
          for (final String code in CardioMachineCodes.values)
            if (code != config.cardioMachineCode)
              scenario(
                _machineLabel(code),
                variant: config.copyWith(cardioMachineCode: code),
              ),
        ],
      ),
    );
    add(
      ActivityParameterImpact(
        key: ActivityFieldKeys.cardioIntensityCode,
        label: 'Intensità cardio',
        currentValue: _intensityLabel(config.cardioIntensityCode),
        note:
            'Modifica il MET fallback quando non sono disponibili dati macchina completi.',
        scenarios: <ActivityImpactScenario>[
          for (final String code in ActivityIntensityCodes.values)
            if (code != config.cardioIntensityCode)
              scenario(
                _intensityLabel(code),
                variant: config.copyWith(cardioIntensityCode: code),
              ),
        ],
      ),
    );
    if (includeHeartRate) {
      add(
        ActivityParameterImpact(
          key: ActivityFieldKeys.cardioAvgHeartRate,
          label: 'Battito medio cardio',
          currentValue: config.cardioAvgHeartRate > 0
              ? '${config.cardioAvgHeartRate} bpm'
              : 'Non indicato',
          note: 'Correzione limitata, a fasce, sulla componente cardio.',
          scenarios: config.cardioAvgHeartRate > 0
              ? <ActivityImpactScenario>[
                  scenario(
                    '−10 bpm',
                    variant: config.copyWith(
                      cardioAvgHeartRate: (config.cardioAvgHeartRate - 10)
                          .clamp(40, 220)
                          .toInt(),
                    ),
                  ),
                  scenario(
                    '+10 bpm',
                    variant: config.copyWith(
                      cardioAvgHeartRate: (config.cardioAvgHeartRate + 10)
                          .clamp(40, 220)
                          .toInt(),
                    ),
                  ),
                ]
              : <ActivityImpactScenario>[
                  scenario(
                    'Se fosse 110 bpm',
                    variant: config.copyWith(cardioAvgHeartRate: 110),
                  ),
                  scenario(
                    'Se fosse 140 bpm',
                    variant: config.copyWith(cardioAvgHeartRate: 140),
                  ),
                ],
        ),
      );
    }
    add(
      ActivityParameterImpact(
        key: ActivityFieldKeys.cardioSpeedKmh,
        label: 'Velocità cardio',
        currentValue: config.cardioSpeedKmh > 0
            ? '${config.cardioSpeedKmh.toStringAsFixed(1)} km/h'
            : 'Non indicata',
        note:
            'Usata direttamente nel tapis roulant; negli altri macchinari resta memorizzata ma non incide.',
        scenarios: <ActivityImpactScenario>[
          scenario(
            config.cardioSpeedKmh > 0 ? '−0,5 km/h' : 'Se fosse 5,0 km/h',
            variant: config.copyWith(
              cardioSpeedKmh: config.cardioSpeedKmh > 0
                  ? (config.cardioSpeedKmh - 0.5).clamp(0, 30).toDouble()
                  : 5,
            ),
          ),
          scenario(
            config.cardioSpeedKmh > 0 ? '+0,5 km/h' : 'Se fosse 8,0 km/h',
            variant: config.copyWith(
              cardioSpeedKmh: config.cardioSpeedKmh > 0
                  ? (config.cardioSpeedKmh + 0.5).clamp(0, 30).toDouble()
                  : 8,
            ),
          ),
        ],
      ),
    );
    add(
      ActivityParameterImpact(
        key: ActivityFieldKeys.cardioInclinePercent,
        label: 'Pendenza tapis roulant',
        currentValue: config.cardioInclinePercent > 0
            ? '${config.cardioInclinePercent.toStringAsFixed(1)}%'
            : 'Non indicata',
        note:
            'Incide solo sul tapis roulant quando è presente anche la velocità.',
        scenarios: <ActivityImpactScenario>[
          scenario(
            config.cardioInclinePercent > 0 ? '−1 punto %' : 'Se fosse 5%',
            variant: config.copyWith(
              cardioInclinePercent: config.cardioInclinePercent > 0
                  ? (config.cardioInclinePercent - 1).clamp(0, 30).toDouble()
                  : 5,
            ),
          ),
          scenario(
            config.cardioInclinePercent > 0 ? '+1 punto %' : 'Se fosse 10%',
            variant: config.copyWith(
              cardioInclinePercent: config.cardioInclinePercent > 0
                  ? (config.cardioInclinePercent + 1).clamp(0, 30).toDouble()
                  : 10,
            ),
          ),
        ],
      ),
    );
    add(
      ActivityParameterImpact(
        key: ActivityFieldKeys.cardioWatts,
        label: 'Potenza cardio',
        currentValue:
            config.cardioWatts > 0 ? '${config.cardioWatts} W' : 'Non indicata',
        note:
            'Usata per cyclette, ellittica e vogatore; prevale sul MET fallback.',
        scenarios: <ActivityImpactScenario>[
          scenario(
            config.cardioWatts > 0 ? '−10 W' : 'Se fossero 80 W',
            variant: config.copyWith(
              cardioWatts: config.cardioWatts > 0
                  ? (config.cardioWatts - 10).clamp(0, 1500).toInt()
                  : 80,
            ),
          ),
          scenario(
            config.cardioWatts > 0 ? '+10 W' : 'Se fossero 120 W',
            variant: config.copyWith(
              cardioWatts: config.cardioWatts > 0
                  ? (config.cardioWatts + 10).clamp(0, 1500).toInt()
                  : 120,
            ),
          ),
        ],
      ),
    );

    if (includeIntervals) {
      add(
        ActivityParameterImpact(
          key: ActivityFieldKeys.intervalCount,
          label: 'Numero intervalli',
          currentValue: '${config.intervalCount}',
          note:
              'Aumenta lavoro e recupero finché la durata disponibile non è satura.',
          scenarios: <ActivityImpactScenario>[
            scenario(
              '−1 intervallo',
              variant: config.copyWith(
                intervalCount: (config.intervalCount - 1).clamp(1, 80).toInt(),
              ),
            ),
            scenario(
              '+1 intervallo',
              variant: config.copyWith(
                intervalCount: (config.intervalCount + 1).clamp(1, 80).toInt(),
              ),
            ),
          ],
        ),
      );
      add(
        ActivityParameterImpact(
          key: ActivityFieldKeys.activeIntervalSeconds,
          label: 'Durata intervallo attivo',
          currentValue: '${config.activeIntervalSeconds} s',
          note: 'Sposta tempo verso il MET cardio più elevato.',
          scenarios: <ActivityImpactScenario>[
            scenario(
              '−15 s',
              variant: config.copyWith(
                activeIntervalSeconds:
                    (config.activeIntervalSeconds - 15).clamp(10, 900).toInt(),
              ),
            ),
            scenario(
              '+15 s',
              variant: config.copyWith(
                activeIntervalSeconds:
                    (config.activeIntervalSeconds + 15).clamp(10, 900).toInt(),
              ),
            ),
          ],
        ),
      );
      add(
        ActivityParameterImpact(
          key: ActivityFieldKeys.recoveryIntervalSeconds,
          label: 'Durata recupero intervallo',
          currentValue: '${config.recoveryIntervalSeconds} s',
          note:
              'Sposta tempo dal cardio residuo al recupero a intensità ridotta.',
          scenarios: <ActivityImpactScenario>[
            scenario(
              '−15 s',
              variant: config.copyWith(
                recoveryIntervalSeconds: (config.recoveryIntervalSeconds - 15)
                    .clamp(10, 900)
                    .toInt(),
              ),
            ),
            scenario(
              '+15 s',
              variant: config.copyWith(
                recoveryIntervalSeconds: (config.recoveryIntervalSeconds + 15)
                    .clamp(10, 900)
                    .toInt(),
              ),
            ),
          ],
        ),
      );
    }
  }

  static List<ActivityParameterAudit> _buildRawParameterAudits({
    required ProfileActivityConfig config,
    required double rawWeightKg,
    required double safeWeightKg,
  }) {
    final Set<String> used = _usedKeys(config.presetCode);
    final List<ActivityParameterAudit> result = <ActivityParameterAudit>[
      ActivityParameterAudit(
        key: 'profileWeightKg',
        section: 'Profilo e frequenza',
        label: 'Peso corporeo',
        rawValue: '${rawWeightKg.toStringAsFixed(1)} kg',
        usedValue: '${safeWeightKg.toStringAsFixed(1)} kg',
        sourceCode: ActivityInputSourceCodes.profile,
        usedInEstimate: true,
        role: 'Scala tutte le calorie MET della sessione.',
        formula: 'MET netto × peso × ore',
        effect: 'Quasi lineare: +1 kg aumenta ogni segmento di circa 1/peso.',
      ),
    ];

    for (final String key in ActivityFieldKeys.all) {
      final ({String section, String label, String role, String formula}) meta =
          _parameterMeta(key);
      result.add(
        ActivityParameterAudit(
          key: key,
          section: meta.section,
          label: meta.label,
          rawValue: _rawValue(config, key),
          usedValue: _usedValue(config, key),
          sourceCode: config.sourceFor(key),
          usedInEstimate: used.contains(key),
          role: meta.role,
          formula: meta.formula,
          effect: used.contains(key)
              ? _parameterEffect(key)
              : 'Nessun effetto con il preset corrente; il valore resta memorizzato per altri preset.',
        ),
      );
    }
    return result;
  }

  static Set<String> _usedKeys(String preset) {
    final Set<String> common = <String>{
      ActivityFieldKeys.presetCode,
      ActivityFieldKeys.sessionsPerWeek,
    };
    final Set<String> weights = <String>{
      ActivityFieldKeys.weightsDurationMinutes,
      ActivityFieldKeys.weightSets,
      ActivityFieldKeys.restSeconds,
      ActivityFieldKeys.setDurationSeconds,
      ActivityFieldKeys.averageRir,
      ActivityFieldKeys.weightsAvgHeartRate,
      ActivityFieldKeys.inactiveMinutes,
      ActivityFieldKeys.weightsOrganizationCode,
    };
    final Set<String> cardio = <String>{
      ActivityFieldKeys.cardioDurationMinutes,
      ActivityFieldKeys.cardioMachineCode,
      ActivityFieldKeys.cardioIntensityCode,
      ActivityFieldKeys.cardioAvgHeartRate,
      ActivityFieldKeys.cardioPauseMinutes,
      ActivityFieldKeys.cardioSpeedKmh,
      ActivityFieldKeys.cardioInclinePercent,
      ActivityFieldKeys.cardioWatts,
    };
    if (preset == ActivityPresetCodes.weights) {
      return <String>{...common, ...weights};
    }
    if (preset == ActivityPresetCodes.cardioContinuous) {
      return <String>{...common, ...cardio};
    }
    if (preset == ActivityPresetCodes.cardioIntervals) {
      return <String>{
        ...common,
        ...cardio,
        ActivityFieldKeys.intervalCount,
        ActivityFieldKeys.activeIntervalSeconds,
        ActivityFieldKeys.recoveryIntervalSeconds,
      };
    }
    if (preset == ActivityPresetCodes.weightsCardio) {
      return <String>{...common, ...weights, ...cardio};
    }
    if (preset == ActivityPresetCodes.mixedCircuit) {
      return <String>{
        ...common,
        ActivityFieldKeys.averageRir,
        ActivityFieldKeys.weightsOrganizationCode,
        ActivityFieldKeys.cardioMachineCode,
        ActivityFieldKeys.cardioIntensityCode,
        ActivityFieldKeys.cardioSpeedKmh,
        ActivityFieldKeys.cardioInclinePercent,
        ActivityFieldKeys.cardioWatts,
        ActivityFieldKeys.mixedDurationMinutes,
        ActivityFieldKeys.mixedRounds,
        ActivityFieldKeys.mixedWeightPhaseSeconds,
        ActivityFieldKeys.mixedCardioPhaseSeconds,
        ActivityFieldKeys.mixedRestSeconds,
        ActivityFieldKeys.mixedWeightsAvgHeartRate,
        ActivityFieldKeys.mixedCardioAvgHeartRate,
      };
    }
    return <String>{
      ...common,
      ActivityFieldKeys.freeDurationMinutes,
      ActivityFieldKeys.freePauseMinutes,
      ActivityFieldKeys.freeAvgHeartRate,
      ActivityFieldKeys.freeIntensityCode,
    };
  }

  static ({String section, String label, String role, String formula})
      _parameterMeta(String key) => switch (key) {
            ActivityFieldKeys.presetCode => (
                section: 'Profilo e frequenza',
                label: 'Tipo di sessione',
                role: 'Seleziona segmenti e formule attive.',
                formula: 'Scelta del ramo del modello',
              ),
            ActivityFieldKeys.sessionsPerWeek => (
                section: 'Profilo e frequenza',
                label: 'Sessioni settimanali',
                role: 'Converte la sessione in media giornaliera.',
                formula: 'sessione × frequenza ÷ 7',
              ),
            ActivityFieldKeys.weightsDurationMinutes => (
                section: 'Pesi',
                label: 'Durata blocco pesi',
                role: 'Tetto temporale di serie, recuperi e transizioni.',
                formula: 'durata − inattività',
              ),
            ActivityFieldKeys.weightSets => (
                section: 'Pesi',
                label: 'Serie per sessione',
                role: 'Determina lavoro e numero di recuperi.',
                formula: 'serie × durata; (serie − 1) × recupero',
              ),
            ActivityFieldKeys.restSeconds => (
                section: 'Pesi',
                label: 'Recupero medio',
                role: 'Tempo a intensità bassa tra le serie.',
                formula: '(serie − 1) × secondi ÷ 60',
              ),
            ActivityFieldKeys.setDurationSeconds => (
                section: 'Pesi',
                label: 'Durata media serie',
                role: 'Tempo effettivo sotto carico.',
                formula: 'serie × secondi ÷ 60',
              ),
            ActivityFieldKeys.averageRir => (
                section: 'Pesi',
                label: 'RIR medio',
                role: 'Determina il MET base delle serie.',
                formula: 'fascia RIR → MET lordo',
              ),
            ActivityFieldKeys.weightsAvgHeartRate => (
                section: 'Pesi',
                label: 'Battito medio pesi',
                role: 'Correzione limitata di plausibilità.',
                formula: 'fascia bpm → fattore 0,94–1,10',
              ),
            ActivityFieldKeys.inactiveMinutes => (
                section: 'Pesi',
                label: 'Minuti inattivi',
                role: 'Tempo escluso completamente.',
                formula: 'durata − minuti inattivi',
              ),
            ActivityFieldKeys.weightsOrganizationCode => (
                section: 'Pesi',
                label: 'Organizzazione serie',
                role: 'Modifica densità e MET delle serie.',
                formula:
                    'tradizionale +0; superserie +0,7; giant set +1,1; circuito +1,4',
              ),
            ActivityFieldKeys.cardioDurationMinutes => (
                section: 'Cardio',
                label: 'Durata cardio',
                role: 'Tetto temporale del blocco cardio.',
                formula: 'durata − pause',
              ),
            ActivityFieldKeys.cardioMachineCode => (
                section: 'Cardio',
                label: 'Macchinario / attività',
                role: 'Seleziona fallback MET o formula macchina.',
                formula: 'tipo + dati macchina',
              ),
            ActivityFieldKeys.cardioIntensityCode => (
                section: 'Cardio',
                label: 'Intensità cardio',
                role: 'Seleziona il MET fallback.',
                formula: 'leggera / moderata / elevata',
              ),
            ActivityFieldKeys.cardioAvgHeartRate => (
                section: 'Cardio',
                label: 'Battito medio cardio',
                role: 'Correzione limitata di plausibilità.',
                formula: 'fascia bpm → fattore 0,94–1,10',
              ),
            ActivityFieldKeys.cardioPauseMinutes => (
                section: 'Cardio',
                label: 'Pause cardio',
                role: 'Tempo separato dal lavoro cardio.',
                formula: 'durata − pause',
              ),
            ActivityFieldKeys.cardioSpeedKmh => (
                section: 'Cardio',
                label: 'Velocità',
                role: 'Input metabolico del tapis roulant.',
                formula: 'km/h → m/min → VO₂',
              ),
            ActivityFieldKeys.cardioInclinePercent => (
                section: 'Cardio',
                label: 'Pendenza',
                role: 'Aumenta la componente verticale del tapis roulant.',
                formula: 'velocità × pendenza → VO₂',
              ),
            ActivityFieldKeys.cardioWatts => (
                section: 'Cardio',
                label: 'Potenza media',
                role: 'Input per cyclette, ellittica e vogatore.',
                formula: '10,8 × watt ÷ peso + 7 → VO₂',
              ),
            ActivityFieldKeys.intervalCount => (
                section: 'Cardio intervallato',
                label: 'Numero intervalli',
                role: 'Ripete lavoro e recupero.',
                formula: 'numero × durata fase',
              ),
            ActivityFieldKeys.activeIntervalSeconds => (
                section: 'Cardio intervallato',
                label: 'Secondi intervallo attivo',
                role: 'Tempo al MET cardio aumentato.',
                formula: 'intervalli × secondi ÷ 60',
              ),
            ActivityFieldKeys.recoveryIntervalSeconds => (
                section: 'Cardio intervallato',
                label: 'Secondi recupero intervallo',
                role: 'Tempo a intensità ridotta.',
                formula: 'intervalli × secondi ÷ 60',
              ),
            ActivityFieldKeys.mixedDurationMinutes => (
                section: 'Circuito misto',
                label: 'Durata totale circuito',
                role: 'Tetto temporale di tutti i round.',
                formula: 'ridimensionamento se fasi > durata',
              ),
            ActivityFieldKeys.mixedRounds => (
                section: 'Circuito misto',
                label: 'Numero round',
                role: 'Moltiplica tutte le fasi.',
                formula: 'round × secondi fase',
              ),
            ActivityFieldKeys.mixedWeightPhaseSeconds => (
                section: 'Circuito misto',
                label: 'Fase pesi per round',
                role: 'Tempo pesi integrato.',
                formula: 'round × secondi ÷ 60',
              ),
            ActivityFieldKeys.mixedCardioPhaseSeconds => (
                section: 'Circuito misto',
                label: 'Fase cardio per round',
                role: 'Tempo cardio integrato.',
                formula: 'round × secondi ÷ 60',
              ),
            ActivityFieldKeys.mixedRestSeconds => (
                section: 'Circuito misto',
                label: 'Recupero per round',
                role: 'Tempo a intensità ridotta.',
                formula: 'round × secondi ÷ 60',
              ),
            ActivityFieldKeys.mixedWeightsAvgHeartRate => (
                section: 'Circuito misto',
                label: 'Battito medio fasi pesi',
                role: 'Correzione limitata della fase pesi.',
                formula: 'fascia bpm → fattore 0,94–1,10',
              ),
            ActivityFieldKeys.mixedCardioAvgHeartRate => (
                section: 'Circuito misto',
                label: 'Battito medio fasi cardio',
                role: 'Correzione limitata della fase aerobica.',
                formula: 'fascia bpm → fattore 0,94–1,10',
              ),
            ActivityFieldKeys.freeDurationMinutes => (
                section: 'Attività libera',
                label: 'Durata attività',
                role: 'Tempo totale prima delle pause.',
                formula: 'durata − pause',
              ),
            ActivityFieldKeys.freePauseMinutes => (
                section: 'Attività libera',
                label: 'Pause attività',
                role: 'Tempo separato dal lavoro.',
                formula: 'durata − pause',
              ),
            ActivityFieldKeys.freeAvgHeartRate => (
                section: 'Attività libera',
                label: 'Battito medio attività',
                role: 'Correzione limitata.',
                formula: 'fascia bpm → fattore 0,94–1,10',
              ),
            ActivityFieldKeys.freeIntensityCode => (
                section: 'Attività libera',
                label: 'Intensità attività',
                role: 'Seleziona il MET generico.',
                formula: 'leggera 3,5; moderata 5,5; elevata 8,5 MET lordi',
              ),
            _ => (
                section: 'Altro',
                label: key,
                role: 'Parametro del modello.',
                formula: '—',
              ),
          };

  static String _parameterEffect(String key) => switch (key) {
        ActivityFieldKeys.presetCode =>
          'Cambia completamente i segmenti attivi.',
        ActivityFieldKeys.sessionsPerWeek =>
          'Scala linearmente settimana e media giornaliera.',
        ActivityFieldKeys.weightsDurationMinutes =>
          'Modifica soprattutto le transizioni disponibili.',
        ActivityFieldKeys.weightSets =>
          'Aumenta lavoro e recuperi entro la durata.',
        ActivityFieldKeys.restSeconds =>
          'Sposta tempo verso un segmento a MET più basso.',
        ActivityFieldKeys.setDurationSeconds =>
          'Sposta tempo verso le serie ad alto MET.',
        ActivityFieldKeys.averageRir => 'Modifica il MET delle serie.',
        ActivityFieldKeys.weightsAvgHeartRate ||
        ActivityFieldKeys.cardioAvgHeartRate ||
        ActivityFieldKeys.mixedWeightsAvgHeartRate ||
        ActivityFieldKeys.mixedCardioAvgHeartRate ||
        ActivityFieldKeys.freeAvgHeartRate =>
          'Applica un fattore limitato 0,94–1,10.',
        ActivityFieldKeys.inactiveMinutes => 'Rimuove minuti dal calcolo.',
        ActivityFieldKeys.weightsOrganizationCode =>
          'Aggiunge 0–1,4 MET lordi alle serie.',
        ActivityFieldKeys.cardioDurationMinutes ||
        ActivityFieldKeys.freeDurationMinutes ||
        ActivityFieldKeys.mixedDurationMinutes =>
          'Modifica il tempo disponibile.',
        ActivityFieldKeys.cardioMachineCode =>
          'Seleziona formula o MET fallback.',
        ActivityFieldKeys.cardioIntensityCode ||
        ActivityFieldKeys.freeIntensityCode =>
          'Seleziona il MET fallback.',
        ActivityFieldKeys.cardioPauseMinutes ||
        ActivityFieldKeys.freePauseMinutes =>
          'Sposta minuti in una pausa a MET quasi nullo.',
        ActivityFieldKeys.cardioSpeedKmh =>
          'Nel tapis aumenta la componente orizzontale del VO₂.',
        ActivityFieldKeys.cardioInclinePercent =>
          'Nel tapis aumenta la componente verticale del VO₂.',
        ActivityFieldKeys.cardioWatts =>
          'Converte potenza e peso in VO₂ e MET.',
        ActivityFieldKeys.intervalCount => 'Ripete fasi attive e recuperi.',
        ActivityFieldKeys.activeIntervalSeconds =>
          'Aumenta il tempo al MET più alto.',
        ActivityFieldKeys.recoveryIntervalSeconds =>
          'Aumenta il tempo a intensità ridotta.',
        ActivityFieldKeys.mixedRounds =>
          'Moltiplica le fasi fino al limite di durata.',
        ActivityFieldKeys.mixedWeightPhaseSeconds => 'Aumenta la quota pesi.',
        ActivityFieldKeys.mixedCardioPhaseSeconds => 'Aumenta la quota cardio.',
        ActivityFieldKeys.mixedRestSeconds => 'Aumenta la quota recupero.',
        _ => 'Partecipa al ramo selezionato del modello.',
      };

  static String _rawValue(ProfileActivityConfig c, String key) => switch (key) {
        ActivityFieldKeys.presetCode => _presetLabel(c.presetCode),
        ActivityFieldKeys.sessionsPerWeek =>
          '${c.sessionsPerWeek.toStringAsFixed(2)} / settimana',
        ActivityFieldKeys.weightsDurationMinutes =>
          '${c.weightsDurationMinutes} min',
        ActivityFieldKeys.weightSets => '${c.weightSets}',
        ActivityFieldKeys.restSeconds => '${c.restSeconds} s',
        ActivityFieldKeys.setDurationSeconds => '${c.setDurationSeconds} s',
        ActivityFieldKeys.averageRir => '${c.averageRir}',
        ActivityFieldKeys.weightsAvgHeartRate => _rawHeartRate(
            c.weightsAvgHeartRate,
          ),
        ActivityFieldKeys.inactiveMinutes => '${c.inactiveMinutes} min',
        ActivityFieldKeys.weightsOrganizationCode => _organizationLabel(
            c.weightsOrganizationCode,
          ),
        ActivityFieldKeys.cardioDurationMinutes =>
          '${c.cardioDurationMinutes} min',
        ActivityFieldKeys.cardioMachineCode =>
          _machineLabel(c.cardioMachineCode),
        ActivityFieldKeys.cardioIntensityCode => _intensityLabel(
            c.cardioIntensityCode,
          ),
        ActivityFieldKeys.cardioAvgHeartRate =>
          _rawHeartRate(c.cardioAvgHeartRate),
        ActivityFieldKeys.cardioPauseMinutes => '${c.cardioPauseMinutes} min',
        ActivityFieldKeys.cardioSpeedKmh =>
          '${c.cardioSpeedKmh.toStringAsFixed(2)} km/h',
        ActivityFieldKeys.cardioInclinePercent =>
          '${c.cardioInclinePercent.toStringAsFixed(2)}%',
        ActivityFieldKeys.cardioWatts => '${c.cardioWatts} W',
        ActivityFieldKeys.intervalCount => '${c.intervalCount}',
        ActivityFieldKeys.activeIntervalSeconds =>
          '${c.activeIntervalSeconds} s',
        ActivityFieldKeys.recoveryIntervalSeconds =>
          '${c.recoveryIntervalSeconds} s',
        ActivityFieldKeys.mixedDurationMinutes =>
          '${c.mixedDurationMinutes} min',
        ActivityFieldKeys.mixedRounds => '${c.mixedRounds}',
        ActivityFieldKeys.mixedWeightPhaseSeconds =>
          '${c.mixedWeightPhaseSeconds} s',
        ActivityFieldKeys.mixedCardioPhaseSeconds =>
          '${c.mixedCardioPhaseSeconds} s',
        ActivityFieldKeys.mixedRestSeconds => '${c.mixedRestSeconds} s',
        ActivityFieldKeys.mixedWeightsAvgHeartRate => _rawHeartRate(
            c.mixedWeightsAvgHeartRate,
          ),
        ActivityFieldKeys.mixedCardioAvgHeartRate => _rawHeartRate(
            c.mixedCardioAvgHeartRate,
          ),
        ActivityFieldKeys.freeDurationMinutes => '${c.freeDurationMinutes} min',
        ActivityFieldKeys.freePauseMinutes => '${c.freePauseMinutes} min',
        ActivityFieldKeys.freeAvgHeartRate => _rawHeartRate(c.freeAvgHeartRate),
        ActivityFieldKeys.freeIntensityCode =>
          _intensityLabel(c.freeIntensityCode),
        _ => '—',
      };

  static String _usedValue(
    ProfileActivityConfig c,
    String key,
  ) =>
      switch (key) {
        ActivityFieldKeys.presetCode => _presetLabel(c.presetCode),
        ActivityFieldKeys.sessionsPerWeek =>
          '${c.sessionsPerWeek.clamp(0, 14).toDouble().toStringAsFixed(2)} / settimana',
        ActivityFieldKeys.weightsDurationMinutes =>
          '${c.weightsDurationMinutes.clamp(0, 300).toInt()} min',
        ActivityFieldKeys.weightSets => '${c.weightSets.clamp(0, 80).toInt()}',
        ActivityFieldKeys.restSeconds =>
          '${c.restSeconds.clamp(15, 600).toInt()} s',
        ActivityFieldKeys.setDurationSeconds =>
          '${c.setDurationSeconds.clamp(15, 120).toInt()} s',
        ActivityFieldKeys.averageRir =>
          _rirLabel(c.averageRir.clamp(0, 5).toInt()),
        ActivityFieldKeys.weightsAvgHeartRate => _usedHeartRate(
            c.weightsAvgHeartRate,
          ),
        ActivityFieldKeys.inactiveMinutes =>
          '${c.inactiveMinutes.clamp(0, 240).toInt()} min',
        ActivityFieldKeys.weightsOrganizationCode => _organizationLabel(
            c.weightsOrganizationCode,
          ),
        ActivityFieldKeys.cardioDurationMinutes =>
          '${c.cardioDurationMinutes.clamp(0, 300).toInt()} min',
        ActivityFieldKeys.cardioMachineCode =>
          _machineLabel(c.cardioMachineCode),
        ActivityFieldKeys.cardioIntensityCode => _intensityLabel(
            c.cardioIntensityCode,
          ),
        ActivityFieldKeys.cardioAvgHeartRate => _usedHeartRate(
            c.cardioAvgHeartRate,
          ),
        ActivityFieldKeys.cardioPauseMinutes =>
          '${c.cardioPauseMinutes.clamp(0, 240).toInt()} min',
        ActivityFieldKeys.cardioSpeedKmh => c.cardioSpeedKmh > 0
            ? '${c.cardioSpeedKmh.clamp(0, 30).toDouble().toStringAsFixed(2)} km/h'
            : 'Non indicata',
        ActivityFieldKeys.cardioInclinePercent =>
          '${c.cardioInclinePercent.clamp(0, 30).toDouble().toStringAsFixed(2)}%',
        ActivityFieldKeys.cardioWatts => c.cardioWatts > 0
            ? '${c.cardioWatts.clamp(0, 1500).toInt()} W'
            : 'Non indicati',
        ActivityFieldKeys.intervalCount =>
          '${c.intervalCount.clamp(1, 80).toInt()}',
        ActivityFieldKeys.activeIntervalSeconds =>
          '${c.activeIntervalSeconds.clamp(10, 900).toInt()} s',
        ActivityFieldKeys.recoveryIntervalSeconds =>
          '${c.recoveryIntervalSeconds.clamp(10, 900).toInt()} s',
        ActivityFieldKeys.mixedDurationMinutes =>
          '${c.mixedDurationMinutes.clamp(0, 300).toInt()} min',
        ActivityFieldKeys.mixedRounds =>
          '${c.mixedRounds.clamp(1, 60).toInt()}',
        ActivityFieldKeys.mixedWeightPhaseSeconds =>
          '${c.mixedWeightPhaseSeconds.clamp(10, 900).toInt()} s',
        ActivityFieldKeys.mixedCardioPhaseSeconds =>
          '${c.mixedCardioPhaseSeconds.clamp(10, 900).toInt()} s',
        ActivityFieldKeys.mixedRestSeconds =>
          '${c.mixedRestSeconds.clamp(0, 600).toInt()} s',
        ActivityFieldKeys.mixedWeightsAvgHeartRate => _usedHeartRate(
            c.mixedWeightsAvgHeartRate,
          ),
        ActivityFieldKeys.mixedCardioAvgHeartRate => _usedHeartRate(
            c.mixedCardioAvgHeartRate,
          ),
        ActivityFieldKeys.freeDurationMinutes =>
          '${c.freeDurationMinutes.clamp(0, 300).toInt()} min',
        ActivityFieldKeys.freePauseMinutes =>
          '${c.freePauseMinutes.clamp(0, 240).toInt()} min',
        ActivityFieldKeys.freeAvgHeartRate =>
          _usedHeartRate(c.freeAvgHeartRate),
        ActivityFieldKeys.freeIntensityCode =>
          _intensityLabel(c.freeIntensityCode),
        _ => '—',
      };

  static String _rawHeartRate(int bpm) => bpm > 0 ? '$bpm bpm' : 'Non indicato';

  static String _usedHeartRate(int bpm) => bpm > 0
      ? '${bpm.clamp(40, 220).toInt()} bpm'
      : 'Non indicato; fattore 1,000';

  static String _cardioFormulaDescription(
    ProfileActivityConfig config,
    double weightKg,
  ) {
    if (config.cardioMachineCode == CardioMachineCodes.treadmill &&
        config.cardioSpeedKmh > 0) {
      return config.cardioSpeedKmh >= 8
          ? 'Corsa: VO₂ = 0,2×velocità + 0,9×velocità×pendenza + 3,5; MET = VO₂÷3,5'
          : 'Cammino: VO₂ = 0,1×velocità + 1,8×velocità×pendenza + 3,5; MET = VO₂÷3,5';
    }
    if ((config.cardioMachineCode == CardioMachineCodes.bike ||
            config.cardioMachineCode == CardioMachineCodes.elliptical ||
            config.cardioMachineCode == CardioMachineCodes.rower) &&
        config.cardioWatts > 0) {
      return 'VO₂ = 10,8×${config.cardioWatts} W÷${weightKg.toStringAsFixed(1)} kg + 7; MET = VO₂÷3,5';
    }
    return 'Tabella MET per ${_machineLabel(config.cardioMachineCode)} e intensità ${_intensityLabel(config.cardioIntensityCode)}';
  }

  static String _presetLabel(String code) => switch (code) {
        ActivityPresetCodes.weights => 'Pesi',
        ActivityPresetCodes.cardioContinuous => 'Cardio continuo',
        ActivityPresetCodes.cardioIntervals => 'Cardio intervallato',
        ActivityPresetCodes.weightsCardio => 'Pesi + sessione cardio',
        ActivityPresetCodes.mixedCircuit => 'Misto · circuito integrato',
        ActivityPresetCodes.freeActivity => 'Sport o attività libera',
        _ => 'Attività',
      };

  static String _machineLabel(String code) => switch (code) {
        CardioMachineCodes.treadmill => 'Tapis roulant',
        CardioMachineCodes.bike => 'Cyclette',
        CardioMachineCodes.elliptical => 'Ellittica',
        CardioMachineCodes.rower => 'Vogatore',
        CardioMachineCodes.stairClimber => 'Stair climber',
        CardioMachineCodes.outdoorWalk => 'Camminata esterna',
        CardioMachineCodes.outdoorRun => 'Corsa esterna',
        _ => 'Cardio generico',
      };

  static String _intensityLabel(String code) => switch (code) {
        ActivityIntensityCodes.light => 'Leggera',
        ActivityIntensityCodes.vigorous => 'Elevata',
        _ => 'Moderata',
      };

  static String _organizationLabel(String code) => switch (code) {
        WeightOrganizationCodes.supersets => 'Superserie',
        WeightOrganizationCodes.giantSets => 'Giant set',
        WeightOrganizationCodes.circuit => 'Circuito',
        _ => 'Serie tradizionali',
      };

  static String _rirLabel(int rir) {
    if (rir >= 4) return 'RIR 4+ · lontano dal cedimento';
    if (rir >= 2) return 'RIR 2–3 · moderato';
    if (rir == 1) return 'RIR 0–1 · vicino al cedimento';
    return 'Cedimento frequente';
  }
}
