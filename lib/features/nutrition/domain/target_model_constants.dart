class TargetModelConstants {
  const TargetModelConstants._();

  static const String logicalPatchId = '0.1.0_01_theo';
  static const String modelVersion = 'target-model-0.1.0-theo.2';
  static const String formulaSourcesVersion = 'target-sources-0.1.0-theo.2';
  static const String effectiveDate = '2026-07-06';

  static const String rmrEquation = 'mifflin_st_jeor';
  static const double rmrMaleConstant = 5;
  static const double rmrFemaleConstant = -161;
  static const double rmrUnspecifiedConstant = -78;

  static const double rmrActivityFactor = 1.10;
  static const String rmrActivityFactorStatus = 'stalled';
  static const String rmrActivityFactorSource = 'internal_legacy_heuristic';

  static const double stepLengthHeightFactor = 0.0042;
  static const double netWalkingCostKcalPerKgKm = 0.50;
  static const double legacyStepKcalCoefficient = 0.020;
  static const int defaultStepGoal = 8000;
  static const String stepsExclusionPolicyVersion = 'steps-exclusion-policy-1';

  static const int adaptiveWindowDays = 28;
  static const double energyDensityPriorKcalPerKg = 7700;
  static const double fatMassEnergyDensityKcalPerKg = 9500;
  static const double fatFreeMassEnergyDensityKcalPerKg = 1020;

  static const double proteinDefaultGramsPerKg = 1.8;
  static const double proteinMinimumGramsPerKg = 1.4;
  static const double proteinMaximumGramsPerKg = 2.2;
  static const double fatDefaultEnergyPercent = 25;
  static const double fatMinimumEnergyPercent = 20;
  static const double fatMaximumEnergyPercent = 35;
  static const double fiberMinimumGrams = 25;
  static const double fiberGramsPer1000Kcal = 14;
  static const double freeSugarLimitEnergyPercent = 10;
  static const double freeSugarPreferredEnergyPercent = 5;

  static const double proteinKcalPerGram = 4;
  static const double carbohydrateKcalPerGram = 4;
  static const double fatKcalPerGram = 9;

  static const double minimumReasonableTdee = 1300;
  static const double maximumReasonableTdee = 4600;
}
