import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/workout/data/entities/exercise_entity.dart';
import 'package:total_tracker/features/workout/data/entities/muscle_entity.dart';
import 'package:total_tracker/features/workout/data/repositories/exercise_repository.dart';
import 'package:total_tracker/features/workout/data/repositories/muscle_repository.dart';
import 'package:total_tracker/features/workout/data/seed/muscle_catalog_seeder.dart';
import 'package:total_tracker/features/workout/domain/workout_codes.dart';

import '../../helpers/objectbox_test_helper.dart';

void main() {
  test('salvataggio di un esercizio gym', () async {
    final database = await openTestDatabase();
    final repository = ExerciseRepository(database.store);

    final exercise = repository.save(_exercise(name: 'Panca piana'));

    expect(exercise.id, greaterThan(0));
    expect(exercise.exerciseModeCode, ExerciseModeCodes.gym);
  });

  test('rifiuto di un exerciseModeCode non valido', () async {
    final database = await openTestDatabase();
    final repository = ExerciseRepository(database.store);

    expect(
      () => repository.save(_exercise(name: 'Invalido', modeCode: 'invalid')),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('ricerca per modalita', () async {
    final database = await openTestDatabase();
    final repository = ExerciseRepository(database.store);

    repository
        .save(_exercise(name: 'Corsa', modeCode: ExerciseModeCodes.activity));
    repository.save(_exercise(name: 'Squat', modeCode: ExerciseModeCodes.gym));

    final gymExercises = repository.getByMode(ExerciseModeCodes.gym);

    expect(gymExercises.length, 1);
    expect(gymExercises.single.name, 'Squat');
  });

  test('archiviazione', () async {
    final database = await openTestDatabase();
    final repository = ExerciseRepository(database.store);

    final exercise = repository.save(_exercise(name: 'Affondi'));
    repository.archive(exercise);

    expect(repository.getAllActive(), isEmpty);
    expect(database.store.box<ExerciseEntity>().get(exercise.id), isNotNull);
  });

  test('associa muscoli primari e secondari', () async {
    final context = await _relationContext();

    context.exerciseRepository.replaceMuscles(
      context.exercise.id,
      <int>[context.pectoralis.id],
      <int>[context.triceps.id],
    );

    expect(
      context.exerciseRepository
          .getPrimaryMuscles(context.exercise.id)
          .single
          .code,
      'pectoralis_major',
    );
    expect(
      context.exerciseRepository
          .getSecondaryMuscles(context.exercise.id)
          .single
          .code,
      'triceps_long',
    );
  });

  test('mantiene ordine tramite position', () async {
    final context = await _relationContext();

    context.exerciseRepository.replaceMuscles(
      context.exercise.id,
      <int>[context.triceps.id, context.pectoralis.id],
      <int>[],
    );

    final primaryCodes = context.exerciseRepository
        .getPrimaryMuscles(context.exercise.id)
        .map((muscle) => muscle.code)
        .toList();

    expect(primaryCodes, <String>['triceps_long', 'pectoralis_major']);
  });

  test('impedisce duplicati', () async {
    final context = await _relationContext();

    expect(
      () => context.exerciseRepository.replaceMuscles(
        context.exercise.id,
        <int>[context.pectoralis.id, context.pectoralis.id],
        <int>[],
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => context.exerciseRepository.replaceMuscles(
        context.exercise.id,
        <int>[context.pectoralis.id],
        <int>[context.pectoralis.id],
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('replaceMuscles sostituisce atomicamente le relazioni', () async {
    final context = await _relationContext();

    context.exerciseRepository.replaceMuscles(
      context.exercise.id,
      <int>[context.pectoralis.id],
      <int>[context.triceps.id],
    );

    expect(
      () => context.exerciseRepository.replaceMuscles(
        context.exercise.id,
        <int>[context.triceps.id],
        <int>[999999],
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(
      context.exerciseRepository
          .getPrimaryMuscles(context.exercise.id)
          .single
          .id,
      context.pectoralis.id,
    );
    expect(
      context.exerciseRepository
          .getSecondaryMuscles(context.exercise.id)
          .single
          .id,
      context.triceps.id,
    );
  });

  test('ricerca esercizi tramite muscolo', () async {
    final context = await _relationContext();

    context.exerciseRepository.replaceMuscles(
      context.exercise.id,
      <int>[context.pectoralis.id],
      <int>[],
    );

    final exercises =
        context.exerciseRepository.getExercisesByMuscle(context.pectoralis.id);

    expect(exercises.single.id, context.exercise.id);
  });
}

ExerciseEntity _exercise({
  required String name,
  String modeCode = ExerciseModeCodes.gym,
}) {
  return ExerciseEntity(
    uuid: '',
    name: name,
    exerciseModeCode: modeCode,
    createdAtEpochMs: 0,
    updatedAtEpochMs: 0,
  );
}

Future<_RelationContext> _relationContext() async {
  final database = await openTestDatabase();
  MuscleCatalogSeeder(database.store).seed();
  final MuscleRepository muscleRepository = MuscleRepository(database.store);
  final ExerciseRepository exerciseRepository =
      ExerciseRepository(database.store);
  final ExerciseEntity exercise =
      exerciseRepository.save(_exercise(name: 'Panca piana'));

  return _RelationContext(
    exerciseRepository: exerciseRepository,
    exercise: exercise,
    pectoralis: muscleRepository.findByCode('pectoralis_major')!,
    triceps: muscleRepository.findByCode('triceps_long')!,
  );
}

class _RelationContext {
  const _RelationContext({
    required this.exerciseRepository,
    required this.exercise,
    required this.pectoralis,
    required this.triceps,
  });

  final ExerciseRepository exerciseRepository;
  final ExerciseEntity exercise;
  final MuscleEntity pectoralis;
  final MuscleEntity triceps;
}
