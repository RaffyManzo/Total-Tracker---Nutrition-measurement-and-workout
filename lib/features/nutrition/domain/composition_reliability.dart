import 'dart:math' as math;

class CompositionReliabilityBreakdown {
  const CompositionReliabilityBreakdown({
    required this.score,
    required this.minimumRequired,
    required this.dayFactor,
    required this.coverageFactor,
    required this.gapFactor,
    required this.waterFactor,
    required this.waterStatusCode,
    required this.deviceFactor,
    required this.dayContribution,
    required this.coverageContribution,
    required this.gapContribution,
    required this.waterContribution,
    required this.deviceContribution,
    required this.passed,
    required this.deviceStatusCode,
    required this.hardFailureReasonCode,
    required this.notes,
  });

  final double score;
  final double minimumRequired;
  final double dayFactor;
  final double coverageFactor;
  final double gapFactor;
  final double waterFactor;
  final String waterStatusCode;
  final double deviceFactor;
  final double dayContribution;
  final double coverageContribution;
  final double gapContribution;
  final double waterContribution;
  final double deviceContribution;
  final bool passed;
  final String deviceStatusCode;
  final String hardFailureReasonCode;
  final List<String> notes;

  Map<String, double> get factors => <String, double>{
        'days': dayFactor,
        'coverage': coverageFactor,
        'gap': gapFactor,
        'water': waterFactor,
        'device': deviceFactor,
      };

  Map<String, double> get contributions => <String, double>{
        'days': dayContribution,
        'coverage': coverageContribution,
        'gap': gapContribution,
        'water': waterContribution,
        'device': deviceContribution,
      };

  List<String> toDiagnosticNotes() {
    String value(String key, double input) =>
        'composition_reliability_$key=${input.toStringAsFixed(6)}';
    return <String>[
      value('score', score),
      value('minimum', minimumRequired),
      value('day_factor', dayFactor),
      value('coverage_factor', coverageFactor),
      value('gap_factor', gapFactor),
      value('water_factor', waterFactor),
      value('device_factor', deviceFactor),
      value('day_contribution', dayContribution),
      value('coverage_contribution', coverageContribution),
      value('gap_contribution', gapContribution),
      value('water_contribution', waterContribution),
      value('device_contribution', deviceContribution),
      'composition_reliability_water_status=$waterStatusCode',
      'composition_reliability_device_status=$deviceStatusCode',
      'composition_reliability_hard_failure=$hardFailureReasonCode',
      'composition_reliability_passed=$passed',
      ...notes,
    ];
  }
}

class CompositionReliabilityCalculator {
  const CompositionReliabilityCalculator._();

  static const double dayWeight = 0.30;
  static const double coverageWeight = 0.25;
  static const double gapWeight = 0.20;
  static const double waterWeight = 0.15;
  static const double deviceWeight = 0.10;

