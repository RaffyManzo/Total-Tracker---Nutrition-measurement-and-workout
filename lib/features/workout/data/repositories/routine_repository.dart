import 'package:objectbox/objectbox.dart';

import '../../../../core/identifiers/uuid_generator.dart';
import '../../../../core/time/clock.dart';
import '../entities/workout_tracking_entities.dart';

class RoutineDetails {
  const RoutineDetails({
    required this.routine,
    required this.exercises,
    required this.setsByExerciseId,
  });

  final RoutineEntity routine;
  final List<RoutineExerciseEntity> exercises;
  final Map<int, List<RoutineSetTemplateEntity>> setsByExerciseId;
}

class RoutineRepository {
  RoutineRepository(
    Store store, {
    Clock clock = const Clock(),
    UuidGenerator? uuidGenerator,
  })  : _store = store,
        _clock = clock,
        _uuidGenerator = uuidGenerator ?? UuidGenerator();

  final Store _store;
  final Clock _clock;
  final UuidGenerator _uuidGenerator;

  Box<RoutineEntity> get _routineBox => _store.box<RoutineEntity>();
  Box<RoutineExerciseEntity> get _exerciseBox {
    return _store.box<RoutineExerciseEntity>();
  }

  Box<RoutineSetTemplateEntity> get _setBox {
    return _store.box<RoutineSetTemplateEntity>();
  }

  RoutineEntity save(RoutineEntity routine) {
    _normalize(routine);
    _validate(routine);
    _prepareRoutine(routine);
    routine.id = _routineBox.put(routine);
    return routine;
  }

  RoutineEntity? getById(int id) {
    final RoutineEntity? routine = _routineBox.get(id);
    if (routine == null || routine.deletedAtEpochMs != null) {
      return null;
    }
    return routine;
  }

  RoutineDetails? getDetails(int id) {
    final RoutineEntity? routine = getById(id);
    if (routine == null) {
      return null;
    }
    final List<RoutineExerciseEntity> exercises = getExercises(id);
    return RoutineDetails(
      routine: routine,
      exercises: exercises,
      setsByExerciseId: <int, List<RoutineSetTemplateEntity>>{
        for (final RoutineExerciseEntity exercise in exercises)
          exercise.id: getSets(exercise.id),
      },
    );
  }

  List<RoutineEntity> getAllActive() {
    return _routineBox
        .getAll()
        .where((RoutineEntity routine) => routine.deletedAtEpochMs == null)
        .toList()
      ..sort((RoutineEntity a, RoutineEntity b) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  List<RoutineExerciseEntity> getExercises(int routineId) {
    return _exerciseBox
        .getAll()
        .where(
          (RoutineExerciseEntity exercise) =>
              exercise.routine.targetId == routineId &&
              exercise.deletedAtEpochMs == null,
        )
        .toList()
      ..sort((RoutineExerciseEntity a, RoutineExerciseEntity b) {
        return a.position.compareTo(b.position);
      });
  }

  List<RoutineSetTemplateEntity> getSets(int routineExerciseId) {
    return _setBox
        .getAll()
        .where(
          (RoutineSetTemplateEntity set) =>
              set.routineExercise.targetId == routineExerciseId &&
              set.deletedAtEpochMs == null,
        )
        .toList()
      ..sort((RoutineSetTemplateEntity a, RoutineSetTemplateEntity b) {
        return a.position.compareTo(b.position);
      });
  }

  void _prepareRoutine(RoutineEntity routine) {
    final int now = _clock.nowEpochMs();
    if (routine.uuid.trim().isEmpty) {
      routine.uuid = _uuidGenerator.generate();
    }
    if (routine.createdAtEpochMs == 0) {
      routine.createdAtEpochMs = now;
    }
    routine.updatedAtEpochMs = now;
  }

  void _normalize(RoutineEntity routine) {
    routine.name = routine.name.trim();
    routine.slug = routine.slug.trim().isEmpty
        ? routine.name.toLowerCase().replaceAll(RegExp(r'\s+'), '-')
        : routine.slug.trim();
    routine.summary = routine.summary.trim();
    routine.goal = routine.goal.trim();
    routine.notes = routine.notes.trim();
  }

  void _validate(RoutineEntity routine) {
    if (routine.name.isEmpty) {
      throw ArgumentError.value(routine.name, 'name', 'Name is required.');
    }
  }
}
