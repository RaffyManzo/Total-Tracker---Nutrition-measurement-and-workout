import 'package:objectbox/objectbox.dart';

import '../../../../core/identifiers/uuid_generator.dart';
import '../../../../core/time/clock.dart';
import '../../../nutrition/data/entities/nutrition_tracking_entities.dart';
import '../../../nutrition/data/services/target_input_change_bus.dart';
import '../../../nutrition/data/services/target_input_mutation_service.dart';
import '../../domain/profile_codes.dart';
import '../entities/user_profile_entity.dart';

class UserProfileRepository {
  UserProfileRepository(
    Store store, {
    Clock clock = const Clock(),
    UuidGenerator? uuidGenerator,
  })  : _store = store,
        _clock = clock,
        _uuidGenerator = uuidGenerator ?? UuidGenerator();

  final Store _store;
  final Clock _clock;
  final UuidGenerator _uuidGenerator;

  Box<UserProfileEntity> get _box => _store.box<UserProfileEntity>();

  UserProfileEntity? getActiveProfile() {
    final List<UserProfileEntity> activeProfiles = _activeProfiles();
    if (activeProfiles.isEmpty) {
      return null;
    }

    if (activeProfiles.length > 1) {
      _enforceSingleActiveProfile();
      final List<UserProfileEntity> normalizedProfiles = _activeProfiles();
      return normalizedProfiles.isEmpty ? null : normalizedProfiles.first;
    }

    return activeProfiles.first;
  }

  UserProfileEntity createDefaultProfileIfMissing() {
    return _store.runInTransaction(TxMode.write, () {
      _enforceSingleActiveProfileInTransaction();
      final List<UserProfileEntity> activeProfiles = _activeProfiles();
      if (activeProfiles.isNotEmpty) {
        return activeProfiles.first;
      }

      final int nowEpochMs = _clock.nowEpochMs();
      final UserProfileEntity profile = UserProfileEntity(
        uuid: _uuidGenerator.generate(),
        createdAtEpochMs: nowEpochMs,
        updatedAtEpochMs: nowEpochMs,
      );
      profile.id = _box.put(profile);
      return profile;
    });
  }

