class WeightMeasurementSample {
  const WeightMeasurementSample({
    required this.identity,
    required this.dateKey,
    required this.weightKg,
  });

  final String identity;
  final String dateKey;
  final double? weightKg;
}

class WeightAnomalyEvaluation {
  const WeightAnomalyEvaluation({
    required this.isAnomalous,
    this.confirmationKey,
  });

  static const WeightAnomalyEvaluation none = WeightAnomalyEvaluation(
    isAnomalous: false,
  );

  final bool isAnomalous;
  final String? confirmationKey;
}

WeightAnomalyEvaluation evaluateWeightAnomaly({
  required String currentIdentity,
  required String currentDateKey,
  required double? currentWeightKg,
  required Iterable<WeightMeasurementSample> measurements,
  int lookbackDays = 3,
  double thresholdKg = 2,
}) {
  if (currentWeightKg == null || currentWeightKg <= 0) {
    return WeightAnomalyEvaluation.none;
  }
  final DateTime? currentDate = _parseDateKey(currentDateKey);
  if (currentDate == null) {
    return WeightAnomalyEvaluation.none;
  }

  final List<WeightMeasurementSample> anomalousPrevious = measurements.where(
    (WeightMeasurementSample sample) {
      if (sample.identity == currentIdentity ||
          sample.weightKg == null ||
          sample.weightKg! <= 0) {
        return false;
      }
      final DateTime? sampleDate = _parseDateKey(sample.dateKey);
      if (sampleDate == null || !sampleDate.isBefore(currentDate)) {
        return false;
      }
      final int distanceDays = currentDate.difference(sampleDate).inDays;
      if (distanceDays < 1 || distanceDays > lookbackDays) {
        return false;
      }
      return (currentWeightKg - sample.weightKg!).abs() > thresholdKg;
    },
  ).toList()
    ..sort((WeightMeasurementSample a, WeightMeasurementSample b) {
      final int dateComparison = a.dateKey.compareTo(b.dateKey);
      if (dateComparison != 0) {
        return dateComparison;
      }
      return a.identity.compareTo(b.identity);
    });

  if (anomalousPrevious.isEmpty) {
    return WeightAnomalyEvaluation.none;
  }

  final String evidence = anomalousPrevious
      .map(
        (WeightMeasurementSample sample) =>
            '${sample.identity}:${sample.dateKey}:${_weightKey(sample.weightKg!)}',
      )
      .join(';');
  final String confirmationKey =
      'v1|$currentIdentity|$currentDateKey|${_weightKey(currentWeightKg)}|$evidence';

  return WeightAnomalyEvaluation(
    isAnomalous: true,
    confirmationKey: confirmationKey,
  );
}

DateTime? _parseDateKey(String value) {
  final RegExpMatch? match =
      RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
  if (match == null) {
    return null;
  }
  final int? year = int.tryParse(match.group(1)!);
  final int? month = int.tryParse(match.group(2)!);
  final int? day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) {
    return null;
  }
  final DateTime parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

String _weightKey(double value) => value.toStringAsFixed(3);
