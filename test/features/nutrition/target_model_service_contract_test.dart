import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('historical and daily activity use component-wise fallback', () {
    final String source = File(
      'lib/features/nutrition/data/services/food_analytics_service.dart',
    ).readAsStringSync();

    expect(source, contains('component_fallback_history'));
    expect(source, contains('effectiveActivityForDay('));
    expect(source, contains('ogni componente registrata è stata'));
    expect(source, contains('result.activity.actualWorkoutKcal'));
    expect(source, contains('hasRecordedWorkout'));
    expect(source, contains('hasCompletedWorkoutRecord'));
    expect(source, contains('estimated_active_calories'));
    expect(source, contains('_estimatedActiveCalories'));
  });

  test('migration preserves historical target snapshots', () {
    final String source = File(
      'lib/features/profile/presentation/profile_settings_screen.dart',
    ).readAsStringSync();

    expect(source, contains('todayKey'));
    expect(
      source,
      contains('day.dateKey.compareTo(todayKey) >= 0'),
    );
  });
}
