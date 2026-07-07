import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/domain/composition_reliability.dart';

void main() {
  test('one known device plus unspecified metadata is penalized, not blocked',
      () {
    final result = CompositionReliabilityCalculator.calculate(
      validDays: 15,
      coverageDays: 20,
      maximumGapDays: 2,
      maximumWaterRangePercent: 6,
      waterPercentages: List<double?>.filled(15, 60),
      deviceCodes: const <String>['ttdev:abc::name', 'unspecified'],
      minimumRequired: 0.55,
    );

    expect(result.deviceStatusCode, 'device_metadata_incomplete');
    expect(result.deviceFactor, 0.85);
    expect(result.passed, isTrue);
  });

  test('two stable known device ids are a hard conflict', () {
    final result = CompositionReliabilityCalculator.calculate(
      validDays: 15,
      coverageDays: 20,
      maximumGapDays: 2,
      maximumWaterRangePercent: 6,
      waterPercentages: List<double?>.filled(15, 60),
      deviceCodes: const <String>['ttdev:abc::a', 'ttdev:def::b'],
      minimumRequired: 0.55,
    );

    expect(result.deviceStatusCode, 'device_changed');
    expect(result.passed, isFalse);
  });

  test(
      'water range above the hard limit blocks eligibility even with a sufficient score',
      () {
    final result = CompositionReliabilityCalculator.calculate(
      validDays: 14,
      coverageDays: 28,
      maximumGapDays: 3,
      maximumWaterRangePercent: 6,
      waterPercentages: const <double?>[55, 62, 55, 62, 55, 62, 55],
      deviceCodes: const <String>['Bilancia casa'],
      minimumRequired: 0.55,
    );

    expect(result.score, greaterThan(0.55));
    expect(result.waterStatusCode, 'water_variation_too_large');
    expect(result.hardFailureReasonCode, 'water_variation_too_large');
    expect(result.passed, isFalse);
  });

  test('score exposes factors and weighted contributions', () {
    final result = CompositionReliabilityCalculator.calculate(
      validDays: 14,
      coverageDays: 28,
      maximumGapDays: 3,
      maximumWaterRangePercent: 6,
      waterPercentages: List<double?>.filled(14, 60),
      deviceCodes: const <String>['Bilancia casa'],
      minimumRequired: 0.55,
    );

    expect(result.score, closeTo(1, 0.000001));
    expect(result.dayContribution, closeTo(0.30, 0.000001));
    expect(result.coverageContribution, closeTo(0.25, 0.000001));
    expect(result.gapContribution, closeTo(0.20, 0.000001));
    expect(result.waterContribution, closeTo(0.15, 0.000001));
    expect(result.deviceContribution, closeTo(0.10, 0.000001));
  });
}
