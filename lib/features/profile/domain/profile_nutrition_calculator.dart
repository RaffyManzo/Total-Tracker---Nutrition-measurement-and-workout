import '../data/entities/user_profile_entity.dart';
import 'profile_codes.dart';

class ProfileNutritionTargets {
  const ProfileNutritionTargets({
    required this.rmrKcal,
    required this.sedentaryMultiplier,
    required this.sedentaryKcal,
    required this.workoutDailyKcal,
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
  final double workoutDailyKcal;
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
    final double workoutDaily = _workoutDailyKcal(profile, weightKg);
    final double target = profile.targetModeCode == TargetModeCodes.fixedUser
        ? profile.defaultTargetKcal.toDouble()
        : sedentary + workoutDaily;
    final double carbsGrams = profile.carbsGramsPerKg * weightKg;
    final double sugarPercent = profile.sugarCarbsPercent <= 0
        ? 15
        : profile.sugarCarbsPercent.clamp(0, 100).toDouble();
    return ProfileNutritionTargets(
      sedentaryKcal: sedentary,
      rmrKcal: rmr,
      sedentaryMultiplier: sedentaryMultiplier,
      workoutDailyKcal: workoutDaily,
      targetKcal: target.clamp(
        profile.minimumReasonableTdee,
        profile.maximumReasonableTdee,
      ),
      proteinGrams: profile.proteinGramsPerKg * weightKg,
      fatGrams: profile.fatGramsPerKg * weightKg,
      fiberGrams: profile.fiberGramsPerKg * weightKg,
      carbsGrams: carbsGrams,
      sugarGrams: carbsGrams * sugarPercent / 100,
    );
  }

  double _rmrKcal(
    UserProfileEntity profile,
    double weightKg, {
    DateTime? now,
  }) {
    final int? age = _age(profile.birthDateEpochDay, now ?? DateTime.now());
    final double? heightCm = profile.heightCm;
    if (age == null || heightCm == null || heightCm <= 0) {
      return profile.defaultTargetKcal / (profile.rmrActivityFactor <= 0
          ? 1.10
          : profile.rmrActivityFactor);
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

  double _workoutDailyKcal(UserProfileEntity profile, double weightKg) {
    final double metNet = switch (profile.workoutActivityTypeCode) {
      WorkoutActivityTypeCodes.mixed => 5.5,
      WorkoutActivityTypeCodes.cardio => 7.0,
      _ => 4.0,
    };
    final double durationHours =
        (profile.averageWorkoutDurationMinutes / 60).clamp(0, 8).toDouble();
    final double workouts =
        profile.averageWorkoutsPerWeek.clamp(0, 14).toDouble();
    return metNet * weightKg * durationHours * workouts / 7;
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