  UserProfileEntity save(UserProfileEntity profile) {
    _validate(profile);
    final DateTime today = DateTime.now();
    final String effectiveDate = '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    final UserProfileEntity result = _store.runInTransaction(TxMode.write, () {
      _prepareForSave(profile);
      if (profile.isActive && profile.deletedAtEpochMs == null) {
        _deactivateOtherProfiles(profile.id);
      }
      profile.id = _box.put(profile);
      TargetInputMutationService.enqueueInCurrentTransaction(
        _store,
        kind: TargetInputChangeKind.profile,
        fromDateKey: effectiveDate,
        reasonCode: 'profile_effective_from_today',
        sourceEntityUuid: profile.uuid,
        sourceRevision: profile.updatedAtEpochMs,
      );
      return profile;
    });
    TargetInputMutationService.publishAfterCommit(
      kind: TargetInputChangeKind.profile,
      fromDateKey: effectiveDate,
      reasonCode: 'profile_effective_from_today',
      sourceEntityUuid: profile.uuid,
      sourceRevision: profile.updatedAtEpochMs,
    );
    return result;
  }

  UserProfileEntity saveWithDailyRecords(
    UserProfileEntity profile,
    List<DailyRecordEntity> dailyRecords,
  ) {
    _validate(profile);
    return _store.runInTransaction(TxMode.write, () {
      _prepareForSave(profile);
      if (profile.isActive && profile.deletedAtEpochMs == null) {
        _deactivateOtherProfiles(profile.id);
      }
      profile.id = _box.put(profile);
      if (dailyRecords.isNotEmpty) {
        final int updatedAtEpochMs = _clock.nowEpochMs();
        for (final DailyRecordEntity day in dailyRecords) {
          day.updatedAtEpochMs = updatedAtEpochMs;
        }
        _store.box<DailyRecordEntity>().putMany(dailyRecords);
      }
      return profile;
    });
  }

  UserProfileEntity update(UserProfileEntity profile) {
    if (profile.id == 0 || _box.get(profile.id) == null) {
      throw ArgumentError.value(profile.id, 'id', 'Profile does not exist.');
    }
    return save(profile);
  }

  UserProfileEntity softDelete(UserProfileEntity profile) {
    if (profile.id == 0 || _box.get(profile.id) == null) {
      throw ArgumentError.value(profile.id, 'id', 'Profile does not exist.');
    }

    final int nowEpochMs = _clock.nowEpochMs();
    profile.isActive = false;
    profile.deletedAtEpochMs ??= nowEpochMs;
    profile.updatedAtEpochMs = nowEpochMs;
    profile.id = _box.put(profile);
    return profile;
  }

  List<UserProfileEntity> _activeProfiles() {
    final List<UserProfileEntity> profiles = _box
        .getAll()
        .where(
          (UserProfileEntity profile) =>
              profile.isActive && profile.deletedAtEpochMs == null,
        )
        .toList()
      ..sort(
        (UserProfileEntity a, UserProfileEntity b) =>
            a.createdAtEpochMs.compareTo(b.createdAtEpochMs),
      );
    return profiles;
  }

  void _enforceSingleActiveProfile() {
    _store.runInTransaction(
        TxMode.write, _enforceSingleActiveProfileInTransaction);
  }

  void _enforceSingleActiveProfileInTransaction() {
    final List<UserProfileEntity> activeProfiles = _activeProfiles();
    if (activeProfiles.length <= 1) {
      return;
    }

    final UserProfileEntity profileToKeep = activeProfiles.first;
    final int nowEpochMs = _clock.nowEpochMs();
    for (final UserProfileEntity profile in activeProfiles.skip(1)) {
      profile.isActive = false;
      profile.updatedAtEpochMs = nowEpochMs;
    }
    _box.putMany(activeProfiles.where((UserProfileEntity profile) {
      return profile.id != profileToKeep.id;
    }).toList());
  }

  void _deactivateOtherProfiles(int currentProfileId) {
    final int nowEpochMs = _clock.nowEpochMs();
    final List<UserProfileEntity> profilesToDeactivate = _activeProfiles()
        .where((UserProfileEntity profile) => profile.id != currentProfileId)
        .toList();
    for (final UserProfileEntity profile in profilesToDeactivate) {
      profile.isActive = false;
      profile.updatedAtEpochMs = nowEpochMs;
    }
    if (profilesToDeactivate.isNotEmpty) {
      _box.putMany(profilesToDeactivate);
    }
  }

  void _prepareForSave(UserProfileEntity profile) {
    final int nowEpochMs = _clock.nowEpochMs();
    if (profile.uuid.trim().isEmpty) {
      profile.uuid = _uuidGenerator.generate();
    }
    if (profile.createdAtEpochMs == 0) {
      profile.createdAtEpochMs = nowEpochMs;
    }
    profile.updatedAtEpochMs = nowEpochMs;
  }

  void _validate(UserProfileEntity profile) {
    if (!BiologicalSexCodes.values.contains(profile.biologicalSexCode)) {
      throw ArgumentError.value(
        profile.biologicalSexCode,
        'biologicalSexCode',
        'Unsupported biological sex code.',
      );
    }
    if (!TargetModeCodes.values.contains(profile.targetModeCode)) {
      throw ArgumentError.value(
        profile.targetModeCode,
        'targetModeCode',
        'Unsupported target mode code.',
      );
    }
    if (!MacroModeCodes.values.contains(profile.macroModeCode)) {
      throw ArgumentError.value(
        profile.macroModeCode,
        'macroModeCode',
        'Unsupported macro mode code.',
      );
    }
    if (!MealTargetModeCodes.values.contains(profile.mealTargetModeCode)) {
      throw ArgumentError.value(
        profile.mealTargetModeCode,
        'mealTargetModeCode',
        'Unsupported meal target mode code.',
      );
    }
    if (!WorkoutActivityTypeCodes.values
        .contains(profile.workoutActivityTypeCode)) {
      throw ArgumentError.value(
        profile.workoutActivityTypeCode,
        'workoutActivityTypeCode',
        'Unsupported workout activity type code.',
      );
    }
    if (!ActivityFallbackModeCodes.values
        .contains(profile.activityFallbackModeCode)) {
      throw ArgumentError.value(
        profile.activityFallbackModeCode,
        'activityFallbackModeCode',
        'Unsupported activity fallback mode code.',
      );
    }
    if (!ThemePreferenceCodes.values.contains(profile.themeModeCode)) {
      throw ArgumentError.value(
        profile.themeModeCode,
        'themeModeCode',
        'Unsupported theme mode code.',
      );
    }
    if (profile.defaultStepGoal < 0) {
      throw ArgumentError.value(
        profile.defaultStepGoal,
        'defaultStepGoal',
        'Step goal cannot be negative.',
      );
    }
    if (profile.defaultTargetKcal < 0) {
      throw ArgumentError.value(
        profile.defaultTargetKcal,
        'defaultTargetKcal',
        'Target kcal cannot be negative.',
      );
    }
    if (profile.heightCm != null && profile.heightCm! <= 0) {
      throw ArgumentError.value(
        profile.heightCm,
        'heightCm',
        'Height must be positive when present.',
      );
    }
    if (profile.initialWeightKg != null && profile.initialWeightKg! <= 0) {
      throw ArgumentError.value(
        profile.initialWeightKg,
        'initialWeightKg',
        'Initial weight must be positive when present.',
      );
    }
    if (profile.sedentaryBaseKcal < 0) {
      throw ArgumentError.value(
        profile.sedentaryBaseKcal,
        'sedentaryBaseKcal',
        'Sedentary base cannot be negative.',
      );
    }
    if (profile.averageWorkoutsPerWeek < 0) {
      throw ArgumentError.value(
        profile.averageWorkoutsPerWeek,
        'averageWorkoutsPerWeek',
        'Average workouts cannot be negative.',
      );
    }
    if (profile.averageWorkoutDurationMinutes < 0) {
      throw ArgumentError.value(
        profile.averageWorkoutDurationMinutes,
        'averageWorkoutDurationMinutes',
        'Workout duration cannot be negative.',
      );
    }
    if (profile.stepKcalCoefficient < 0) {
      throw ArgumentError.value(
        profile.stepKcalCoefficient,
        'stepKcalCoefficient',
        'Step coefficient cannot be negative.',
      );
    }
    if (profile.proteinGramsPerKg < 0 ||
        profile.fatGramsPerKg < 0 ||
        profile.carbsGramsPerKg < 0) {
      throw ArgumentError(
        'Personalized macro values in g/kg cannot be negative.',
      );
    }
    if (profile.macroModeCode == MacroModeCodes.customGramsPerKg &&
        (profile.proteinGramsPerKg > 5 ||
            profile.fatGramsPerKg > 5 ||
            profile.carbsGramsPerKg > 15)) {
      throw ArgumentError(
        'Personalized macro values exceed the supported editor range.',
      );
    }
    if (profile.sugarCarbsPercent < 0 || profile.sugarCarbsPercent > 100) {
      throw ArgumentError.value(
        profile.sugarCarbsPercent,
        'sugarCarbsPercent',
        'Sugar percentage must be between 0 and 100.',
      );
    }
  }
}
