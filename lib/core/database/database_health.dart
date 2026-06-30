import '../../features/nutrition/data/entities/ingredient_entity.dart';
import '../../features/profile/data/repositories/user_profile_repository.dart';
import '../../features/workout/data/entities/exercise_entity.dart';
import '../../features/workout/data/entities/exercise_muscle_link_entity.dart';
import '../../features/workout/data/repositories/muscle_repository.dart';
import '../../features/workout/data/seed/muscle_catalog_seed.dart';
import 'objectbox_database.dart';

class DatabaseHealthReport {
  const DatabaseHealthReport({
    required this.storeOpen,
    required this.defaultProfileAvailable,
    required this.muscleCatalogPopulated,
    required this.noDuplicateMuscleCodes,
    required this.ingredientCount,
    required this.exerciseCount,
    required this.exerciseMuscleLinkCount,
    required this.errors,
  });

  final bool storeOpen;
  final bool defaultProfileAvailable;
  final bool muscleCatalogPopulated;
  final bool noDuplicateMuscleCodes;
  final int ingredientCount;
  final int exerciseCount;
  final int exerciseMuscleLinkCount;
  final List<String> errors;

  bool get isReady {
    return storeOpen &&
        defaultProfileAvailable &&
        muscleCatalogPopulated &&
        noDuplicateMuscleCodes &&
        errors.isEmpty;
  }
}

class DatabaseHealth {
  const DatabaseHealth(this._database);

  final ObjectBoxDatabase _database;

  DatabaseHealthReport check() {
    if (!_database.isOpen) {
      return const DatabaseHealthReport(
        storeOpen: false,
        defaultProfileAvailable: false,
        muscleCatalogPopulated: false,
        noDuplicateMuscleCodes: false,
        ingredientCount: 0,
        exerciseCount: 0,
        exerciseMuscleLinkCount: 0,
        errors: <String>['ObjectBox Store is not open.'],
      );
    }

    final List<String> errors = <String>[];
    bool defaultProfileAvailable = false;
    bool muscleCatalogPopulated = false;
    bool noDuplicateMuscleCodes = false;
    int ingredientCount = 0;
    int exerciseCount = 0;
    int exerciseMuscleLinkCount = 0;

    try {
      defaultProfileAvailable =
          UserProfileRepository(_database.store).getActiveProfile() != null;
    } catch (error) {
      errors.add('Profile check failed: $error');
    }

    try {
      final MuscleRepository muscleRepository =
          MuscleRepository(_database.store);
      muscleCatalogPopulated =
          muscleRepository.getAllActive().length >= muscleCatalogSeed.length;
      noDuplicateMuscleCodes = muscleRepository.duplicateCodeCounts().isEmpty;
    } catch (error) {
      errors.add('Muscle catalog check failed: $error');
    }

    try {
      ingredientCount = _database.store.box<IngredientEntity>().getAll().length;
      exerciseCount = _database.store.box<ExerciseEntity>().getAll().length;
      exerciseMuscleLinkCount =
          _database.store.box<ExerciseMuscleLinkEntity>().getAll().length;
    } catch (error) {
      errors.add('Entity count failed: $error');
    }

    return DatabaseHealthReport(
      storeOpen: true,
      defaultProfileAvailable: defaultProfileAvailable,
      muscleCatalogPopulated: muscleCatalogPopulated,
      noDuplicateMuscleCodes: noDuplicateMuscleCodes,
      ingredientCount: ingredientCount,
      exerciseCount: exerciseCount,
      exerciseMuscleLinkCount: exerciseMuscleLinkCount,
      errors: List<String>.unmodifiable(errors),
    );
  }
}
