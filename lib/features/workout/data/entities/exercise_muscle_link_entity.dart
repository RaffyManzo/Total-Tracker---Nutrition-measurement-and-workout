import 'package:objectbox/objectbox.dart';

import '../../domain/workout_codes.dart';
import 'exercise_entity.dart';
import 'muscle_entity.dart';

@Entity()
class ExerciseMuscleLinkEntity {
  ExerciseMuscleLinkEntity({
    this.id = 0,
    required this.uuid,
    this.roleCode = MuscleRoleCodes.primary,
    this.position = 0,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.deletedAtEpochMs,
  });

  @Id()
  int id;

  @Unique()
  String uuid;

  final ToOne<ExerciseEntity> exercise = ToOne<ExerciseEntity>();
  final ToOne<MuscleEntity> muscle = ToOne<MuscleEntity>();

  String roleCode;
  int position;

  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
}
