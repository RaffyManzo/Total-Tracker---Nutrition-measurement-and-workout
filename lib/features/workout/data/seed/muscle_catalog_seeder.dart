import 'package:objectbox/objectbox.dart';

import '../../../../core/identifiers/uuid_generator.dart';
import '../../../../core/time/clock.dart';
import '../entities/muscle_entity.dart';
import 'muscle_catalog_seed.dart';

class MuscleCatalogSeedReport {
  const MuscleCatalogSeedReport({
    required this.inserted,
    required this.updated,
    required this.unchanged,
    required this.duplicateCodes,
    required this.errors,
  });

  final int inserted;
  final int updated;
  final int unchanged;
  final int duplicateCodes;
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;
}

class MuscleCatalogSeeder {
  MuscleCatalogSeeder(
    Store store, {
    Clock clock = const Clock(),
    UuidGenerator? uuidGenerator,
  })  : _store = store,
        _clock = clock,
        _uuidGenerator = uuidGenerator ?? UuidGenerator();

  final Store _store;
  final Clock _clock;
  final UuidGenerator _uuidGenerator;

  Box<MuscleEntity> get _box => _store.box<MuscleEntity>();

  MuscleCatalogSeedReport seed() {
    return _store.runInTransaction(TxMode.write, () {
      int inserted = 0;
      int updated = 0;
      int unchanged = 0;
      int duplicateCodes = 0;
      final List<String> errors = <String>[];
      final Set<String> seedCodes = <String>{};

      for (final MuscleCatalogSeedEntry entry in muscleCatalogSeed) {
        if (!seedCodes.add(entry.code)) {
          duplicateCodes += 1;
          errors.add('Duplicate muscle seed code: ${entry.code}');
          continue;
        }

        final List<MuscleEntity> existingMuscles = _findAllByCode(entry.code);
        if (existingMuscles.length > 1) {
          duplicateCodes += existingMuscles.length - 1;
          errors.add('Duplicate persisted muscle code: ${entry.code}');
          continue;
        }

        if (existingMuscles.isEmpty) {
          _insert(entry);
          inserted += 1;
          continue;
        }

        final MuscleEntity existingMuscle = existingMuscles.first;
        if (_updateDescription(existingMuscle, entry)) {
          updated += 1;
        } else {
          unchanged += 1;
        }
      }

      return MuscleCatalogSeedReport(
        inserted: inserted,
        updated: updated,
        unchanged: unchanged,
        duplicateCodes: duplicateCodes,
        errors: List<String>.unmodifiable(errors),
      );
    });
  }

  List<MuscleEntity> _findAllByCode(String code) {
    return _box
        .getAll()
        .where((MuscleEntity muscle) => muscle.code == code)
        .toList();
  }

  void _insert(MuscleCatalogSeedEntry entry) {
    final int nowEpochMs = _clock.nowEpochMs();
    final MuscleEntity muscle = MuscleEntity(
      uuid: _uuidGenerator.generate(),
      code: entry.code,
      displayNameIt: entry.displayNameIt,
      displayNameEn: entry.displayNameEn,
      groupCode: entry.groupCode,
      bodyRegionCode: entry.bodyRegionCode,
      sortOrder: entry.sortOrder,
      isActive: true,
      createdAtEpochMs: nowEpochMs,
      updatedAtEpochMs: nowEpochMs,
    );
    muscle.id = _box.put(muscle);
  }

  bool _updateDescription(
    MuscleEntity muscle,
    MuscleCatalogSeedEntry entry,
  ) {
    bool changed = false;
    if (muscle.displayNameIt != entry.displayNameIt) {
      muscle.displayNameIt = entry.displayNameIt;
      changed = true;
    }
    if (muscle.displayNameEn != entry.displayNameEn) {
      muscle.displayNameEn = entry.displayNameEn;
      changed = true;
    }
    if (muscle.groupCode != entry.groupCode) {
      muscle.groupCode = entry.groupCode;
      changed = true;
    }
    if (muscle.bodyRegionCode != entry.bodyRegionCode) {
      muscle.bodyRegionCode = entry.bodyRegionCode;
      changed = true;
    }
    if (muscle.sortOrder != entry.sortOrder) {
      muscle.sortOrder = entry.sortOrder;
      changed = true;
    }
    if (!muscle.isActive) {
      muscle.isActive = true;
      changed = true;
    }

    if (!changed) {
      return false;
    }

    muscle.updatedAtEpochMs = _clock.nowEpochMs();
    muscle.id = _box.put(muscle);
    return true;
  }
}
