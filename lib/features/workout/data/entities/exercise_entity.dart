import 'package:objectbox/objectbox.dart';

import '../../domain/workout_codes.dart';

@Entity()
class ExerciseEntity {
  ExerciseEntity({
    this.id = 0,
    required this.uuid,
    required this.name,
    this.exerciseModeCode = ExerciseModeCodes.gym,
    this.mediaPath = '',
    this.defaultRestSec,
    this.notes = '',
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

  @Index()
  String exerciseModeCode;

  String mediaPath;
  int? defaultRestSec;
  String notes;

  bool isArchived;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
}
