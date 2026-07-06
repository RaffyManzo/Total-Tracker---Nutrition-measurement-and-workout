import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/domain/target_model_constants.dart';
import 'package:total_tracker/features/profile/data/entities/user_profile_entity.dart';
import 'package:total_tracker/features/profile/domain/profile_codes.dart';
import 'package:total_tracker/features/profile/domain/profile_nutrition_calculator.dart';

void main() {
  UserProfileEntity profile({
    String targetMode = TargetModeCodes.appCalculatedFixed,
    String sex = BiologicalSexCodes.male,
    String macroMode = MacroModeCodes.defaultByWeight,
    int defaultTargetKcal = 2100,
    double proteinPerKg = 1.8,
    double fatPerKg = 1.0,
    double carbsPerKg = 4.0,
  }) {
    return UserProfileEntity(
      uuid: 'profile-calculator-test',
      targetModeCode: targetMode,
      biologicalSexCode: sex,
      defaultTargetKcal: defaultTargetKcal,
      defaultStepGoal: 8000,
      averageWorkoutsPerWeek: 3,
      averageWorkoutDurationMinutes: 60,
      workoutActivityTypeCode: WorkoutActivityTypeCodes.weights,
      initialWeightKg: 64,
      heightCm: 160,
      macroModeCode: macroMode,
      proteinGramsPerKg: proteinPerKg,
      fatGramsPerKg: fatPerKg,
      carbsGramsPerKg: carbsPerKg,
      birthDateEpochDay: DateTime(2004, 1, 1).millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 1,
    );
  }

  test('uses Mifflin St Jeor male equation without intermediate rounding', () {
    const ProfileNutritionCalculator calculator = ProfileNutritionCalculator();
    final ProfileNutritionTargets result = calculator.calculateFixedTargets(
      profile(),
      now: DateTime(2026, 7, 2),
    );

    expect(result.rmrKcal, closeTo(1535, 0.0001));
    expect(result.rmrEquationCode, TargetModelConstants.rmrEquation);
    expect(result.rmrPhysiologicalCoefficientCode, 'male_plus_5');
    expect(result.rmrFallbackUsed, isFalse);
  });

  test('uses Mifflin St Jeor female equation', () {
    const ProfileNutritionCalculator calculator = ProfileNutritionCalculator();
    final ProfileNutritionTargets result = calculator.calculateFixedTargets(
      profile(sex: BiologicalSexCodes.female),
      now: DateTime(2026, 7, 2),
    );

    expect(result.rmrKcal, closeTo(1369, 0.0001));
    expect(result.rmrPhysiologicalCoefficientCode, 'female_minus_161');
    expect(result.rmrFallbackUsed, isFalse);
  });

  test('unspecified physiological coefficient uses approved minus 78 fallback',
      () {
    const ProfileNutritionCalculator calculator = ProfileNutritionCalculator();
    final ProfileNutritionTargets result = calculator.calculateFixedTargets(
      profile(sex: BiologicalSexCodes.unspecified),
      now: DateTime(2026, 7, 2),
    );

    expect(result.rmrKcal, closeTo(1452, 0.0001));
    expect(result.rmrPhysiologicalCoefficientCode, 'unspecified_minus_78');
    expect(result.rmrFallbackUsed, isTrue);
  });

  test('step estimate uses weight, height-derived step length and distance',
      () {
    const ProfileNutritionCalculator calculator = ProfileNutritionCalculator();
    final ProfileNutritionTargets result = calculator.calculateFixedTargets(
      profile(),
      now: DateTime(2026, 7, 2),
    );

    expect(result.stepEstimate.stepLengthMeters, closeTo(0.672, 0.000001));
    expect(result.stepEstimate.distanceKm, closeTo(5.376, 0.000001));
    expect(
        result.stepEstimate.effectiveKcalPerStep, closeTo(0.021504, 0.000001));
    expect(result.stepDailyKcal, closeTo(172.032, 0.0001));
    expect(result.workoutDailyKcal, greaterThan(0));
    expect(
      result.profileActivityDailyKcal,
      closeTo(result.stepDailyKcal + result.workoutDailyKcal, 0.0001),
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

  test('new default macros reproduce target with 4 4 9 factors', () {
    const ProfileNutritionCalculator calculator = ProfileNutritionCalculator();
    final ProfileNutritionTargets result = calculator.calculateFixedTargets(
      profile(targetMode: TargetModeCodes.fixedUser),
      now: DateTime(2026, 7, 2),
    );

    final double macroKcal =
        result.proteinGrams * 4 + result.carbsGrams * 4 + result.fatGrams * 9;

    expect(macroKcal, closeTo(result.targetKcal, 0.0001));
    expect(result.proteinGramsPerKg, 1.8);
    expect(result.proteinGrams, closeTo(115.2, 0.0001));
    expect(result.fatEnergyPercent, 25);
    expect(result.fatGrams, closeTo(58.333333, 0.0001));
    expect(result.carbsGrams, closeTo(278.55, 0.0001));
    expect(result.fiberGrams, closeTo(29.4, 0.0001));
    expect(result.freeSugarLimitGrams, closeTo(52.5, 0.0001));
    expect(result.freeSugarPreferredGrams, closeTo(26.25, 0.0001));
  });

  test('fiber target keeps the 25 gram minimum at lower energy', () {
    const ProfileNutritionCalculator calculator = ProfileNutritionCalculator();
    final ProfileNutritionTargets result = calculator.calculateFixedTargets(
      profile(
        targetMode: TargetModeCodes.fixedUser,
        defaultTargetKcal: 1500,
      ),
      now: DateTime(2026, 7, 2),
    );

    expect(result.fiberGrams, 25);
    expect(result.freeSugarLimitGrams, closeTo(37.5, 0.0001));
    expect(result.freeSugarPreferredGrams, closeTo(18.75, 0.0001));
  });

  test('personalized macros use g per kg and expose calorie correction', () {
    const ProfileNutritionCalculator calculator = ProfileNutritionCalculator();
    final ProfileNutritionTargets result = calculator.calculateFixedTargets(
      profile(
        targetMode: TargetModeCodes.fixedUser,
        macroMode: MacroModeCodes.customGramsPerKg,
        proteinPerKg: 2,
        fatPerKg: 1,
        carbsPerKg: 4,
      ),
      now: DateTime(2026, 7, 2),
    );

    expect(result.proteinGrams, 128);
    expect(result.fatGrams, 64);
    expect(result.carbsGrams, 256);
    expect(result.macroCalculatedKcal, 2112);
    expect(result.macroTargetKcal, 2100);
    expect(result.macroCalorieDelta, 12);
    expect(result.macroCaloriesMatchTarget, isTrue);
    expect(result.suggestedProteinGramsPerKg, closeTo(1.988636, 0.00001));
    expect(result.suggestedFatGramsPerKg, closeTo(0.994318, 0.00001));
    expect(result.suggestedCarbsGramsPerKg, closeTo(3.977273, 0.00001));
    expect(result.fiberGrams, closeTo(29.4, 0.0001));
    expect(result.freeSugarLimitGrams, closeTo(52.5, 0.0001));
  });
}
