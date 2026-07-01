import 'package:objectbox/objectbox.dart';

@Entity()
class DailyRecordEntity {
  DailyRecordEntity({
    this.id = 0,
    required this.uuid,
    required this.dateKey,
    this.weekCode = '',
    this.weekdayCode = '',
    this.weekdayLabel = '',
    this.weekdayIndex = 1,
    this.targetKcal,
    this.targetStatusCode = 'provisional',
    this.targetCalculatedAtEpochMs,
    this.targetSourceHash = '',
    this.tdeeRefKcal,
    this.tdeeTheoreticalKcal,
    this.tdeeObservedKcal,
    this.observedConfidence,
    this.referenceDaysCount,
    this.validIntakeDays,
    this.validWeightDays,
    this.rmrKcal,
    this.weightRefKg,
    this.activeRefKcal,
    this.activeKcalSteps,
    this.activeKcalWorkoutCompleted,
    this.activeKcalWorkoutInProgress,
    this.activeKcalWorkoutPlanned,
    this.activeKcalWorkoutSkipped,
    this.activeKcalWorkoutUnknown,
    this.activeKcalActual,
    this.activeEffectiveKcal,
    this.activityDeltaKcal,
    this.activeStatusCode = 'unknown',
    this.caloriesInKcal,
    this.energyBalanceKcal,
    this.weightKg,
    this.weightReliabilityCode = '',
    this.freeMealModeCode = 'none',
    this.freeMealKcal,
    this.freeMealReliabilityCode = '',
    this.dataCompletenessScore,
    this.waterLiters,
    this.waterGlasses,
    this.sleepDeepHours,
    this.sleepLightHours,
    this.sleepQualityCode = '',
    this.steps = 0,
    this.stepGoal = 8000,
    this.notes = '',
    this.activityBonusKcal = 0,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.deletedAtEpochMs,
  });

  @Id()
  int id;

  @Index()
  String uuid;

  @Index()
  String dateKey;

  String weekCode;
  String weekdayCode;
  String weekdayLabel;
  int weekdayIndex;
  double? targetKcal;
  String targetStatusCode;
  int? targetCalculatedAtEpochMs;
  String targetSourceHash;
  double? tdeeRefKcal;
  double? tdeeTheoreticalKcal;
  double? tdeeObservedKcal;
  double? observedConfidence;
  int? referenceDaysCount;
  int? validIntakeDays;
  int? validWeightDays;
  double? rmrKcal;
  double? weightRefKg;
  double? activeRefKcal;
  double? activeKcalSteps;
  double? activeKcalWorkoutCompleted;
  double? activeKcalWorkoutInProgress;
  double? activeKcalWorkoutPlanned;
  double? activeKcalWorkoutSkipped;
  double? activeKcalWorkoutUnknown;
  double? activeKcalActual;
  double? activeEffectiveKcal;
  double? activityDeltaKcal;
  String activeStatusCode;
  double? caloriesInKcal;
  double? energyBalanceKcal;
  double? weightKg;
  String weightReliabilityCode;
  String freeMealModeCode;
  double? freeMealKcal;
  String freeMealReliabilityCode;
  double? dataCompletenessScore;
  double? waterLiters;
  int? waterGlasses;
  double? sleepDeepHours;
  double? sleepLightHours;
  String sleepQualityCode;
  int steps;
  int stepGoal;
  String notes;
  double activityBonusKcal;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
}

@Entity()
class MealEntity {
  MealEntity({
    this.id = 0,
    required this.uuid,
    required this.dateKey,
    this.weekCode = '',
    this.weekdayCode = '',
    this.weekdayLabel = '',
    required this.mealTypeCode,
    required this.title,
    this.mealModeCode = 'standard',
    this.freeMealTrackingCode = '',
    this.freeMealLabel = '',
    this.freeMealNotes = '',
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.deletedAtEpochMs,
  });

  @Id()
  int id;

  @Index()
  String uuid;

  @Index()
  String dateKey;

  String weekCode;
  String weekdayCode;
  String weekdayLabel;
  String mealTypeCode;
  String title;
  String mealModeCode;
  String freeMealTrackingCode;
  String freeMealLabel;
  String freeMealNotes;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
  final dailyRecord = ToOne<DailyRecordEntity>();
}

@Entity()
class MealItemEntity {
  MealItemEntity({
    this.id = 0,
    required this.uuid,
    this.position = 0,
    required this.kindCode,
    this.sourceUuid = '',
    required this.itemNameSnapshot,
    this.quantityModeCode = 'grams',
    this.grams,
    this.portions,
    this.kcal = 0,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    this.fiberGrams = 0,
    this.sugarGrams = 0,
    this.notes = '',
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.deletedAtEpochMs,
  });

  @Id()
  int id;

  @Index()
  String uuid;

  int position;
  String kindCode;
  String sourceUuid;
  String itemNameSnapshot;
  String quantityModeCode;
  double? grams;
  double? portions;
  double kcal;
  double proteinGrams;
  double carbsGrams;
  double fatGrams;
  double fiberGrams;
  double sugarGrams;
  String notes;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
  final meal = ToOne<MealEntity>();
}

