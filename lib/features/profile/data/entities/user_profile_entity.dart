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
    this.defaultStepGoal = 8000,
    this.defaultTargetKcal = 1980,
    this.waterGlassLiters = 0.25,
    this.stepKcalCoefficient = 0.025,
    this.adaptiveReferenceDays = 28,
    this.adaptiveMinimumObservedDays = 7,
    this.rmrActivityFactor = 1.10,
    this.kcalPerKg = 7700,
    this.minimumReasonableTdee = 1300,
    this.maximumReasonableTdee = 4600,
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

  int defaultStepGoal;
  int defaultTargetKcal;
  double waterGlassLiters;
  double stepKcalCoefficient;

  int adaptiveReferenceDays;
  int adaptiveMinimumObservedDays;
  double rmrActivityFactor;
  double kcalPerKg;
  double minimumReasonableTdee;
  double maximumReasonableTdee;

  bool isActive;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
}
