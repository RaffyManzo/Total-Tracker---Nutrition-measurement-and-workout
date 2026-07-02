import 'package:objectbox/objectbox.dart';

@Entity()
class OpenNutritionFoodEntity {
  OpenNutritionFoodEntity({
    this.id = 0,
    required this.externalFoodId,
    required this.importBatchId,
    required this.datasetVersion,
    required this.name,
    required this.normalizedName,
    this.alternateNamesJson = '[]',
    this.description = '',
    this.typeCode = '',
    this.brand = '',
    this.normalizedBrand = '',
    this.barcode = '',
    this.labelsJson = '[]',
    this.ingredientsText = '',
    this.ingredientAnalysisJson = '{}',
    this.sourceJson = '{}',
    this.servingJson = '{}',
    this.packageSizeJson = '{}',
    this.nutrition100gJson = '{}',
    this.additionalFieldsJson = '{}',
    this.normalizedSearchText = '',
    this.kcalPer100g = 0,
    this.proteinPer100g = 0,
    this.carbsPer100g = 0,
    this.fatPer100g = 0,
    this.fiberPer100g = 0,
    this.sugarPer100g = 0,
    this.saturatedFatPer100g = 0,
    this.transFatPer100g = 0,
    this.saltPer100g = 0,
    this.sodiumPer100g = 0,
    this.hasCompleteMacros = false,
    this.hasEstimatedValues = false,
    this.fromOpenFoodFacts = false,
    required this.importedAtEpochMs,
  });

  @Id()
  int id;

  @Index()
  String externalFoodId;

  @Index()
  String importBatchId;

  String datasetVersion;

  @Index()
  String name;

  @Index()
  String normalizedName;

  String alternateNamesJson;
  String description;

  @Index()
  String typeCode;

  String brand;

  @Index()
  String normalizedBrand;

  @Index()
  String barcode;

  String labelsJson;
  String ingredientsText;
  String ingredientAnalysisJson;
  String sourceJson;
  String servingJson;
  String packageSizeJson;
  String nutrition100gJson;
  String additionalFieldsJson;

  @Index()
  String normalizedSearchText;

  double kcalPer100g;
  double proteinPer100g;
  double carbsPer100g;
  double fatPer100g;
  double fiberPer100g;
  double sugarPer100g;
  double saturatedFatPer100g;
  double transFatPer100g;
  double saltPer100g;
  double sodiumPer100g;
  bool hasCompleteMacros;
  bool hasEstimatedValues;
  bool fromOpenFoodFacts;
  int importedAtEpochMs;
}
