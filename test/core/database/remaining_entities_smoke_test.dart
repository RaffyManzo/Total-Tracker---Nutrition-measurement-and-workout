import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/entities/nutrition_tracking_entities.dart';
import 'package:total_tracker/features/workout/data/entities/workout_tracking_entities.dart';

void main() {
  const int now = 1750000000000;

  group('remaining ObjectBox entities', () {
    test('nutrition entities keep stable defaults', () {
      final DailyRecordEntity day = DailyRecordEntity(
        uuid: 'day-1',
        dateKey: '2026-06-29',
        createdAtEpochMs: now,
        updatedAtEpochMs: now,
      );
      final MealEntity meal = MealEntity(
        uuid: 'meal-1',
        dateKey: '2026-06-29',
        mealTypeCode: 'pranzo',
        title: 'Pranzo',
        createdAtEpochMs: now,
        updatedAtEpochMs: now,
      );
      final RecipeEntity recipe = RecipeEntity(
        uuid: 'recipe-1',
        title: 'Riso e pollo',
        createdAtEpochMs: now,
        updatedAtEpochMs: now,
      );
      final ScaleMeasurementEntity scale = ScaleMeasurementEntity(
        uuid: 'scale-1',
        dateKey: '2026-06-29',
        title: 'Bilancia',
        createdAtEpochMs: now,
        updatedAtEpochMs: now,
      );
      final TapeMeasurementEntity tape = TapeMeasurementEntity(
        uuid: 'tape-1',
        dateKey: '2026-06-29',
        title: 'Metro',
        createdAtEpochMs: now,
        updatedAtEpochMs: now,
      );

      expect(day.stepGoal, 8000);
      expect(meal.mealModeCode, 'standard');
      expect(recipe.servings, 1);
      expect(scale.reliabilityCode, 'normal');
      expect(tape.reliabilityCode, 'normal');
    });

    test('workout entities keep session snapshots', () {
      final RoutineEntity routine = RoutineEntity(
        uuid: 'routine-1',
        name: 'Upper',
        slug: 'upper',
        createdAtEpochMs: now,
        updatedAtEpochMs: now,
      );
      final RoutineExerciseEntity routineExercise = RoutineExerciseEntity(
        uuid: 'routine-exercise-1',
        exerciseNameSnapshot: 'Panca piana',
        createdAtEpochMs: now,
        updatedAtEpochMs: now,
      );
      final WorkoutPlanEntity plan = WorkoutPlanEntity(
        uuid: 'plan-1',
        name: 'Scheda A',
        createdAtEpochMs: now,
        updatedAtEpochMs: now,
      );
      final WorkoutSessionEntity session = WorkoutSessionEntity(
        uuid: 'session-1',
        title: 'Upper - Sessione 2026-06-29',
        sessionDateKey: '2026-06-29',
        routineUuid: routine.uuid,
        routineNameSnapshot: routine.name,
        createdAtEpochMs: now,
        updatedAtEpochMs: now,
      );
      final SessionExerciseEntity sessionExercise = SessionExerciseEntity(
        uuid: 'session-exercise-1',
        exerciseUuid: routineExercise.exerciseUuid,
        exerciseNameSnapshot: routineExercise.exerciseNameSnapshot,
        createdAtEpochMs: now,
        updatedAtEpochMs: now,
      );

      expect(plan.statusCode, 'draft');
      expect(session.statusCode, 'planned');
      expect(session.routineNameSnapshot, 'Upper');
      expect(sessionExercise.exerciseNameSnapshot, 'Panca piana');
      expect(sessionExercise.primaryMuscleCodesJson, '[]');
    });

    test('all 18 deferred entity types can be instantiated', () {
      final List<Object> entities = <Object>[
        DailyRecordEntity(
          uuid: '1',
          dateKey: '2026-06-29',
          createdAtEpochMs: now,
          updatedAtEpochMs: now,
        ),
        MealEntity(
          uuid: '2',
          dateKey: '2026-06-29',
          mealTypeCode: 'cena',
          title: 'Cena',
          createdAtEpochMs: now,
          updatedAtEpochMs: now,
        ),
        MealItemEntity(
          uuid: '3',
          kindCode: 'ingredient',
          itemNameSnapshot: 'Riso',
          createdAtEpochMs: now,
          updatedAtEpochMs: now,
        ),
        RecipeEntity(
          uuid: '4',
          title: 'Ricetta',
          createdAtEpochMs: now,
          updatedAtEpochMs: now,
        ),
        RecipeIngredientEntity(
          uuid: '5',
          nameSnapshot: 'Ingrediente',
          createdAtEpochMs: now,
          updatedAtEpochMs: now,
        ),
        RecipeStepEntity(
          uuid: '6',
          instruction: 'Mescola',
          createdAtEpochMs: now,
          updatedAtEpochMs: now,
        ),
        ScaleMeasurementEntity(
          uuid: '7',
          dateKey: '2026-06-29',
          title: 'Bilancia',
          createdAtEpochMs: now,
          updatedAtEpochMs: now,
        ),
        TapeMeasurementEntity(
          uuid: '8',
          dateKey: '2026-06-29',
          title: 'Metro',
          createdAtEpochMs: now,
          updatedAtEpochMs: now,
        ),
        TapeMeasurementEntryEntity(
          uuid: '9',
          measurementCode: 'waist_cm',
          createdAtEpochMs: now,
          updatedAtEpochMs: now,
        ),
        RoutineEntity(
          uuid: '10',
          name: 'Routine',
          slug: 'routine',
          createdAtEpochMs: now,
          updatedAtEpochMs: now,
        ),
        RoutineExerciseEntity(
          uuid: '11',
          exerciseNameSnapshot: 'Exercise',
          createdAtEpochMs: now,
          updatedAtEpochMs: now,
        ),
        RoutineSetTemplateEntity(
          uuid: '12',
          createdAtEpochMs: now,
          updatedAtEpochMs: now,
        ),
        WorkoutPlanEntity(
          uuid: '13',
          name: 'Plan',
          createdAtEpochMs: now,
          updatedAtEpochMs: now,
        ),
        WorkoutPlanDayEntity(
          uuid: '14',
          dayCode: 'day-1',
          title: 'Giorno 1',
          createdAtEpochMs: now,
          updatedAtEpochMs: now,
        ),
        WorkoutPlanExerciseEntity(
          uuid: '15',
          exerciseNameSnapshot: 'Exercise',
          createdAtEpochMs: now,
          updatedAtEpochMs: now,
        ),
        WorkoutSessionEntity(
          uuid: '16',
          title: 'Session',
          sessionDateKey: '2026-06-29',
          createdAtEpochMs: now,
          updatedAtEpochMs: now,
        ),
        SessionExerciseEntity(
          uuid: '17',
          exerciseNameSnapshot: 'Exercise',
          createdAtEpochMs: now,
          updatedAtEpochMs: now,
        ),
        SessionSetEntity(
          uuid: '18',
          createdAtEpochMs: now,
          updatedAtEpochMs: now,
        ),
      ];

      expect(entities, hasLength(18));
    });
  });
}