  static CompositionReliabilityBreakdown calculate({
    required int validDays,
    required int coverageDays,
    required int maximumGapDays,
    required double maximumWaterRangePercent,
    required Iterable<double?> waterPercentages,
    required Iterable<String> deviceCodes,
    required double minimumRequired,
  }) {
    final List<String> notes = <String>[];
    final List<double> waterValues = waterPercentages
        .whereType<double>()
        .where((double value) => value.isFinite && value >= 0 && value <= 100)
        .toList(growable: false);

    final double dayFactor = (validDays / 14).clamp(0, 1).toDouble();
    final double coverageFactor =
        (math.max(0, coverageDays) / 28).clamp(0, 1).toDouble();
    final double gapFactor = maximumGapDays <= 3
        ? 1
        : maximumGapDays <= 5
            ? 0.85
            : maximumGapDays <= 7
                ? 0.65
                : 0.45;

    final double safeMaximumWaterRange =
        maximumWaterRangePercent.isFinite && maximumWaterRangePercent >= 0
            ? maximumWaterRangePercent
            : 6;
    final double waterFactor;
    final String waterStatusCode;
    bool waterHardConflict = false;
    if (waterValues.isEmpty) {
      waterFactor = 0.65;
      waterStatusCode = 'water_missing';
      notes.add('composition_reliability_water_missing');
    } else if (waterValues.length < validDays ~/ 2) {
      waterFactor = 0.65;
      waterStatusCode = 'water_partially_missing';
      notes.add('composition_reliability_water_partially_missing');
    } else {
      final double waterRange =
          waterValues.reduce(math.max) - waterValues.reduce(math.min);
      waterFactor = waterRange <= 2
          ? 1
          : waterRange <= 4
              ? 0.8
              : 0.55;
      waterHardConflict = waterRange > safeMaximumWaterRange;
      waterStatusCode = waterHardConflict
          ? 'water_variation_too_large'
          : waterRange <= 2
              ? 'water_stable'
              : waterRange <= 4
                  ? 'water_moderate_variation'
                  : 'water_high_but_acceptable_variation';
      notes.add(
        'composition_reliability_water_range=${waterRange.toStringAsFixed(3)}',
      );
      notes.add(
        'composition_reliability_water_maximum=${safeMaximumWaterRange.toStringAsFixed(3)}',
      );
      if (waterHardConflict) {
        notes.add('composition_reliability_water_hard_conflict');
      }
    }

    final _DeviceAssessment device = _assessDevices(deviceCodes);
    notes.addAll(device.notes);
    final String hardFailureReasonCode = device.hardConflict
        ? 'device_changed'
        : waterHardConflict
            ? 'water_variation_too_large'
            : 'none';

    final double dayContribution = dayFactor * dayWeight;
    final double coverageContribution = coverageFactor * coverageWeight;
    final double gapContribution = gapFactor * gapWeight;
    final double waterContribution = waterFactor * waterWeight;
    final double deviceContribution = device.factor * deviceWeight;
    final double score = (dayContribution +
            coverageContribution +
            gapContribution +
            waterContribution +
            deviceContribution)
        .clamp(0, 1)
        .toDouble();

    return CompositionReliabilityBreakdown(
      score: score,
      minimumRequired: minimumRequired,
      dayFactor: dayFactor,
      coverageFactor: coverageFactor,
      gapFactor: gapFactor,
      waterFactor: waterFactor,
      waterStatusCode: waterStatusCode,
      deviceFactor: device.factor,
      dayContribution: dayContribution,
      coverageContribution: coverageContribution,
      gapContribution: gapContribution,
      waterContribution: waterContribution,
      deviceContribution: deviceContribution,
      passed: score >= minimumRequired && hardFailureReasonCode == 'none',
      deviceStatusCode: device.statusCode,
      hardFailureReasonCode: hardFailureReasonCode,
      notes: List<String>.unmodifiable(notes),
    );
  }

  static _DeviceAssessment _assessDevices(Iterable<String> rawCodes) {
    final Set<String> known = <String>{};
    bool hasUnspecified = false;
    bool hasMixed = false;

    for (final String raw in rawCodes) {
      final String canonical = canonicalDeviceCode(raw);
      if (canonical == 'unspecified') {
        hasUnspecified = true;
      } else if (canonical == 'mixed') {
        hasMixed = true;
      } else if (canonical.isNotEmpty) {
        known.add(canonical);
      }
    }

    if (hasMixed || known.length > 1) {
      return const _DeviceAssessment(
        factor: 0,
        hardConflict: true,
        statusCode: 'device_changed',
        notes: <String>['composition_reliability_device_conflict'],
      );
    }
    if (known.length == 1 && hasUnspecified) {
      return const _DeviceAssessment(
        factor: 0.85,
        hardConflict: false,
        statusCode: 'device_metadata_incomplete',
        notes: <String>['composition_reliability_device_partially_unspecified'],
      );
    }
    if (known.isEmpty) {
      return const _DeviceAssessment(
        factor: 0.65,
        hardConflict: false,
        statusCode: 'device_unspecified',
        notes: <String>['composition_reliability_device_unspecified'],
      );
    }
    return const _DeviceAssessment(
      factor: 1,
      hardConflict: false,
      statusCode: 'device_consistent',
      notes: <String>['composition_reliability_device_consistent'],
    );
  }

  static String canonicalDeviceCode(String raw) {
    String value = raw.trim().toLowerCase();
    if (value.isEmpty || value == 'unknown' || value == 'n/d') {
      return 'unspecified';
    }
    if (value.startsWith('ttdev:')) {
      final int separator = value.indexOf('::');
      return separator > 6 ? value.substring(0, separator) : value;
    }
    const Map<String, String> accents = <String, String>{
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
    };
    accents.forEach((String from, String to) {
      value = value.replaceAll(from, to);
    });
    value = value.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    value = value.replaceAll(RegExp(r'\s+'), ' ');
    return value.isEmpty ? 'unspecified' : value;
  }
}

class _DeviceAssessment {
  const _DeviceAssessment({
    required this.factor,
    required this.hardConflict,
    required this.statusCode,
    required this.notes,
  });

  final double factor;
  final bool hardConflict;
  final String statusCode;
  final List<String> notes;
}
