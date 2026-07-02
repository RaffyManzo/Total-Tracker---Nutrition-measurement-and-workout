import '../data/entities/user_profile_entity.dart';
import 'profile_activity_estimator.dart';
import 'profile_codes.dart';

class ProfileNutritionTargets {
  const ProfileNutritionTargets({
    required this.rmrKcal,
    required this.sedentaryMultiplier,
    required this.sedentaryKcal,
    required this.stepDailyKcal,
    required this.workoutDailyKcal,
    required this.profileActivityDailyKcal,
    required this.targetKcal,
    required this.proteinGrams,
    required this.fatGrams,
    required this.fiberGrams,
    required this.carbsGrams,
    required this.sugarGrams,
  });

  final double rmrKcal;
  final double sedentaryMultiplier;
  final double sedentaryKcal;
  final double stepDailyKcal;
  final double workoutDailyKcal;
  final double profileActivityDailyKcal;
  final double targetKcal;
  final double proteinGrams;
  final double fatGrams;
  final double fiberGrams;
  final double carbsGrams;
  final double sugarGrams;
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
    final double rmr = _rmrKcal(profile, weightKg, now: now);
    final double sedentaryMultiplier =
        profile.rmrActivityFactor <= 0 ? 1.10 : profile.rmrActivityFactor;
    final double sedentary = rmr * sedentaryMultiplier;
    final double stepDaily =
        profile.defaultStepGoal.clamp(0, 100000).toDouble() *
            profile.stepKcalCoefficient.clamp(0, 1).toDouble();
    final double workoutDaily = workoutDailyKcal(profile, weightKg);
    final double profileActivityDaily = stepDaily + workoutDaily;
    final double target = profile.targetModeCode == TargetModeCodes.fixedUser
        ? profile.defaultTargetKcal.toDouble()
        : sedentary + profileActivityDaily;
    final double targetKcal = target
        .clamp(
          profile.minimumReasonableTdee,
          profile.maximumReasonableTdee,
        )
        .toDouble();
    final double proteinGrams = profile.proteinGramsPerKg * weightKg;
    final double fatGrams = profile.fatGramsPerKg * weightKg;
    final double proteinKcal = proteinGrams * 4;
    final double fatKcal = fatGrams * 9;
    final double carbohydrateKcal = (targetKcal - proteinKcal - fatKcal)
        .clamp(0, double.infinity)
        .toDouble();
    final double carbsGrams = carbohydrateKcal / 4;
    final double sugarPercent = profile.sugarCarbsPercent <= 0
        ? 25
        : profile.sugarCarbsPercent.clamp(0, 100).toDouble();
    return ProfileNutritionTargets(
      sedentaryKcal: sedentary,
      rmrKcal: rmr,
      sedentaryMultiplier: sedentaryMultiplier,
      stepDailyKcal: stepDaily,
      workoutDailyKcal: workoutDaily,
      profileActivityDailyKcal: profileActivityDaily,
      targetKcal: targetKcal,
      proteinGrams: proteinGrams,
      fatGrams: fatGrams,
      fiberGrams: profile.fiberGramsPerKg * weightKg,
      carbsGrams: carbsGrams,
      sugarGrams: carbsGrams * sugarPercent / 100,
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

  double _rmrKcal(
    UserProfileEntity profile,
    double weightKg, {
    DateTime? now,
  }) {
    final int? age = _age(profile.birthDateEpochDay, now ?? DateTime.now());
    final double? heightCm = profile.heightCm;
    if (age == null || heightCm == null || heightCm <= 0) {
      return profile.defaultTargetKcal /
          (profile.rmrActivityFactor <= 0 ? 1.10 : profile.rmrActivityFactor);
    }
    final double male =
        88.362 + (13.397 * weightKg) + (4.799 * heightCm) - (5.677 * age);
    final double female =
        447.593 + (9.247 * weightKg) + (3.098 * heightCm) - (4.330 * age);
    if (profile.biologicalSexCode == BiologicalSexCodes.male) {
      return male;
    }
    if (profile.biologicalSexCode == BiologicalSexCodes.female) {
      return female;
    }
    return (male + female) / 2;
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
