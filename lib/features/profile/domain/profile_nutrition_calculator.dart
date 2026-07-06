import '../../nutrition/domain/target_model_constants.dart';
import '../../nutrition/domain/target_model_math.dart';
import '../data/entities/user_profile_entity.dart';
import 'profile_activity_estimator.dart';
import 'profile_codes.dart';

class ProfileNutritionTargets {
  const ProfileNutritionTargets({
    required this.rmrKcal,
    required this.rmrEquationCode,
    required this.rmrPhysiologicalCoefficientCode,
    required this.rmrFallbackUsed,
    required this.rmrAgeYears,
    required this.rmrHeightCm,
    required this.rmrWeightKg,
    required this.sedentaryMultiplier,
    required this.sedentaryKcal,
    required this.stepDailyKcal,
    required this.stepEstimate,
    required this.workoutDailyKcal,
    required this.profileActivityDailyKcal,
    required this.unclampedTargetKcal,
    required this.targetKcal,
    required this.guardrailApplied,
    required this.guardrailReasonCode,
    required this.proteinGrams,
    required this.proteinGramsPerKg,
    required this.fatGrams,
    required this.fatEnergyPercent,
    required this.fiberGrams,
    required this.carbsGrams,
    required this.sugarGrams,
    required this.freeSugarLimitGrams,
    required this.freeSugarPreferredGrams,
    required this.macroModelCode,
  });

  final double rmrKcal;
  final String rmrEquationCode;
  final String rmrPhysiologicalCoefficientCode;
  final bool rmrFallbackUsed;
  final int? rmrAgeYears;
  final double? rmrHeightCm;
  final double rmrWeightKg;
  final double sedentaryMultiplier;
  final double sedentaryKcal;
  final double stepDailyKcal;
  final StepEnergyEstimate stepEstimate;
  final double workoutDailyKcal;
  final double profileActivityDailyKcal;
  final double unclampedTargetKcal;
  final double targetKcal;
  final bool guardrailApplied;
  final String guardrailReasonCode;
  final double proteinGrams;
  final double proteinGramsPerKg;
  final double fatGrams;
  final double fatEnergyPercent;
  final double fiberGrams;
  final double carbsGrams;

  /// Compatibility field. It represents the WHO free-sugar limit, not total
  /// sugars present in foods. The UI must not compare total sugars to it.
  final double sugarGrams;
  final double freeSugarLimitGrams;
  final double freeSugarPreferredGrams;
  final String macroModelCode;
}

class _RmrResult {
  const _RmrResult({
    required this.kcal,
    required this.equationCode,
    required this.coefficientCode,
    required this.fallbackUsed,
    required this.ageYears,
    required this.heightCm,
  });

  final double kcal;
  final String equationCode;
  final String coefficientCode;
  final bool fallbackUsed;
  final int? ageYears;
  final double? heightCm;
}

class ProfileNutritionCalculator {
  const ProfileNutritionCalculator();

