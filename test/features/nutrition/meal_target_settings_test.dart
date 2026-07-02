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

  test('shared target applies to every supported meal slot', () {
    const MealTargetSettings settings = MealTargetSettings(
      modeCode: MealTargetModeCodes.shared,
      sharedTarget: MealNutrientTarget(
        kcal: 500,
        proteinGrams: 35,
      ),
    );

    for (final String slot in MealTargetSettings.supportedSlots) {
      final MealNutrientTarget target = settings.effectiveTargetForSlot(slot);
      expect(target.kcal, 500);
      expect(target.proteinGrams, 35);
    }
  });

  test('custom target returns only the selected slot values', () {
    const MealTargetSettings settings = MealTargetSettings(
      modeCode: MealTargetModeCodes.custom,
      slotTargets: <String, MealNutrientTarget>{
        'pranzo': MealNutrientTarget(kcal: 700, carbsGrams: 80),
      },
    );

    expect(settings.effectiveTargetForSlot('pranzo').kcal, 700);
    expect(settings.effectiveTargetForSlot('pranzo').carbsGrams, 80);
    expect(settings.effectiveTargetForSlot('cena').hasAny, isFalse);
  });

  test('settings survive profile JSON round trip', () {
    const MealTargetSettings original = MealTargetSettings(
      modeCode: MealTargetModeCodes.custom,
      sharedTarget: MealNutrientTarget(kcal: 400),
      slotTargets: <String, MealNutrientTarget>{
        'colazione': MealNutrientTarget(
          kcal: 450,
          proteinGrams: 30,
          carbsGrams: 55,
          fatGrams: 12,
        ),
      },
    );
    final UserProfileEntity entity = profile(
      mode: MealTargetModeCodes.custom,
      json: original.toJsonString(),
    );

    final MealTargetSettings decoded = MealTargetSettings.fromProfile(entity);

    expect(decoded.modeCode, MealTargetModeCodes.custom);
    expect(decoded.effectiveTargetForSlot('colazione').kcal, 450);
    expect(decoded.effectiveTargetForSlot('colazione').proteinGrams, 30);
    expect(decoded.effectiveTargetForSlot('colazione').carbsGrams, 55);
    expect(decoded.effectiveTargetForSlot('colazione').fatGrams, 12);
  });

  test('non-positive and non-finite values are omitted', () {
    const MealNutrientTarget raw = MealNutrientTarget(
      kcal: 0,
      proteinGrams: -2,
      carbsGrams: double.infinity,
      fatGrams: 10,
    );

    final MealNutrientTarget clean = raw.normalized();

    expect(clean.kcal, isNull);
    expect(clean.proteinGrams, isNull);
    expect(clean.carbsGrams, isNull);
    expect(clean.fatGrams, 10);
  });

  test('invalid profile JSON falls back without throwing', () {
    final MealTargetSettings decoded = MealTargetSettings.fromProfile(
      profile(
        mode: MealTargetModeCodes.shared,
        json: '{not-json',
      ),
    );

    expect(decoded.modeCode, MealTargetModeCodes.shared);
    expect(decoded.sharedTarget.hasAny, isFalse);
  });
}
