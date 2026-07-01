import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/domain/weight_measurement_anomaly.dart';

void main() {
  const WeightMeasurementSample previous = WeightMeasurementSample(
    identity: 'previous',
    dateKey: '2026-07-01',
    weightKg: 64,
  );

  test('flags a variation greater than 2 kg in the previous 3 days', () {
    final WeightAnomalyEvaluation result = evaluateWeightAnomaly(
      currentIdentity: 'current',
      currentDateKey: '2026-07-03',
      currentWeightKg: 66.1,
      measurements: const <WeightMeasurementSample>[previous],
    );

    expect(result.isAnomalous, isTrue);
    expect(result.confirmationKey, isNotNull);
  });

  test('flags a decrease greater than 2 kg', () {
    final WeightAnomalyEvaluation result = evaluateWeightAnomaly(
      currentIdentity: 'current',
      currentDateKey: '2026-07-03',
      currentWeightKg: 61.9,
      measurements: const <WeightMeasurementSample>[previous],
    );

    expect(result.isAnomalous, isTrue);
  });

  test('does not flag a variation equal to 2 kg', () {
    final WeightAnomalyEvaluation result = evaluateWeightAnomaly(
      currentIdentity: 'current',
      currentDateKey: '2026-07-03',
      currentWeightKg: 66,
      measurements: const <WeightMeasurementSample>[previous],
    );

    expect(result.isAnomalous, isFalse);
  });

  test('ignores measurements older than 3 days', () {
    final WeightAnomalyEvaluation result = evaluateWeightAnomaly(
      currentIdentity: 'current',
      currentDateKey: '2026-07-05',
      currentWeightKg: 67,
      measurements: const <WeightMeasurementSample>[previous],
    );

    expect(result.isAnomalous, isFalse);
  });

  test('ignores same-day and future measurements', () {
    final WeightAnomalyEvaluation result = evaluateWeightAnomaly(
      currentIdentity: 'current',
      currentDateKey: '2026-07-03',
      currentWeightKg: 67,
      measurements: const <WeightMeasurementSample>[
        WeightMeasurementSample(
          identity: 'same-day',
          dateKey: '2026-07-03',
          weightKg: 60,
        ),
        WeightMeasurementSample(
          identity: 'future',
          dateKey: '2026-07-04',
          weightKg: 60,
        ),
      ],
    );

    expect(result.isAnomalous, isFalse);
  });

  test('confirmation key changes when anomaly evidence changes', () {
    final WeightAnomalyEvaluation first = evaluateWeightAnomaly(
      currentIdentity: 'current',
      currentDateKey: '2026-07-03',
      currentWeightKg: 67,
      measurements: const <WeightMeasurementSample>[previous],
    );
    final WeightAnomalyEvaluation second = evaluateWeightAnomaly(
      currentIdentity: 'current',
      currentDateKey: '2026-07-03',
      currentWeightKg: 67,
      measurements: const <WeightMeasurementSample>[
        WeightMeasurementSample(
          identity: 'previous',
          dateKey: '2026-07-01',
          weightKg: 63.5,
        ),
      ],
    );

    expect(first.confirmationKey, isNot(second.confirmationKey));
  });
}
