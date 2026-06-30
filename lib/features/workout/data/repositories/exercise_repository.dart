import 'package:objectbox/objectbox.dart';

import '../../../../core/identifiers/uuid_generator.dart';
import '../../../../core/time/clock.dart';
import '../../domain/workout_codes.dart';
import '../entities/exercise_entity.dart';
import '../entities/exercise_muscle_link_entity.dart';
import '../entities/muscle_entity.dart';

class ExerciseRepository {
  ExerciseRepository(
    Store store, {
    Clock clock = const Clock(),
    UuidGenerator? uuidGenerator,
  })  : _store = store,
        _clock = clock,
        _uuidGenerator = uuidGenerator ?? UuidGenerator();

  final Store _store;
  final Clock _clock;
  final UuidGenerator _uuidGenerator;

  Box<ExerciseEntity> get _exerciseBox => _store.box<ExerciseEntity>();
  Box<MuscleEntity> get _muscleBox => _store.box<MuscleEntity>();
  Box<ExerciseMuscleLinkEntity> get _linkBox {
    return _store.box<ExerciseMuscleLinkEntity>();
  }

  ExerciseEntity save(ExerciseEntity exercise) {
    _normalize(exercise);
    _validate(exercise);
    _prepareForSave(exercise);
    exercise.id = _exerciseBox.put(exercise);
    return exercise;
  }

  ExerciseEntity? findByUuid(String uuid) {
    for (final ExerciseEntity exercise in _exerciseBox.getAll()) {
      if (exercise.uuid == uuid && exercise.deletedAtEpochMs == null) {
        return exercise;
      }
    }
    return null;
  }

  ExerciseEntity? getById(int id) {
    final ExerciseEntity? exercise = _exerciseBox.get(id);
    if (exercise == null || exercise.deletedAtEpochMs != null) {
      return null;
    }
    return exercise;
  }

  List<ExerciseEntity> searchByName(String query) {
    final String normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return getAllActive();
    }