  ProfileNutritionTargets calculateFixedTargets(
    UserProfileEntity profile, {
    double? currentWeightKg,
    DateTime? now,
  }) {
    final double weightKg =
        currentWeightKg ?? profile.initialWeightKg ?? profile.weightFallbackKg;
    final _RmrResult rmr = _rmr(profile, weightKg, now: now);
    final double baseFactor = profile.rmrActivityFactor <= 0
        ? TargetModelConstants.rmrActivityFactor
        : profile.rmrActivityFactor;
    final double sedentary = rmr.kcal * baseFactor;
    final StepEnergyEstimate stepEstimate = TargetModelMath.estimateSteps(
      steps: profile.defaultStepGoal.clamp(0, 100000).toInt(),
      weightKg: weightKg,
      heightCm: profile.heightCm,
      legacyKcalPerStep: profile.stepKcalCoefficient <= 0
          ? TargetModelConstants.legacyStepKcalCoefficient
          : profile.stepKcalCoefficient,
    );
    final double workoutDaily = workoutDailyKcal(profile, weightKg);
    final double profileActivityDaily = stepEstimate.activeKcal + workoutDaily;
    final double calculatedTarget = sedentary + profileActivityDaily;
    final double requestedTarget =
        profile.targetModeCode == TargetModeCodes.fixedUser
            ? profile.defaultTargetKcal.toDouble()
            : calculatedTarget;
    final GuardrailResult guardrail = TargetModelMath.applyGuardrail(
      value: requestedTarget,
      minimum: profile.minimumReasonableTdee,
      maximum: profile.maximumReasonableTdee,
    );
    final double targetKcal = guardrail.value;

    final bool legacyCustom = profile.macroModeCode == MacroModeCodes.custom;
    final bool theo2Custom =
        profile.macroModeCode == MacroModeCodes.customTheo2;
    final double proteinPerKg = legacyCustom || theo2Custom
        ? profile.proteinGramsPerKg
            .clamp(
              TargetModelConstants.proteinMinimumGramsPerKg,
              TargetModelConstants.proteinMaximumGramsPerKg,
            )
            .toDouble()
        : TargetModelConstants.proteinDefaultGramsPerKg;
    final double proteinGrams = proteinPerKg * weightKg;

    final double fatEnergyPercent;
    final double fatGrams;
    final String macroModelCode;
    if (legacyCustom) {
      fatGrams = profile.fatGramsPerKg.clamp(0, 10).toDouble() * weightKg;
      fatEnergyPercent = targetKcal <= 0
          ? 0
          : fatGrams * TargetModelConstants.fatKcalPerGram / targetKcal * 100;
      macroModelCode = 'legacy_custom_g_per_kg';
    } else {
      fatEnergyPercent = theo2Custom
          ? profile.fatGramsPerKg
              .clamp(
                TargetModelConstants.fatMinimumEnergyPercent,
                TargetModelConstants.fatMaximumEnergyPercent,
              )
              .toDouble()
          : TargetModelConstants.fatDefaultEnergyPercent;
      fatGrams = targetKcal *
          fatEnergyPercent /
          100 /
          TargetModelConstants.fatKcalPerGram;
      macroModelCode = theo2Custom ? 'theo2_custom' : 'theo2_default';
    }

    final double proteinKcal =
        proteinGrams * TargetModelConstants.proteinKcalPerGram;
    final double fatKcal = fatGrams * TargetModelConstants.fatKcalPerGram;
    final double carbohydrateKcal = (targetKcal - proteinKcal - fatKcal)
        .clamp(0, double.infinity)
        .toDouble();
    final double carbsGrams =
        carbohydrateKcal / TargetModelConstants.carbohydrateKcalPerGram;
    final double fiberGrams = legacyCustom
        ? profile.fiberGramsPerKg.clamp(0, 10).toDouble() * weightKg
        : (TargetModelConstants.fiberGramsPer1000Kcal * targetKcal / 1000)
            .clamp(TargetModelConstants.fiberMinimumGrams, double.infinity)
            .toDouble();
    final double freeSugarLimitGrams = targetKcal *
        TargetModelConstants.freeSugarLimitEnergyPercent /
        100 /
        TargetModelConstants.carbohydrateKcalPerGram;
    final double freeSugarPreferredGrams = targetKcal *
        TargetModelConstants.freeSugarPreferredEnergyPercent /
        100 /
        TargetModelConstants.carbohydrateKcalPerGram;

    return ProfileNutritionTargets(
      rmrKcal: rmr.kcal,
      rmrEquationCode: rmr.equationCode,
      rmrPhysiologicalCoefficientCode: rmr.coefficientCode,
      rmrFallbackUsed: rmr.fallbackUsed,
      rmrAgeYears: rmr.ageYears,
      rmrHeightCm: rmr.heightCm,
      rmrWeightKg: weightKg,
      sedentaryKcal: sedentary,
      sedentaryMultiplier: baseFactor,
      stepDailyKcal: stepEstimate.activeKcal,
      stepEstimate: stepEstimate,
      workoutDailyKcal: workoutDaily,
      profileActivityDailyKcal: profileActivityDaily,
      unclampedTargetKcal: requestedTarget,
      targetKcal: targetKcal,
      guardrailApplied: guardrail.applied,
      guardrailReasonCode: guardrail.reasonCode,
      proteinGrams: proteinGrams,
      proteinGramsPerKg: proteinPerKg,
      fatGrams: fatGrams,
      fatEnergyPercent: fatEnergyPercent,
      fiberGrams: fiberGrams,
      carbsGrams: carbsGrams,
      sugarGrams: freeSugarLimitGrams,
      freeSugarLimitGrams: freeSugarLimitGrams,
      freeSugarPreferredGrams: freeSugarPreferredGrams,
      macroModelCode: macroModelCode,
    );
  }

