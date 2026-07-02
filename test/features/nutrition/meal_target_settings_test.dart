import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/domain/meal_target_settings.dart';
import 'package:total_tracker/features/profile/data/entities/user_profile_entity.dart';
import 'package:total_tracker/features/profile/domain/profile_codes.dart';

void main() {
  UserProfileEntity profile({
    String mode = MealTargetModeCodes.none,
    String json = '{}',
  }) {
    return UserProfileEntity(
      uuid: 'profile-test',
      mealTargetModeCode: mode,
      mealTargetsJson: json,
      createdAtEpochMs: 1,
      updatedAtEpochMs: 1,
    );
  }

  test('uniform distribution assigns 25 percent to every meal', () {
    const MealTargetSettings settings = MealTargetSettings(
      modeCode: MealTargetModeCodes.shared,
    );

    for (final String slot in MealTargetSettings.supportedSlots) {
      final MealNutrientPercentages percentages =
          settings.effectivePercentagesForSlot(slot);
      expect(percentages.kcalPercent, 25);
      expect(percentages.proteinPercent, 25);
      expect(percentages.carbsPercent, 25);
      expect(percentages.fatPercent, 25);
      expect(percentages.fiberPercent, 25);
      expect(percentages.sugarPercent, 25);
    }
    expect(settings.validationMessage(), isNull);
  });

  test('custom distribution requires every nutrient to sum to 100', () {
    const MealTargetSettings valid = MealTargetSettings(
      modeCode: MealTargetModeCodes.custom,
      slotPercentages: <String, MealNutrientPercentages>{
        'colazione': MealNutrientPercentages.uniform,
        'spuntino': MealNutrientPercentages.uniform,
        'pranzo': MealNutrientPercentages.uniform,
        'cena': MealNutrientPercentages.uniform,
      },
    );

    expect(valid.validationMessage(), isNull);

    const MealTargetSettings invalid = MealTargetSettings(
      modeCode: MealTargetModeCodes.custom,
      slotPercentages: <String, MealNutrientPercentages>{
        'colazione': MealNutrientPercentages.uniform,
        'spuntino': MealNutrientPercentages.uniform,
        'pranzo': MealNutrientPercentages.uniform,
        'cena': MealNutrientPercentages(
          kcalPercent: 20,
          proteinPercent: 25,
          carbsPercent: 25,
          fatPercent: 25,
          fiberPercent: 25,
          sugarPercent: 25,
        ),
      },
    );

    expect(invalid.validationMessage(), contains('calorie'));
    expect(invalid.validationMessage(), contains('95%'));
  });

  test('percentage distribution resolves calories macros fiber and sugar', () {
    const MealTargetSettings settings = MealTargetSettings(
      modeCode: MealTargetModeCodes.custom,
      slotPercentages: <String, MealNutrientPercentages>{
        'pranzo': MealNutrientPercentages(
          kcalPercent: 40,
          proteinPercent: 35,
          carbsPercent: 45,
          fatPercent: 30,
          fiberPercent: 50,
          sugarPercent: 20,
        ),
      },
    );

    final MealNutrientTarget target = settings.targetForSlot(
      slotCode: 'pranzo',
      dailyKcal: 2000,
      dailyProteinGrams: 120,
      dailyCarbsGrams: 250,
      dailyFatGrams: 60,
      dailyFiberGrams: 30,
      dailySugarGrams: 50,
    );

    expect(target.kcal, 800);
    expect(target.proteinGrams, 42);
    expect(target.carbsGrams, 112.5);
    expect(target.fatGrams, 18);
    expect(target.fiberGrams, 15);
    expect(target.sugarGrams, 10);
  });

  test('settings survive profile JSON round trip', () {
    const MealTargetSettings original = MealTargetSettings(
      modeCode: MealTargetModeCodes.custom,
      slotPercentages: <String, MealNutrientPercentages>{
        'colazione': MealNutrientPercentages(
          kcalPercent: 20,
          proteinPercent: 30,
          carbsPercent: 25,
          fatPercent: 20,
          fiberPercent: 30,
          sugarPercent: 10,
        ),
      },
    );
    final UserProfileEntity entity = profile(
      mode: MealTargetModeCodes.custom,
      json: original.toJsonString(),
    );

    final MealTargetSettings decoded = MealTargetSettings.fromProfile(entity);
    final MealNutrientPercentages percentages =
        decoded.effectivePercentagesForSlot('colazione');

    expect(decoded.modeCode, MealTargetModeCodes.custom);
    expect(percentages.kcalPercent, 20);
    expect(percentages.proteinPercent, 30);
    expect(percentages.carbsPercent, 25);
    expect(percentages.fatPercent, 20);
    expect(percentages.fiberPercent, 30);
    expect(percentages.sugarPercent, 10);
  });

  test('invalid profile JSON falls back without throwing', () {
    final MealTargetSettings decoded = MealTargetSettings.fromProfile(
      profile(
        mode: MealTargetModeCodes.shared,
        json: '{not-json',
      ),
    );

    expect(decoded.modeCode, MealTargetModeCodes.shared);
    expect(
      decoded.effectivePercentagesForSlot('colazione').kcalPercent,
      25,
    );
  });
}
