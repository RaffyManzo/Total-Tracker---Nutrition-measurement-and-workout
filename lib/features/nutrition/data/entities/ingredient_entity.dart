import 'package:objectbox/objectbox.dart';

import '../../domain/nutrition_codes.dart';

@Entity()
class IngredientEntity {
  IngredientEntity({
    this.id = 0,
    required this.uuid,
    required this.name,
    this.brand = '',
    this.baseUnit = NutritionUnitCodes.grams,
    this.barcode = '',
    this.packageQuantity,
    this.sourceTypeCode = IngredientSourceTypeCodes.manual,
    this.sourceName = '',
    this.sourceUrl = '',
    this.sourceExternalId = '',
    this.sourceDatasetVersion = '',
    this.sourceLicenseCode = '',
    this.sourceAttribution = '',
    this.wasModifiedByUser = false,
    this.imageUrl = '',
    this.categories = '',
    this.notes = '',
    this.nutritionReferenceAmount = 100,
    this.nutritionReferenceUnitCode = NutritionUnitCodes.grams,
    this.kcalPerReference = 0,
    this.proteinPerReference = 0,
    this.carbsPerReference = 0,
    this.fatPerReference = 0,
    this.fiberPerReference = 0,
    this.sugarPerReference = 0,
    this.saltPerReference = 0,
    this.isArchived = false,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.deletedAtEpochMs,
  });

  @Id()
  int id;

  @Unique()
  String uuid;

  @Index()
  String name;

  String brand;
  String baseUnit;

  @Index()
  String barcode;

  double? packageQuantity;

  String sourceTypeCode;
  String sourceName;
  String sourceUrl;
  String sourceExternalId;
  String sourceDatasetVersion;
  String sourceLicenseCode;
  String sourceAttribution;
  bool wasModifiedByUser;
  String imageUrl;
  String categories;
  String notes;

  double nutritionReferenceAmount;
  String nutritionReferenceUnitCode;

  double kcalPerReference;
  double proteinPerReference;
  double carbsPerReference;
  double fatPerReference;
  double fiberPerReference;
  double sugarPerReference;
  double saltPerReference;

  bool isArchived;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
}
