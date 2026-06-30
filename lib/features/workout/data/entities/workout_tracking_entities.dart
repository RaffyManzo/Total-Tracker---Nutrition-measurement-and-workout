import 'package:objectbox/objectbox.dart';

@Entity()
class RoutineEntity {
  RoutineEntity({
    this.id = 0,
    required this.uuid,
    required this.name,
    required this.slug,
    this.summary = '',
    this.goal = '',
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
  String name;

  String slug;
  String summary;
  String goal;
  String notes;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
}

@Entity()
class RoutineExerciseEntity {
  RoutineExerciseEntity({
    this.id = 0,
    required this.uuid,
    this.position = 0,
    this.exerciseUuid = '',
    required this.exerciseNameSnapshot,
    this.exerciseModeCode = 'gym',
    this.mediaSnapshot = '',
    this.restSeconds,
    this.primaryMuscleCodesJson = '[]',
    this.secondaryMuscleCodesJson = '[]',
    this.activityTargetDurationMinutes,
    this.treadmillTargetDurationMinutes,
    this.treadmillTargetDistanceKm,
    this.treadmillTargetAverageSpeedKmh,
    this.treadmillTargetAverageInclinePercent,
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
  String exerciseUuid;
  String exerciseNameSnapshot;
  String exerciseModeCode;
  String mediaSnapshot;
  int? restSeconds;
  String primaryMuscleCodesJson;
  String secondaryMuscleCodesJson;
  int? activityTargetDurationMinutes;
  int? treadmillTargetDurationMinutes;
  double? treadmillTargetDistanceKm;
  double? treadmillTargetAverageSpeedKmh;
  double? treadmillTargetAverageInclinePercent;
  String notes;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
  final routine = ToOne<RoutineEntity>();
}

@Entity()
class RoutineSetTemplateEntity {
  RoutineSetTemplateEntity({
    this.id = 0,
    required this.uuid,
    this.position = 0,
    this.setRoleCode = 'working',
    this.targetRepetitions = 8,
    this.effortTypeCode = 'rir',
    this.rir = 2,
    this.executionSpeedCode = 'normal',
    this.executionQualityCode = 'good',
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
  String setRoleCode;
  int targetRepetitions;
  String effortTypeCode;
  int? rir;
  String executionSpeedCode;
  String executionQualityCode;
  String notes;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
  final routineExercise = ToOne<RoutineExerciseEntity>();
}

@Entity()
class WorkoutPlanEntity {
  WorkoutPlanEntity({
    this.id = 0,
    required this.uuid,
    required this.name,
    this.levelCode = '',
    this.statusCode = 'draft',
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
  String name;

  String levelCode;
  String statusCode;
  String notes;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
}

@Entity()
class WorkoutPlanDayEntity {
  WorkoutPlanDayEntity({
    this.id = 0,
    required this.uuid,
    required this.dayCode,
    this.position = 0,
    required this.title,
    this.notes = '',
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.deletedAtEpochMs,
  });

  @Id()
  int id;

  @Index()
  String uuid;

  String dayCode;
  int position;
  String title;
  String notes;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
  final workoutPlan = ToOne<WorkoutPlanEntity>();
}

@Entity()
class WorkoutPlanExerciseEntity {
  WorkoutPlanExerciseEntity({
    this.id = 0,
    required this.uuid,
    this.position = 0,
    this.exerciseUuid = '',
    required this.exerciseNameSnapshot,
    this.exerciseModeCode = 'gym',
    this.setsCount,
    this.warmupSetsCount,
    this.repetitionsText = '',
    this.restSeconds,
    this.activityDurationMinutes,
    this.treadmillDurationMinutes,
    this.treadmillDistanceKm,
    this.treadmillAverageSpeedKmh,
    this.treadmillAverageInclinePercent,
    this.note = '',
    this.mediaOverride = '',
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.deletedAtEpochMs,
  });

  @Id()
  int id;

  @Index()
  String uuid;

  int position;
  String exerciseUuid;
  String exerciseNameSnapshot;
  String exerciseModeCode;
  int? setsCount;
  int? warmupSetsCount;
  String repetitionsText;
  int? restSeconds;
  int? activityDurationMinutes;
  int? treadmillDurationMinutes;
  double? treadmillDistanceKm;
  double? treadmillAverageSpeedKmh;
  double? treadmillAverageInclinePercent;
  String note;
  String mediaOverride;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
  final workoutPlanDay = ToOne<WorkoutPlanDayEntity>();
}

@Entity()
class WorkoutSessionEntity {
  WorkoutSessionEntity({
    this.id = 0,
    required this.uuid,
    required this.title,
    required this.sessionDateKey,
    this.routineUuid = '',
    this.routineNameSnapshot = '',
    this.workoutPlanUuid = '',
    this.workoutPlanDayUuid = '',
    this.statusCode = 'planned',
    this.durationMinutes,
    this.averageHeartRateBpm,
    this.estimatedKcalBurned,
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
  String sessionDateKey;

  String title;
  String routineUuid;
  String routineNameSnapshot;
  String workoutPlanUuid;
  String workoutPlanDayUuid;
  String statusCode;
  int? durationMinutes;
  int? averageHeartRateBpm;
  double? estimatedKcalBurned;
  String notes;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
}

@Entity()
class SessionExerciseEntity {
  SessionExerciseEntity({
    this.id = 0,
    required this.uuid,
    this.position = 0,
    this.exerciseUuid = '',
    required this.exerciseNameSnapshot,
    this.exerciseModeCode = 'gym',
    this.mediaSnapshot = '',
    this.restSeconds,
    this.primaryMuscleCodesJson = '[]',
    this.secondaryMuscleCodesJson = '[]',
    this.activityDurationMinutes,
    this.activityAverageHeartRateBpm,
    this.activityKcalBurned,
    this.treadmillDurationMinutes,
    this.treadmillDistanceKm,
    this.treadmillAverageSpeedKmh,
    this.treadmillAverageInclinePercent,
    this.treadmillAverageHeartRateBpm,
    this.isCompleted = false,
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
  String exerciseUuid;
  String exerciseNameSnapshot;
  String exerciseModeCode;
  String mediaSnapshot;
  int? restSeconds;
  String primaryMuscleCodesJson;
  String secondaryMuscleCodesJson;
  int? activityDurationMinutes;
  int? activityAverageHeartRateBpm;
  double? activityKcalBurned;
  int? treadmillDurationMinutes;
  double? treadmillDistanceKm;
  double? treadmillAverageSpeedKmh;
  double? treadmillAverageInclinePercent;
  int? treadmillAverageHeartRateBpm;
  bool isCompleted;
  String notes;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
  final workoutSession = ToOne<WorkoutSessionEntity>();
}

@Entity()
class SessionSetEntity {
  SessionSetEntity({
    this.id = 0,
    required this.uuid,
    this.position = 0,
    this.setRoleCode = 'working',
    this.targetRepetitions,
    this.repetitionsDone,
    this.weightKg,
    this.previousRepetitionsDone,
    this.previousWeightKg,
    this.previousEffortTypeCode = '',
    this.previousRir,
    this.previousExecutionSpeedCode = '',
    this.previousExecutionQualityCode = '',
    this.effortTypeCode = 'rir',
    this.rir,
    this.executionSpeedCode = 'normal',
    this.executionQualityCode = 'good',
    this.setNote = '',
    this.isCompleted = false,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.deletedAtEpochMs,
  });

  @Id()
  int id;

  @Index()
  String uuid;

  int position;
  String setRoleCode;
  int? targetRepetitions;
  int? repetitionsDone;
  double? weightKg;
  int? previousRepetitionsDone;
  double? previousWeightKg;
  String previousEffortTypeCode;
  int? previousRir;
  String previousExecutionSpeedCode;
  String previousExecutionQualityCode;
  String effortTypeCode;
  int? rir;
  String executionSpeedCode;
  String executionQualityCode;
  String setNote;
  bool isCompleted;
  int createdAtEpochMs;
  int updatedAtEpochMs;
  int? deletedAtEpochMs;
  final sessionExercise = ToOne<SessionExerciseEntity>();
}
