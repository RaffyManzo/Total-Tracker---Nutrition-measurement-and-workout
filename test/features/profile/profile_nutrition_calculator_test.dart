import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/profile/data/entities/user_profile_entity.dart';
import 'package:total_tracker/features/profile/domain/profile_codes.dart';
import 'package:total_tracker/features/profile/domain/profile_nutrition_calculator.dart';

void main() {
  UserProfileEntity profile({
    String targetMode = TargetModeCodes.appCalculatedFixed,
  }) {
    return UserProfileEntity(
      uuid: 'profile-calculator-test',
      targetModeCode: targetMode,
      defaultTargetKcal: 2100,
      defaultStepGoal: 8000,
      stepKcalCoefficient: 0.025,
      averageWorkoutsPerWeek: 3,
      averageWorkoutDurationMinutes: 60,
      workoutActivityTypeCode: WorkoutActivityTypeCodes.weights,
      initialWeightKg: 64,
      heightCm: 160,
      proteinGramsPerKg: 2,
      fatGramsPerKg: 1,
      fiberGramsPerKg: 0.5,
      sugarCarbsPercent: 20,
      birthDateEpochDay: DateTime(2004, 1, 1).millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 1,
    );
  }

  test('calculated fixed target includes profile steps and workouts', () {
    const ProfileNutritionCalculator calculator = ProfileNutritionCalculator();
    final ProfileNutritionTargets result = calculator.calculateFixedTargets(
      profile(),
      now: DateTime(2026, 7, 2),
    );

    expect(result.stepDailyKcal, 200);
    expect(result.workoutDailyKcal, greaterThan(0));
    expect(
      result.profileActivityDailyKcal,
      closeTo(result.stepDailyKcal + result.workoutDailyKcal, 0.0001),
    );
    expect(
      result.targetKcal,
      closeTo(result.sedentaryKcal + result.profileActivityDailyKcal, 0.0001),
    );
  });

  test('user fixed mode keeps the manually configured target', () {
    const ProfileNutritionCalculator calculator = ProfileNutritionCalculator();
    final ProfileNutritionTargets result = calculator.calculateFixedTargets(
      profile(targetMode: TargetModeCodes.fixedUser),
      now: DateTime(2026, 7, 2),
    );

    expect(result.targetKcal, 2100);
  });

  test('macro grams reproduce the caloric target with 4 4 9 factors', () {
    const ProfileNutritionCalculator calculator = ProfileNutritionCalculator();
    final ProfileNutritionTargets result = calculator.calculateFixedTargets(
      profile(targetMode: TargetModeCodes.fixedUser),
      now: DateTime(2026, 7, 2),
    );

    final double macroKcal =
        result.proteinGrams * 4 + result.carbsGrams * 4 + result.fatGrams * 9;

    expect(macroKcal, closeTo(result.targetKcal, 0.0001));
    expect(result.proteinGrams, 128);
    expect(result.fatGrams, 64);
    expect(result.carbsGrams, closeTo(253, 0.0001));
    expect(result.fiberGrams, 32);
    expect(result.sugarGrams, closeTo(50.6, 0.0001));
  });
}
