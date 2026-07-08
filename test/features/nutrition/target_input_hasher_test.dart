import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/entities/nutrition_tracking_entities.dart';
import 'package:total_tracker/features/nutrition/data/services/target_input_hasher.dart';

void main() {
  DailyRecordEntity day({int steps = 4000}) {
    return DailyRecordEntity(
      uuid: 'day-2026-07-08',
      dateKey: '2026-07-08',
      steps: steps,
      stepGoal: 8000,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 1,
    );
  }

  test('input revision seed makes repository mutations observable', () {
    final DailyRecordEntity record = day();
    final String first = TargetInputHasher.hashForDay(
      day: record,
      chronologicalHistory: <DailyRecordEntity>[record],
      modelVersion: 'target-model-0.1.0-theo.5',
      inputRevisionSeed: 'meal:revision:1',
    );
    final String second = TargetInputHasher.hashForDay(
      day: record,
      chronologicalHistory: <DailyRecordEntity>[record],
      modelVersion: 'target-model-0.1.0-theo.5',
      inputRevisionSeed: 'meal:revision:2',
    );
    expect(second, isNot(first));
  });

  test('calculated snapshot fields do not invalidate their own input hash', () {
    final DailyRecordEntity record = day();
    final String before = TargetInputHasher.hashForDay(
      day: record,
      chronologicalHistory: <DailyRecordEntity>[record],
      modelVersion: 'target-model-0.1.0-theo.5',
      inputRevisionSeed: 'stable-revision',
    );
    record.targetKcal = 2100;
    record.activeEffectiveKcal = 350;
    record.caloriesInKcal = 1900;
    record.dataCompletenessScore = 0.9;
    final String after = TargetInputHasher.hashForDay(
      day: record,
      chronologicalHistory: <DailyRecordEntity>[record],
      modelVersion: 'target-model-0.1.0-theo.5',
      inputRevisionSeed: 'stable-revision',
    );
    expect(after, before);
  });

  test('a user-entered daily input changes the canonical hash', () {
    final DailyRecordEntity firstDay = day(steps: 4000);
    final DailyRecordEntity changedDay = day(steps: 5000);
    final String first = TargetInputHasher.hashForDay(
      day: firstDay,
      chronologicalHistory: <DailyRecordEntity>[firstDay],
      modelVersion: 'target-model-0.1.0-theo.5',
      inputRevisionSeed: 'daily:revision:1',
    );
    final String changed = TargetInputHasher.hashForDay(
      day: changedDay,
      chronologicalHistory: <DailyRecordEntity>[changedDay],
      modelVersion: 'target-model-0.1.0-theo.5',
      inputRevisionSeed: 'daily:revision:1',
    );
    expect(changed, isNot(first));
  });
}
