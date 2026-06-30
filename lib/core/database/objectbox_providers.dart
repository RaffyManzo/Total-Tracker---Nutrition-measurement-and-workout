import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:objectbox/objectbox.dart';

import '../../features/nutrition/data/repositories/ingredient_repository.dart';
import '../../features/nutrition/data/repositories/daily_record_repository.dart';
import '../../features/nutrition/data/repositories/meal_repository.dart';
import '../../features/nutrition/data/repositories/measurement_repository.dart';
import '../../features/nutrition/data/repositories/recipe_repository.dart';
import '../../features/nutrition/data/services/food_analytics_service.dart';
import '../../features/nutrition/data/services/food_planning_service.dart';
import '../../features/nutrition/data/services/open_food_facts_service.dart';
import '../../features/profile/data/repositories/user_profile_repository.dart';
import '../../features/workout/data/repositories/exercise_repository.dart';
import '../../features/workout/data/repositories/muscle_repository.dart';
import '../../features/workout/data/repositories/routine_repository.dart';
import '../../features/workout/data/repositories/workout_plan_repository.dart';
import '../../features/workout/data/repositories/workout_session_repository.dart';
import '../../features/workout/data/seed/muscle_catalog_seeder.dart';
import 'database_health.dart';
import 'objectbox_database.dart';

class DatabaseInitializationStatus {
  const DatabaseInitializationStatus._({
    required this.isReady,
    this.errorMessage,
  });

  const DatabaseInitializationStatus.notStarted() : this._(isReady: false);

  const DatabaseInitializationStatus.ready() : this._(isReady: true);

  const DatabaseInitializationStatus.failed(String errorMessage)
      : this._(isReady: false, errorMessage: errorMessage);

  final bool isReady;
  final String? errorMessage;
}

final Provider<ObjectBoxDatabase> objectBoxDatabaseProvider =
    Provider<ObjectBoxDatabase>((ref) {
  throw StateError('ObjectBoxDatabase must be provided by the app bootstrap.');
});

final Provider<Store> objectBoxStoreProvider = Provider<Store>((ref) {
  return ref.watch(objectBoxDatabaseProvider).store;
});

final Provider<DatabaseInitializationStatus>
    databaseInitializationStatusProvider =
    Provider<DatabaseInitializationStatus>(
  (ref) {
    return const DatabaseInitializationStatus.notStarted();
  },
);

final Provider<UserProfileRepository> userProfileRepositoryProvider =
    Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(ref.watch(objectBoxStoreProvider));
});

final Provider<IngredientRepository> ingredientRepositoryProvider =
    Provider<IngredientRepository>((ref) {
  return IngredientRepository(ref.watch(objectBoxStoreProvider));
});

final Provider<DailyRecordRepository> dailyRecordRepositoryProvider =
    Provider<DailyRecordRepository>((ref) {
  return DailyRecordRepository(ref.watch(objectBoxStoreProvider));
});

final Provider<MealRepository> mealRepositoryProvider =
    Provider<MealRepository>((ref) {
  return MealRepository(ref.watch(objectBoxStoreProvider));
});

final Provider<RecipeRepository> recipeRepositoryProvider =
    Provider<RecipeRepository>((ref) {
  return RecipeRepository(ref.watch(objectBoxStoreProvider));
});

final Provider<MeasurementRepository> measurementRepositoryProvider =
    Provider<MeasurementRepository>((ref) {
  return MeasurementRepository(ref.watch(objectBoxStoreProvider));
});

final Provider<FoodPlanningService> foodPlanningServiceProvider =
    Provider<FoodPlanningService>((ref) {
  return FoodPlanningService(
    dailyRecords: ref.watch(dailyRecordRepositoryProvider),
    meals: ref.watch(mealRepositoryProvider),
    recipes: ref.watch(recipeRepositoryProvider),
  );
});

final Provider<FoodAnalyticsService> foodAnalyticsServiceProvider =
    Provider<FoodAnalyticsService>((ref) {
  return FoodAnalyticsService(
    meals: ref.watch(mealRepositoryProvider),
    measurements: ref.watch(measurementRepositoryProvider),
    workoutSessions: ref.watch(workoutSessionRepositoryProvider),
  );
});

final Provider<OpenFoodFactsService> openFoodFactsServiceProvider =
    Provider<OpenFoodFactsService>((ref) {
  return OpenFoodFactsService();
});

final Provider<MuscleRepository> muscleRepositoryProvider =
    Provider<MuscleRepository>((ref) {
  return MuscleRepository(ref.watch(objectBoxStoreProvider));
});

final Provider<ExerciseRepository> exerciseRepositoryProvider =
    Provider<ExerciseRepository>((ref) {
  return ExerciseRepository(ref.watch(objectBoxStoreProvider));
});

final Provider<RoutineRepository> routineRepositoryProvider =
    Provider<RoutineRepository>((ref) {
  return RoutineRepository(ref.watch(objectBoxStoreProvider));
});

final Provider<WorkoutPlanRepository> workoutPlanRepositoryProvider =
    Provider<WorkoutPlanRepository>((ref) {
  return WorkoutPlanRepository(ref.watch(objectBoxStoreProvider));
});

final Provider<WorkoutSessionRepository> workoutSessionRepositoryProvider =
    Provider<WorkoutSessionRepository>((ref) {
  return WorkoutSessionRepository(ref.watch(objectBoxStoreProvider));
});

final Provider<MuscleCatalogSeeder> muscleCatalogSeederProvider =
    Provider<MuscleCatalogSeeder>((ref) {
  return MuscleCatalogSeeder(ref.watch(objectBoxStoreProvider));
});

final Provider<DatabaseHealth> databaseHealthProvider =
    Provider<DatabaseHealth>((ref) {
  return DatabaseHealth(ref.watch(objectBoxDatabaseProvider));
});
