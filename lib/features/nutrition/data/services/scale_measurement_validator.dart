import '../entities/nutrition_tracking_entities.dart';

enum ScaleValidationSeverity { structuralError, qualityWarning, information }

class ScaleValidationIssue {
  const ScaleValidationIssue({
    required this.code,
    required this.message,
    required this.severity,
    this.field,
  });

  final String code;
  final String message;
  final ScaleValidationSeverity severity;
  final String? field;
}

class ScaleValidationResult {
  const ScaleValidationResult(this.issues);

  final List<ScaleValidationIssue> issues;

  bool get isValid => !issues.any(
        (issue) => issue.severity == ScaleValidationSeverity.structuralError,
      );

  bool get hasQualityWarnings => issues.any(
        (issue) => issue.severity == ScaleValidationSeverity.qualityWarning,
      );

  String get reliabilityCode => hasQualityWarnings ? 'low' : 'normal';
}

class ScaleMeasurementValidator {
  const ScaleMeasurementValidator(
      {this.futureTolerance = const Duration(days: 1)});

  final Duration futureTolerance;

  ScaleValidationResult validate(
    ScaleMeasurementEntity measurement, {
    DateTime? now,
  }) {
    final List<ScaleValidationIssue> issues = <ScaleValidationIssue>[];
    final DateTime referenceNow = now ?? DateTime.now();
    final DateTime? date = _parseDate(measurement.dateKey);
    if (date == null) {
      issues.add(
        const ScaleValidationIssue(
          code: 'invalid_date',
          message:
              'La data deve essere una data di calendario valida in formato YYYY-MM-DD.',
          severity: ScaleValidationSeverity.structuralError,
          field: 'dateKey',
        ),
      );
    } else {
      final DateTime latestAllowed = DateTime(
        referenceNow.year,
        referenceNow.month,
        referenceNow.day,
      ).add(futureTolerance);
      if (date.isAfter(latestAllowed)) {
        issues.add(
          const ScaleValidationIssue(
            code: 'future_date',
            message:
                'La misurazione è oltre la tolleranza ammessa per date future.',
            severity: ScaleValidationSeverity.structuralError,
            field: 'dateKey',
          ),
        );
      }
    }

    _requirePositiveFinite(
      issues,
      field: 'weightKg',
      value: measurement.weightKg,
      label: 'Peso',
    );
    _percentage(
      issues,
      field: 'bodyFatPercent',
      value: measurement.bodyFatPercent,
      label: 'Grasso corporeo',
    );
    _percentage(
      issues,
      field: 'waterPercent',
      value: measurement.waterPercent,
      label: 'Acqua corporea',
    );
    _percentage(
      issues,
      field: 'subcutaneousFatPercent',
      value: measurement.subcutaneousFatPercent,
      label: 'Grasso sottocutaneo',
    );
    _optionalPositiveFinite(
      issues,
      field: 'muscleMassKg',
      value: measurement.muscleMassKg,
      label: 'Massa muscolare',
    );
    _optionalPositiveFinite(
      issues,
      field: 'boneMassKg',
      value: measurement.boneMassKg,
      label: 'Massa ossea',
    );
    _optionalPositiveFinite(
      issues,
      field: 'visceralFat',
      value: measurement.visceralFat,
      label: 'Grasso viscerale',
    );
    _optionalPositiveFinite(
      issues,
      field: 'basalMetabolismKcal',
      value: measurement.basalMetabolismKcal,
      label: 'Metabolismo basale',
    );
    _optionalPositiveFinite(
      issues,
      field: 'bmi',
      value: measurement.bmi,
      label: 'BMI',
    );
    _optionalPositiveFinite(
      issues,
      field: 'metabolicAge',
      value: measurement.metabolicAge,
      label: 'Età metabolica',
    );

    final double? weight = measurement.weightKg;
    if (weight != null && weight.isFinite && (weight < 25 || weight > 350)) {
      issues.add(
        const ScaleValidationIssue(
          code: 'unusual_weight',
          message:
              'Il peso è strutturalmente valido ma fuori dall’intervallo qualitativo atteso.',
          severity: ScaleValidationSeverity.qualityWarning,
          field: 'weightKg',
        ),
      );
    }
    if (measurement.device.length > 512) {
      issues.add(
        const ScaleValidationIssue(
          code: 'device_too_long',
          message: 'L’identità del dispositivo supera il limite supportato.',
          severity: ScaleValidationSeverity.structuralError,
          field: 'device',
        ),
      );
    }
    if (measurement.notes.length > 8192) {
      issues.add(
        const ScaleValidationIssue(
          code: 'notes_too_long',
          message: 'Le note superano il limite supportato.',
          severity: ScaleValidationSeverity.structuralError,
          field: 'notes',
        ),
      );
    }

    return ScaleValidationResult(
        List<ScaleValidationIssue>.unmodifiable(issues));
  }

  void validateOrThrow(ScaleMeasurementEntity measurement, {DateTime? now}) {
    final ScaleValidationResult result = validate(measurement, now: now);
    if (!result.isValid) {
      final String message = result.issues
          .where(
            (issue) =>
                issue.severity == ScaleValidationSeverity.structuralError,
          )
          .map((issue) => '${issue.code}: ${issue.message}')
          .join('; ');
      throw FormatException(message);
    }
    measurement.reliabilityCode = result.reliabilityCode;
  }

  void _percentage(
    List<ScaleValidationIssue> issues, {
    required String field,
    required double? value,
    required String label,
  }) {
    if (value == null) return;
    if (!value.isFinite || value < 0 || value > 100) {
      issues.add(
        ScaleValidationIssue(
          code: 'invalid_percentage',
          message: '$label deve essere compreso tra 0 e 100.',
          severity: ScaleValidationSeverity.structuralError,
          field: field,
        ),
      );
    }
  }

  void _requirePositiveFinite(
    List<ScaleValidationIssue> issues, {
    required String field,
    required double? value,
    required String label,
  }) {
    if (value == null || !value.isFinite || value <= 0) {
      issues.add(
        ScaleValidationIssue(
          code: 'missing_or_invalid_positive_value',
          message: '$label deve essere presente, finito e maggiore di zero.',
          severity: ScaleValidationSeverity.structuralError,
          field: field,
        ),
      );
    }
  }

  void _optionalPositiveFinite(
    List<ScaleValidationIssue> issues, {
    required String field,
    required double? value,
    required String label,
  }) {
    if (value == null) return;
    if (!value.isFinite || value < 0) {
      issues.add(
        ScaleValidationIssue(
          code: 'invalid_optional_value',
          message: '$label deve essere finito e non negativo.',
          severity: ScaleValidationSeverity.structuralError,
          field: field,
        ),
      );
    }
  }

  DateTime? _parseDate(String dateKey) {
    final RegExpMatch? match =
        RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(dateKey.trim());
    if (match == null) return null;
    final int year = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int day = int.parse(match.group(3)!);
    final DateTime value = DateTime(year, month, day);
    if (value.year != year || value.month != month || value.day != day) {
      return null;
    }
    return value;
  }
}
