import 'package:objectbox/objectbox.dart';

import '../../../../core/identifiers/uuid_generator.dart';
import '../../../../core/time/clock.dart';
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
    _enforceSingleActiveProfile();
    final List<UserProfileEntity> activeProfiles = _activeProfiles();
    if (activeProfiles.isEmpty) {
      return null;
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
    return _store.runInTransaction(TxMode.write, () {
      _prepareForSave(profile);
      if (profile.isActive && profile.deletedAtEpochMs == null) {
        _deactivateOtherProfiles(profile.id);
      }
      profile.id = _box.put(profile);
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
  }
}
