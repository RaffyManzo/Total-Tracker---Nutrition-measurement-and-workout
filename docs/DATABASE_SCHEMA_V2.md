# Database Schema V2

## Scope

Schema V2 completes the ObjectBox entity layer planned in Schema V1.

Schema V1 implemented:

- `UserProfileEntity`
- `IngredientEntity`
- `MuscleEntity`
- `ExerciseEntity`
- `ExerciseMuscleLinkEntity`

Schema V2 adds the 18 previously deferred entities.

### Nutrition and measurements

- `DailyRecordEntity`
- `MealEntity`
- `MealItemEntity`
- `RecipeEntity`
- `RecipeIngredientEntity`
- `RecipeStepEntity`
- `ScaleMeasurementEntity`
- `TapeMeasurementEntity`
- `TapeMeasurementEntryEntity`

### Workout planning and history

- `RoutineEntity`
- `RoutineExerciseEntity`
- `RoutineSetTemplateEntity`
- `WorkoutPlanEntity`
- `WorkoutPlanDayEntity`
- `WorkoutPlanExerciseEntity`
- `WorkoutSessionEntity`
- `SessionExerciseEntity`
- `SessionSetEntity`

The complete local model therefore contains 23 entities.

## Design rules

- Every entity has an ObjectBox local numeric `id`.
- Every new entity has a stable string `uuid`.
- Timestamps are UTC epoch milliseconds.
- Records support soft deletion through `deletedAtEpochMs`.
- Enum ordinals are never persisted; stable string codes are used.
- Ordering of child records is explicit through `position`.
- Meal and workout rows preserve historical nutrient or exercise snapshots.
- References to existing ingredient and exercise archives use stable UUIDs.
- Parent-child structures inside the new schema use ObjectBox `ToOne` relations.

## Parent-child relations

- `MealEntity` -> `DailyRecordEntity`
- `MealItemEntity` -> `MealEntity`
- `RecipeIngredientEntity` -> `RecipeEntity`
- `RecipeStepEntity` -> `RecipeEntity`
- `TapeMeasurementEntryEntity` -> `TapeMeasurementEntity`
- `RoutineExerciseEntity` -> `RoutineEntity`
- `RoutineSetTemplateEntity` -> `RoutineExerciseEntity`
- `WorkoutPlanDayEntity` -> `WorkoutPlanEntity`
- `WorkoutPlanExerciseEntity` -> `WorkoutPlanDayEntity`
- `SessionExerciseEntity` -> `WorkoutSessionEntity`
- `SessionSetEntity` -> `SessionExerciseEntity`

## Historical snapshots

Meal items store their nutritional contribution at insertion time. Session
exercises and sets store exercise name, mode, muscles, media and execution
history at session time. Editing an archive item later must not rewrite past
meals or workout sessions.

## Excluded scope

The fridge and inventory concepts remain excluded. No backend synchronization,
API integration, repository implementation, UI binding or migration from
Obsidian is added by this phase.

## Generated files

After changing entities, regenerate and version:

- `objectbox-model.json`
- `lib/objectbox.g.dart`

```powershell
dart run build_runner build --delete-conflicting-outputs
```