  double workoutDailyKcal(UserProfileEntity profile, double weightKg) {
    final ProfileActivityConfig config = ProfileActivityConfig.fromJsonString(
      profile.activityProfileJson,
      legacyWorkoutTypeCode: profile.workoutActivityTypeCode,
      legacyDurationMinutes: profile.averageWorkoutDurationMinutes,
      legacySessionsPerWeek: profile.averageWorkoutsPerWeek,
    );
    return ProfileActivityEstimator.estimate(
      config: config,
      weightKg: weightKg,
    ).dailyKcal;
  }

  _RmrResult _rmr(
    UserProfileEntity profile,
    double weightKg, {
    DateTime? now,
  }) {
    final int? age = _age(profile.birthDateEpochDay, now ?? DateTime.now());
    final double? heightCm = profile.heightCm;
    if (age == null || heightCm == null || heightCm <= 0) {
      return _RmrResult(
        kcal: profile.defaultTargetKcal /
            (profile.rmrActivityFactor <= 0
                ? TargetModelConstants.rmrActivityFactor
                : profile.rmrActivityFactor),
        equationCode: 'legacy_target_fallback',
        coefficientCode: 'anthropometrics_missing',
        fallbackUsed: true,
        ageYears: age,
        heightCm: heightCm,
      );
    }
    final double common = 10 * weightKg + 6.25 * heightCm - 5 * age;
    if (profile.biologicalSexCode == BiologicalSexCodes.male) {
      return _RmrResult(
        kcal: common + TargetModelConstants.rmrMaleConstant,
        equationCode: TargetModelConstants.rmrEquation,
        coefficientCode: 'male_plus_5',
        fallbackUsed: false,
        ageYears: age,
        heightCm: heightCm,
      );
    }
    if (profile.biologicalSexCode == BiologicalSexCodes.female) {
      return _RmrResult(
        kcal: common + TargetModelConstants.rmrFemaleConstant,
        equationCode: TargetModelConstants.rmrEquation,
        coefficientCode: 'female_minus_161',
        fallbackUsed: false,
        ageYears: age,
        heightCm: heightCm,
      );
    }
    return _RmrResult(
      kcal: common + TargetModelConstants.rmrUnspecifiedConstant,
      equationCode: TargetModelConstants.rmrEquation,
      coefficientCode: 'unspecified_minus_78',
      fallbackUsed: true,
      ageYears: age,
      heightCm: heightCm,
    );
  }

  int? _age(int? birthDateEpochDay, DateTime now) {
    if (birthDateEpochDay == null) {
      return null;
    }
    final DateTime birthDate = DateTime.fromMillisecondsSinceEpoch(
      birthDateEpochDay * Duration.millisecondsPerDay,
    );
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age -= 1;
    }
    return age < 0 ? null : age;
  }
}

extension on UserProfileEntity {
  double get weightFallbackKg => 70;
}
