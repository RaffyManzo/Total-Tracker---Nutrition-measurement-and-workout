import 'package:objectbox/objectbox.dart';

import '../../../../core/identifiers/uuid_generator.dart';
import '../../../../core/time/clock.dart';
import '../entities/workout_tracking_entities.dart';

class WorkoutPlanDetails {
  const WorkoutPlanDetails({
    required this.plan,
    required this.days,
    required this.exercisesByDayId,
  });

  final WorkoutPlanEntity plan;
  final List<WorkoutPlanDayEntity> days;
  final Map<int, List<WorkoutPlanExerciseEntity>> exercisesByDayId;
}

class WorkoutPlanRepository {
  WorkoutPlanRepository(
    Store store, {
    Clock clock = const Clock(),
    UuidGenerator? uuidGenerator,
  })  : _store = store,
        _clock = clock,
        _uuidGenerator = uuidGenerator ?? UuidGenerator();

  final Store _store;
  final Clock _clock;
  final UuidGenerator _uuidGenerator;

  Box<WorkoutPlanEntity> get _planBox => _store.box<WorkoutPlanEntity>();
  Box<WorkoutPlanDayEntity> get _dayBox {
    return _store.box<WorkoutPlanDayEntity>();
  }

  Box<WorkoutPlanExerciseEntity> get _exerciseBox {
    return _store.box<WorkoutPlanExerciseEntity>();
  }

  WorkoutPlanEntity save(WorkoutPlanEntity plan) {
    _normalize(plan);
    _validate(plan);
    _preparePlan(plan);
    plan.id = _planBox.put(plan);
    return plan;
  }

  WorkoutPlanEntity? getById(int id) {
    final WorkoutPlanEntity? plan = _planBox.get(id);
    if (plan == null || plan.deletedAtEpochMs != null) {
      return null;
    }
    return plan;
  }

  WorkoutPlanDetails? getDetails(int id) {
    final WorkoutPlanEntity? plan = getById(id);
    if (plan == null) {
      return null;
    }
    final List<WorkoutPlanDayEntity> days = getDays(id);
    return WorkoutPlanDetails(
      plan: plan,
      days: days,
      exercisesByDayId: <int, List<WorkoutPlanExerciseEntity>>{
        for (final WorkoutPlanDayEntity day in days)
          day.id: getExercises(day.id),
      },
    );
  }

  List<WorkoutPlanEntity> getAllActive() {
    return _planBox
        .getAll()
        .where((WorkoutPlanEntity plan) => plan.deletedAtEpochMs == null)
        .toList()
      ..sort((WorkoutPlanEntity a, WorkoutPlanEntity b) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  List<WorkoutPlanDayEntity> getDays(int planId) {
    return _dayBox
        .getAll()
        .where(
          (WorkoutPlanDayEntity day) =>
              day.workoutPlan.targetId == planId &&
              day.deletedAtEpochMs == null,
        )
        .toList()
      ..sort((WorkoutPlanDayEntity a, WorkoutPlanDayEntity b) {
        return a.position.compareTo(b.position);
      });
  }

  List<WorkoutPlanExerciseEntity> getExercises(int dayId) {
    return _exerciseBox
        .getAll()
        .where(
          (WorkoutPlanExerciseEntity exercise) =>
              exercise.workoutPlanDay.targetId == dayId &&
              exercise.deletedAtEpochMs == null,
        )
        .toList()
      ..sort((WorkoutPlanExerciseEntity a, WorkoutPlanExerciseEntity b) {
        return a.position.compareTo(b.position);
      });
  }

  int exerciseCountForPlan(int planId) {
    int count = 0;
    for (final WorkoutPlanDayEntity day in getDays(planId)) {
      count += getExercises(day.id).length;
    }
    return count;
  }

  void _preparePlan(WorkoutPlanEntity plan) {
    final int now = _clock.nowEpochMs();
    if (plan.uuid.trim().isEmpty) {
      plan.uuid = _uuidGenerator.generate();
    }
    if (plan.createdAtEpochMs == 0) {
      plan.createdAtEpochMs = now;
    }
    plan.updatedAtEpochMs = now;
  }

  void _normalize(WorkoutPlanEntity plan) {
    plan.name = plan.name.trim();
    plan.levelCode = plan.levelCode.trim();
    plan.statusCode =
        plan.statusCode.trim().isEmpty ? 'draft' : plan.statusCode.trim();
    plan.notes = plan.notes.trim();
  }

  void _validate(WorkoutPlanEntity plan) {
    if (plan.name.isEmpty) {
      throw ArgumentError.value(plan.name, 'name', 'Name is required.');
    }
  }
}
