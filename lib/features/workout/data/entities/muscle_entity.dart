import 'package:objectbox/objectbox.dart';

@Entity()
class MuscleEntity {
  MuscleEntity({
    this.id = 0,
    required this.uuid,
    required this.code,
    required this.displayNameIt,
    required this.displayNameEn,
    required this.groupCode,
    required this.bodyRegionCode,
    required this.sortOrder,
    this.isActive = true,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.deletedAtEpochMs,
  });

  @Id()
  int id;

  @Unique()
  String uuid;

  @Unique()
  String code;

  String displayNameIt;
  String displayNameEn;
  String groupCode;
  String bodyRegionCode;
  int sortOrder;
  bool isActive;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
}