    return getAllActive()
        .where(
          (ExerciseEntity exercise) =>
              exercise.name.toLowerCase().contains(normalizedQuery),
        )
        .toList()
      ..sort(_sortByName);
  }

  List<ExerciseEntity> getByMode(String modeCode) {
    if (!ExerciseModeCodes.values.contains(modeCode)) {
      throw ArgumentError.value(
        modeCode,
        'modeCode',
        'Unsupported exercise mode code.',
      );
    }
    return getAllActive()
        .where(
            (ExerciseEntity exercise) => exercise.exerciseModeCode == modeCode)
        .toList()
      ..sort(_sortByName);
  }

  List<ExerciseEntity> getAllActive() {
    return _exerciseBox
        .getAll()
        .where(
          (ExerciseEntity exercise) =>
              !exercise.isArchived && exercise.deletedAtEpochMs == null,
        )
        .toList()
      ..sort(_sortByName);
  }

  ExerciseEntity archive(ExerciseEntity exercise) {
    _ensureExists(exercise);
    exercise.isArchived = true;
    exercise.updatedAtEpochMs = _clock.nowEpochMs();
    exercise.id = _exerciseBox.put(exercise);
    return exercise;
  }

  ExerciseEntity softDelete(ExerciseEntity exercise) {
    _ensureExists(exercise);
    return _store.runInTransaction(TxMode.write, () {
      final int nowEpochMs = _clock.nowEpochMs();
      exercise.isArchived = true;
      exercise.deletedAtEpochMs ??= nowEpochMs;
      exercise.updatedAtEpochMs = nowEpochMs;
      exercise.id = _exerciseBox.put(exercise);

      final List<ExerciseMuscleLinkEntity> links =
          _linksForExercise(exercise.id);
      for (final ExerciseMuscleLinkEntity link in links) {
        link.deletedAtEpochMs ??= nowEpochMs;
        link.updatedAtEpochMs = nowEpochMs;
      }
      if (links.isNotEmpty) {
        _linkBox.putMany(links);
      }
      return exercise;
    });
  }

  void replaceMuscles(
    int exerciseId,
    List<int> primaryMuscleIds,
    List<int> secondaryMuscleIds,
  ) {
    _store.runInTransaction(TxMode.write, () {
      final ExerciseEntity exercise = _requireExercise(exerciseId);
      final List<MuscleEntity> primaryMuscles =
          _requireUniqueMuscles(primaryMuscleIds, MuscleRoleCodes.primary);
      final List<MuscleEntity> secondaryMuscles =
          _requireUniqueMuscles(secondaryMuscleIds, MuscleRoleCodes.secondary);

      final Set<int> primaryIds =
          primaryMuscles.map((MuscleEntity muscle) => muscle.id).toSet();
      for (final MuscleEntity muscle in secondaryMuscles) {
        if (primaryIds.contains(muscle.id)) {
          throw ArgumentError.value(
            muscle.id,
            'secondaryMuscleIds',
            'A muscle cannot be both primary and secondary.',
          );
        }
      }

      final List<int> oldLinkIds = _linksForExercise(exerciseId)
          .map((ExerciseMuscleLinkEntity link) => link.id)
          .toList();
      if (oldLinkIds.isNotEmpty) {
        _linkBox.removeMany(oldLinkIds);
      }

      final List<ExerciseMuscleLinkEntity> newLinks =
          <ExerciseMuscleLinkEntity>[];
      for (int index = 0; index < primaryMuscles.length; index += 1) {
        newLinks.add(
          _createLink(
            exercise: exercise,
            muscle: primaryMuscles[index],
            roleCode: MuscleRoleCodes.primary,
            position: index,
          ),
        );
      }
      for (int index = 0; index < secondaryMuscles.length; index += 1) {
        newLinks.add(
          _createLink(
            exercise: exercise,
            muscle: secondaryMuscles[index],
            roleCode: MuscleRoleCodes.secondary,
            position: index,
          ),
        );
      }
      if (newLinks.isNotEmpty) {
        _linkBox.putMany(newLinks);
      }
    });
  }

  List<MuscleEntity> getPrimaryMuscles(int exerciseId) {
    return _getMusclesByRole(exerciseId, MuscleRoleCodes.primary);
  }

  List<MuscleEntity> getSecondaryMuscles(int exerciseId) {
    return _getMusclesByRole(exerciseId, MuscleRoleCodes.secondary);
  }

  List<ExerciseEntity> getExercisesByMuscle(int muscleId) {
    final Set<int> exerciseIds = <int>{};
    for (final ExerciseMuscleLinkEntity link in _activeLinks()) {
      if (link.muscle.targetId == muscleId) {
        exerciseIds.add(link.exercise.targetId);
      }
    }

    final List<ExerciseEntity> exercises = <ExerciseEntity>[];
    for (final int exerciseId in exerciseIds) {
      final ExerciseEntity? exercise = getById(exerciseId);
      if (exercise != null && !exercise.isArchived) {
        exercises.add(exercise);
      }
    }
    return exercises..sort(_sortByName);
  }

  void _ensureExists(ExerciseEntity exercise) {
    if (exercise.id == 0 || _exerciseBox.get(exercise.id) == null) {
      throw ArgumentError.value(exercise.id, 'id', 'Exercise does not exist.');
    }
  }

  ExerciseEntity _requireExercise(int exerciseId) {
    final ExerciseEntity? exercise = getById(exerciseId);
    if (exercise == null) {
      throw ArgumentError.value(
          exerciseId, 'exerciseId', 'Exercise not found.');
    }
    return exercise;
  }

  List<MuscleEntity> _requireUniqueMuscles(
    List<int> muscleIds,
    String roleCode,
  ) {
    final Set<int> uniqueIds = <int>{};
    final List<MuscleEntity> muscles = <MuscleEntity>[];
    for (final int muscleId in muscleIds) {
      if (!uniqueIds.add(muscleId)) {
        throw ArgumentError.value(
          muscleId,
          '${roleCode}MuscleIds',
          'Duplicate muscle id.',
        );
      }

      final MuscleEntity? muscle = _muscleBox.get(muscleId);
      if (muscle == null ||
          !muscle.isActive ||
          muscle.deletedAtEpochMs != null) {
        throw ArgumentError.value(
          muscleId,
          '${roleCode}MuscleIds',
          'Muscle not found or inactive.',
        );
      }
      muscles.add(muscle);
    }
    return muscles;
  }

  ExerciseMuscleLinkEntity _createLink({
    required ExerciseEntity exercise,
    required MuscleEntity muscle,
    required String roleCode,
    required int position,
  }) {
    final int nowEpochMs = _clock.nowEpochMs();
    final ExerciseMuscleLinkEntity link = ExerciseMuscleLinkEntity(
      uuid: _uuidGenerator.generate(),
      roleCode: roleCode,
      position: position,
      createdAtEpochMs: nowEpochMs,
      updatedAtEpochMs: nowEpochMs,
    );
    link.exercise.target = exercise;
    link.muscle.target = muscle;
    return link;
  }

  List<MuscleEntity> _getMusclesByRole(int exerciseId, String roleCode) {
    final List<ExerciseMuscleLinkEntity> links = _activeLinks()
        .where(
          (ExerciseMuscleLinkEntity link) =>
              link.exercise.targetId == exerciseId && link.roleCode == roleCode,
        )
        .toList()
      ..sort(
        (ExerciseMuscleLinkEntity a, ExerciseMuscleLinkEntity b) =>
            a.position.compareTo(b.position),
      );

    final List<MuscleEntity> muscles = <MuscleEntity>[];
    for (final ExerciseMuscleLinkEntity link in links) {
      final MuscleEntity? muscle = _muscleBox.get(link.muscle.targetId);
      if (muscle != null &&
          muscle.isActive &&
          muscle.deletedAtEpochMs == null) {
        muscles.add(muscle);
      }
    }
    return muscles;
  }

  List<ExerciseMuscleLinkEntity> _linksForExercise(int exerciseId) {
    return _linkBox
        .getAll()
        .where(
          (ExerciseMuscleLinkEntity link) =>
              link.exercise.targetId == exerciseId,
        )
        .toList();
  }

  List<ExerciseMuscleLinkEntity> _activeLinks() {
    return _linkBox
        .getAll()
        .where(
          (ExerciseMuscleLinkEntity link) => link.deletedAtEpochMs == null,
        )
        .toList();
  }

  void _prepareForSave(ExerciseEntity exercise) {
    final int nowEpochMs = _clock.nowEpochMs();
    if (exercise.uuid.trim().isEmpty) {
      exercise.uuid = _uuidGenerator.generate();
    }
    if (exercise.createdAtEpochMs == 0) {
      exercise.createdAtEpochMs = nowEpochMs;
    }
    exercise.updatedAtEpochMs = nowEpochMs;
  }

  void _normalize(ExerciseEntity exercise) {
    exercise.name = exercise.name.trim();
    exercise.exerciseModeCode = exercise.exerciseModeCode.trim();
    exercise.mediaPath = exercise.mediaPath.trim();
    exercise.notes = exercise.notes.trim();
  }

  void _validate(ExerciseEntity exercise) {
    if (exercise.name.isEmpty) {
      throw ArgumentError.value(exercise.name, 'name', 'Name is required.');
    }
    if (!ExerciseModeCodes.values.contains(exercise.exerciseModeCode)) {
      throw ArgumentError.value(
        exercise.exerciseModeCode,
        'exerciseModeCode',
        'Unsupported exercise mode code.',
      );
    }
    if (exercise.defaultRestSec != null && exercise.defaultRestSec! < 0) {
      throw ArgumentError.value(
        exercise.defaultRestSec,
        'defaultRestSec',
        'Default rest cannot be negative.',
      );
    }
  }

  int _sortByName(ExerciseEntity a, ExerciseEntity b) {
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
}
