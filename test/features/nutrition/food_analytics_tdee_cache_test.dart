import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/entities/ingredient_entity.dart';
import 'package:total_tracker/features/nutrition/data/entities/nutrition_tracking_entities.dart';
import 'package:total_tracker/features/nutrition/data/repositories/meal_repository.dart';
import 'package:total_tracker/features/nutrition/data/repositories/measurement_repository.dart';
import 'package:total_tracker/features/nutrition/data/services/food_analytics_service.dart';
import 'package:total_tracker/features/profile/data/entities/user_profile_entity.dart';
import 'package:total_tracker/features/profile/domain/profile_codes.dart';
import 'package:total_tracker/features/workout/data/entities/workout_tracking_entities.dart';
import 'package:total_tracker/features/workout/data/repositories/workout_session_repository.dart';

import '../../helpers/objectbox_test_helper.dart';

void main() {
  test('same target inputs reuse one memoized result', () async {
    final fixture = await _openFixture();

    final first = fixture.analytics.targetResultForDay(
      day: fixture.day,
      allDays: <DailyRecordEntity>[fixture.day],
      profile: fixture.profile,
      now: DateTime.utc(2026, 7, 9, 12),
    );
    final second = fixture.analytics.targetResultForDay(
      day: fixture.day,
      allDays: <DailyRecordEntity>[fixture.day],
      profile: fixture.profile,
      now: DateTime.utc(2026, 7, 9, 12, 30),
    );

    expect(identical(first, second), isTrue);
  });

  test('food, scale, activity and step changes invalidate memoized target',
      () async {
    final fixture = await _openFixture();

    TargetDayResult current() {
      return fixture.analytics.targetResultForDay(
        day: fixture.day,
        allDays: <DailyRecordEntity>[fixture.day],
        profile: fixture.profile,
        now: DateTime.utc(2026, 7, 9, 12),
      );
    }

    final baseline = current();
    fixture.meals.saveMealWithItems(
      MealEntity(
        uuid: '',
        dateKey: '2026-07-09',
        mealTypeCode: 'pranzo',
        title: 'Pranzo',
        createdAtEpochMs: 0,
        updatedAtEpochMs: 0,
      ),
      <MealItemEntity>[
        MealItemEntity(
          uuid: '',
          kindCode: 'ingredient',
          sourceUuid: 'cache-food',
          itemNameSnapshot: 'Cache food',
          grams: 100,
          kcal: 200,
          createdAtEpochMs: 0,
          updatedAtEpochMs: 0,
        ),
      ],
    );
    final afterFood = current();
    expect(identical(baseline, afterFood), isFalse);

    fixture.measurements.saveScale(
      ScaleMeasurementEntity(
        uuid: '',
        dateKey: '2026-07-09',
        title: 'Bilancia',
        weightKg: 72,
        createdAtEpochMs: 0,
        updatedAtEpochMs: 0,
      ),
    );
    final afterScale = current();
    expect(identical(afterFood, afterScale), isFalse);

    fixture.workouts.save(
      WorkoutSessionEntity(
        uuid: '',
        title: 'Workout',
        sessionDateKey: '2026-07-09',
        statusCode: 'completed',
        estimatedKcalBurned: 250,
        createdAtEpochMs: 0,
        updatedAtEpochMs: 0,
      ),
    );
    final afterWorkout = current();
    expect(identical(afterScale, afterWorkout), isFalse);

    fixture.day.steps += 1000;
    fixture.day.updatedAtEpochMs += 1;
    final afterSteps = current();
    expect(identical(afterWorkout, afterSteps), isFalse);
  });
}

class _AnalyticsFixture {
  const _AnalyticsFixture({
    required this.analytics,
    required this.meals,
    required this.measurements,
    required this.workouts,
    required this.day,
    required this.profile,
  });

  final FoodAnalyticsService analytics;
  final MealRepository meals;
  final MeasurementRepository measurements;
  final WorkoutSessionRepository workouts;
  final DailyRecordEntity day;
  final UserProfileEntity profile;
}

Future<_AnalyticsFixture> _openFixture() async {
  final database = await openTestDatabase();
  final meals = MealRepository(database.store);
  final measurements = MeasurementRepository(database.store);
  final workouts = WorkoutSessionRepository(database.store);
  final day = DailyRecordEntity(
    uuid: 'day-cache',
    dateKey: '2026-07-09',
    caloriesInKcal: 2000,
    steps: 6000,
    createdAtEpochMs: 1,
    updatedAtEpochMs: 1,
  );
  final profile = UserProfileEntity(
    uuid: 'profile-cache',
    targetModeCode: TargetModeCodes.fixedUser,
    defaultTargetKcal: 2100,
    heightCm: 175,
    initialWeightKg: 72,
    createdAtEpochMs: 1,
    updatedAtEpochMs: 1,
  );
  database.store.box<IngredientEntity>().put(
        IngredientEntity(
          uuid: 'cache-food',
          name: 'Cache food',
          createdAtEpochMs: 1,
          updatedAtEpochMs: 1,
        ),
      );
  return _AnalyticsFixture(
    analytics: FoodAnalyticsService(
      meals: meals,
      measurements: measurements,
      workoutSessions: workouts,
      diagnosticsEnabled: false,
    ),
    meals: meals,
    measurements: measurements,
    workouts: workouts,
    day: day,
    profile: profile,
  );
}
