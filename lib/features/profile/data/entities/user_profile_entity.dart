import 'package:objectbox/objectbox.dart';

import '../../domain/profile_codes.dart';

@Entity()
class UserProfileEntity {
  UserProfileEntity({
    this.id = 0,
    required this.uuid,
    this.displayName = '',
    this.birthDateEpochDay,
    this.biologicalSexCode = BiologicalSexCodes.unspecified,
    this.heightCm,
    this.initialWeightKg,
    this.defaultStepGoal = 8000,
    this.defaultTargetKcal = 1980,
    this.targetModeCode = TargetModeCodes.adaptiveWeekly,
    this.sedentaryBaseKcal = 0,
    this.averageWorkoutsPerWeek = 3,
    this.averageWorkoutDurationMinutes = 60,
    this.workoutActivityTypeCode = WorkoutActivityTypeCodes.weights,
    this.activityProfileJson = '',
    this.activityFallbackModeCode =
        ActivityFallbackModeCodes.recordedWithProfileFallback,
    this.macroModeCode = MacroModeCodes.defaultByWeight,
    this.mealTargetModeCode = MealTargetModeCodes.none,
    this.mealTargetsJson = '{}',
    this.proteinGramsPerKg = 2.2,
    this.fatGramsPerKg = 1.0,
    this.fiberGramsPerKg = 0.5,
    this.carbsGramsPerKg = 3.0,
    this.sugarCarbsPercent = 25,
    this.waterGlassLiters = 0.25,
    this.stepKcalCoefficient = 0.020,
    this.adaptiveReferenceDays = 28,
    this.adaptiveMinimumObservedDays = 7,
    this.rmrActivityFactor = 1.10,
    this.kcalPerKg = 7700,
    this.minimumReasonableTdee = 1300,
    this.maximumReasonableTdee = 4600,
    this.themeModeCode = ThemePreferenceCodes.system,
    this.languageCode = 'it',
    this.exportFolderPath = '',
    this.isActive = true,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.deletedAtEpochMs,
  });

  @Id()
  int id;

  @Unique()
  String uuid;

  String displayName;
  int? birthDateEpochDay;
  String biologicalSexCode;
  double? heightCm;
  double? initialWeightKg;

  int defaultStepGoal;
  int defaultTargetKcal;
  String targetModeCode;
  double sedentaryBaseKcal;
  int averageWorkoutsPerWeek;
  int averageWorkoutDurationMinutes;
  String workoutActivityTypeCode;
  String activityProfileJson;
  String activityFallbackModeCode;
  String macroModeCode;
  String mealTargetModeCode;
  String mealTargetsJson;
  double proteinGramsPerKg;
  double fatGramsPerKg;
  double fiberGramsPerKg;
  double carbsGramsPerKg;
  double sugarCarbsPercent;
  double waterGlassLiters;
  double stepKcalCoefficient;

  int adaptiveReferenceDays;
  int adaptiveMinimumObservedDays;
  double rmrActivityFactor;
  double kcalPerKg;
  double minimumReasonableTdee;
  double maximumReasonableTdee;
  String themeModeCode;
  String languageCode;
  String exportFolderPath;

  bool isActive;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
}
