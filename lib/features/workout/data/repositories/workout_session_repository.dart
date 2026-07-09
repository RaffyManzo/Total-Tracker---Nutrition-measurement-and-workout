import '../../../../core/identifiers/uuid_generator.dart';
import '../../../../core/time/clock.dart';
import '../../../../objectbox.g.dart';
import '../entities/workout_tracking_entities.dart';
import '../../../nutrition/data/services/target_input_change_bus.dart';
import '../../../nutrition/data/services/target_input_mutation_service.dart';

class WorkoutSessionDetails {
  const WorkoutSessionDetails({
    required this.session,
    required this.exercises,
    required this.setsByExerciseId,
  });

  final WorkoutSessionEntity session;
  final List<SessionExerciseEntity> exercises;
  final Map<int, List<SessionSetEntity>> setsByExerciseId;
}

class WorkoutSessionRepository {
  WorkoutSessionRepository(
    Store store, {
    Clock clock = const Clock(),
    UuidGenerator? uuidGenerator,
  })  : _store = store,
        _clock = clock,
        _uuidGenerator = uuidGenerator ?? UuidGenerator();

  final Store _store;
  final Clock _clock;
  final UuidGenerator _uuidGenerator;

  Box<WorkoutSessionEntity> get _sessionBox {
    return _store.box<WorkoutSessionEntity>();
  }

  Box<SessionExerciseEntity> get _exerciseBox {
    return _store.box<SessionExerciseEntity>();
  }

  Box<SessionSetEntity> get _setBox => _store.box<SessionSetEntity>();

  WorkoutSessionEntity save(WorkoutSessionEntity session) {
    _normalize(session);
    _validate(session);
    _prepareSession(session);
    _store.runInTransaction(TxMode.write, () {
      session.id = _sessionBox.put(session);
      TargetInputMutationService.enqueueInCurrentTransaction(
        _store,
        kind: TargetInputChangeKind.workout,
        fromDateKey: session.sessionDateKey,
        reasonCode: 'workout_active_calories_changed',
        sourceEntityUuid: session.uuid,
        sourceRevision: session.updatedAtEpochMs,
      );
    });
    TargetInputMutationService.publishAfterCommit(
      kind: TargetInputChangeKind.workout,
      fromDateKey: session.sessionDateKey,
      reasonCode: 'workout_active_calories_changed',
      sourceEntityUuid: session.uuid,
      sourceRevision: session.updatedAtEpochMs,
    );
    return session;
  }

  WorkoutSessionEntity? getById(int id) {
    final WorkoutSessionEntity? session = _sessionBox.get(id);
    if (session == null || session.deletedAtEpochMs != null) {
      return null;
    }
    return session;
  }

  WorkoutSessionDetails? getDetails(int id) {
    final WorkoutSessionEntity? session = getById(id);
    if (session == null) {
      return null;
    }
    final List<SessionExerciseEntity> exercises = getExercises(id);
    return WorkoutSessionDetails(
      session: session,
      exercises: exercises,
      setsByExerciseId: <int, List<SessionSetEntity>>{
        for (final SessionExerciseEntity exercise in exercises)
          exercise.id: getSets(exercise.id),
      },
    );
  }

  List<WorkoutSessionEntity> getAllActive() {
    return _sessionBox
        .getAll()
        .where((WorkoutSessionEntity item) => item.deletedAtEpochMs == null)
        .toList()
      ..sort((WorkoutSessionEntity a, WorkoutSessionEntity b) {
        return b.sessionDateKey.compareTo(a.sessionDateKey);
      });
  }

  List<WorkoutSessionEntity> recent({int limit = 5}) {
    final List<WorkoutSessionEntity> sessions = getAllActive();
    return sessions.take(limit).toList();
  }

  WorkoutSessionEntity? latest() {
    final List<WorkoutSessionEntity> sessions = getAllActive();
    return sessions.isEmpty ? null : sessions.first;
  }

  List<WorkoutSessionEntity> completedForDate(String dateKey) {
    return getAllActive()
        .where(
          (WorkoutSessionEntity session) =>
              session.sessionDateKey == dateKey &&
              session.statusCode == 'completed',
        )
        .toList();
  }

  double completedKcalForDate(String dateKey) {
    return completedForDate(dateKey).fold<double>(
      0,
      (double sum, WorkoutSessionEntity session) =>
          sum + (session.estimatedKcalBurned ?? 0),
    );
  }

  int activeWorkoutInputRevision() {
    final Query<WorkoutSessionEntity> query = _sessionBox
        .query(WorkoutSessionEntity_.deletedAtEpochMs.isNull())
        .build();
    final PropertyQuery<int> propertyQuery =
        query.property(WorkoutSessionEntity_.updatedAtEpochMs);
    try {
      if (propertyQuery.count() == 0) {
        return 0;
      }
      return propertyQuery.max();
    } finally {
      propertyQuery.close();
      query.close();
    }
  }

  List<SessionExerciseEntity> getExercises(int sessionId) {
    return _exerciseBox
        .getAll()
        .where(
          (SessionExerciseEntity exercise) =>
              exercise.workoutSession.targetId == sessionId &&
              exercise.deletedAtEpochMs == null,
        )
        .toList()
      ..sort((SessionExerciseEntity a, SessionExerciseEntity b) {
        return a.position.compareTo(b.position);
      });
  }

  List<SessionSetEntity> getSets(int sessionExerciseId) {
    return _setBox
        .getAll()
        .where(
          (SessionSetEntity set) =>
              set.sessionExercise.targetId == sessionExerciseId &&
              set.deletedAtEpochMs == null,
        )
        .toList()
      ..sort((SessionSetEntity a, SessionSetEntity b) {
        return a.position.compareTo(b.position);
      });
  }

  WorkoutSessionEntity createEmpty(String dateKey) {
    final int now = _clock.nowEpochMs();
    return WorkoutSessionEntity(
      uuid: '',
      title: 'Sessione - $dateKey',
      sessionDateKey: dateKey,
      statusCode: 'planned',
      createdAtEpochMs: now,
      updatedAtEpochMs: now,
    );
  }

  void _prepareSession(WorkoutSessionEntity session) {
    final int now = _clock.nowEpochMs();
    if (session.uuid.trim().isEmpty) {
      session.uuid = _uuidGenerator.generate();
    }
    if (session.createdAtEpochMs == 0) {
      session.createdAtEpochMs = now;
    }
    session.updatedAtEpochMs = now;
  }

  void _normalize(WorkoutSessionEntity session) {
    session.title = session.title.trim();
    session.sessionDateKey = session.sessionDateKey.trim();
    session.statusCode = session.statusCode.trim().isEmpty
        ? 'unknown'
        : session.statusCode.trim();
    session.notes = session.notes.trim();
  }

  void _validate(WorkoutSessionEntity session) {
    if (session.title.isEmpty) {
      throw ArgumentError.value(session.title, 'title', 'Title is required.');
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(session.sessionDateKey)) {
      throw ArgumentError.value(
        session.sessionDateKey,
        'sessionDateKey',
        'Use YYYY-MM-DD.',
      );
    }
    if (!<String>['planned', 'in_progress', 'completed', 'skipped', 'unknown']
        .contains(session.statusCode)) {
      throw ArgumentError.value(
        session.statusCode,
        'statusCode',
        'Unsupported session status.',
      );
    }
  }
}
