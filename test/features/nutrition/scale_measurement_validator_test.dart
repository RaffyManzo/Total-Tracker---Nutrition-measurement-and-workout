import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/entities/nutrition_tracking_entities.dart';
import 'package:total_tracker/features/nutrition/data/services/scale_measurement_validator.dart';

void main() {
  ScaleMeasurementEntity measurement({
    String date = '2026-07-08',
    double? weight = 64,
    double? bodyFat = 18,
  }) {
    return ScaleMeasurementEntity(
      uuid: 'test',
      dateKey: date,
      title: 'Test',
      weightKg: weight,
      bodyFatPercent: bodyFat,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 1,
    );
  }

  test('accepts a structurally valid measurement', () {
    final ScaleValidationResult result = const ScaleMeasurementValidator()
        .validate(measurement(), now: DateTime(2026, 7, 8));
    expect(result.isValid, isTrue);
    expect(result.reliabilityCode, 'normal');
  });

  test('rejects percentages outside zero to one hundred', () {
    final ScaleValidationResult result =
        const ScaleMeasurementValidator().validate(
      measurement(bodyFat: 101),
      now: DateTime(2026, 7, 8),
    );
    expect(result.isValid, isFalse);
    expect(
      result.issues.any((issue) => issue.code == 'invalid_percentage'),
      isTrue,
    );
  });

  test('rejects a date beyond the future tolerance', () {
    final ScaleValidationResult result =
        const ScaleMeasurementValidator().validate(
      measurement(date: '2026-07-11'),
      now: DateTime(2026, 7, 8),
    );
    expect(result.isValid, isFalse);
    expect(result.issues.any((issue) => issue.code == 'future_date'), isTrue);
  });
}