@Entity()
class RecipeEntity {
  RecipeEntity({
    this.id = 0,
    required this.uuid,
    required this.title,
    this.subtitle = '',
    this.summary = '',
    this.imagePath = '',
    this.servings = 1,
    this.prepTimeMinutes = 0,
    this.cookTimeMinutes = 0,
    this.restTimeMinutes = 0,
    this.difficultyCode = 'easy',
    this.courseCode = '',
    this.cuisineCode = '',
    this.source = '',
    this.satietyIndex,
    this.usageScore,
    this.totalWeightGrams,
    this.yieldGrams,
    this.cookedLossGrams,
    this.cookedLossPercent,
    this.caloriesTotal,
    this.proteinTotalGrams,
    this.carbsTotalGrams,
    this.fatTotalGrams,
    this.fiberTotalGrams,
    this.sugarTotalGrams,
    this.kcalPerServing,
    this.kcalPer100Grams,
    this.proteinPer100Grams,
    this.carbsPer100Grams,
    this.fatPer100Grams,
    this.tagsJson = '[]',
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.deletedAtEpochMs,
  });

  @Id()
  int id;

  @Index()
  String uuid;

  @Index()
  String title;

  String subtitle;
  String summary;
  String imagePath;
  int servings;
  int prepTimeMinutes;
  int cookTimeMinutes;
  int restTimeMinutes;
  String difficultyCode;
  String courseCode;
  String cuisineCode;
  String source;
  double? satietyIndex;
  double? usageScore;
  double? totalWeightGrams;
  double? yieldGrams;
  double? cookedLossGrams;
  double? cookedLossPercent;
  double? caloriesTotal;
  double? proteinTotalGrams;
  double? carbsTotalGrams;
  double? fatTotalGrams;
  double? fiberTotalGrams;
  double? sugarTotalGrams;
  double? kcalPerServing;
  double? kcalPer100Grams;
  double? proteinPer100Grams;
  double? carbsPer100Grams;
  double? fatPer100Grams;
  String tagsJson;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
}

@Entity()
class RecipeIngredientEntity {
  RecipeIngredientEntity({
    this.id = 0,
    required this.uuid,
    this.position = 0,
    this.ingredientUuid = '',
    required this.nameSnapshot,
    this.grams = 0,
    this.finalGrams,
    this.preparationNote = '',
    this.calories = 0,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    this.fiberGrams = 0,
    this.sugarGrams = 0,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.deletedAtEpochMs,
  });

  @Id()
  int id;

  @Index()
  String uuid;

  int position;
  String ingredientUuid;
  String nameSnapshot;
  double grams;
  double? finalGrams;
  String preparationNote;
  double calories;
  double proteinGrams;
  double carbsGrams;
  double fatGrams;
  double fiberGrams;
  double sugarGrams;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
  final recipe = ToOne<RecipeEntity>();
}

@Entity()
class RecipeStepEntity {
  RecipeStepEntity({
    this.id = 0,
    required this.uuid,
    this.position = 0,
    required this.instruction,
    this.durationMinutes,
    this.notes = '',
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.deletedAtEpochMs,
  });

  @Id()
  int id;

  @Index()
  String uuid;

  int position;
  String instruction;
  int? durationMinutes;
  String notes;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
  final recipe = ToOne<RecipeEntity>();
}

@Entity()
class ScaleMeasurementEntity {
  ScaleMeasurementEntity({
    this.id = 0,
    required this.uuid,
    required this.dateKey,
    required this.title,
    this.weightKg,
    this.weightSourceCode = 'manual',
    this.bodyFatPercent,
    this.muscleMassKg,
    this.waterPercent,
    this.boneMassKg,
    this.visceralFat,
    this.subcutaneousFatPercent,
    this.basalMetabolismKcal,
    this.bmi,
    this.metabolicAge,
    this.physiqueRating = '',
    this.measurementTime = '',
    this.device = '',
    this.reliabilityCode = 'normal',
    this.weightAnomalyConfirmationKey = '',
    this.notes = '',
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.deletedAtEpochMs,
  });

  @Id()
  int id;

  @Index()
  String uuid;

  @Index()
  String dateKey;

  String title;
  double? weightKg;
  String weightSourceCode;
  double? bodyFatPercent;
  double? muscleMassKg;
  double? waterPercent;
  double? boneMassKg;
  double? visceralFat;
  double? subcutaneousFatPercent;
  double? basalMetabolismKcal;
  double? bmi;
  double? metabolicAge;
  String physiqueRating;
  String measurementTime;
  String device;
  String reliabilityCode;
  String weightAnomalyConfirmationKey;
  String notes;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
}

@Entity()
class TapeMeasurementEntity {
  TapeMeasurementEntity({
    this.id = 0,
    required this.uuid,
    required this.dateKey,
    required this.title,
    this.measurementTime = '',
    this.reliabilityCode = 'normal',
    this.notes = '',
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.deletedAtEpochMs,
  });

  @Id()
  int id;

  @Index()
  String uuid;

  @Index()
  String dateKey;

  String title;
  String measurementTime;
  String reliabilityCode;
  String notes;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
}

@Entity()
class TapeMeasurementEntryEntity {
  TapeMeasurementEntryEntity({
    this.id = 0,
    required this.uuid,
    required this.measurementCode,
    this.position = 0,
    this.valueCm,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.deletedAtEpochMs,
  });

  @Id()
  int id;

  @Index()
  String uuid;

  String measurementCode;
  int position;
  double? valueCm;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
  final tapeMeasurement = ToOne<TapeMeasurementEntity>();
}
