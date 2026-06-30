import 'package:objectbox/objectbox.dart';

import '../../../../core/identifiers/uuid_generator.dart';
import '../../../../core/time/clock.dart';
import '../entities/muscle_entity.dart';

class MuscleRepository {
  MuscleRepository(
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

  MuscleEntity save(MuscleEntity muscle) {
    _normalize(muscle);
    _validate(muscle);
    _ensureCodeIsUnique(muscle);
    _prepareForSave(muscle);
    muscle.id = _box.put(muscle);
    return muscle;
  }

  MuscleEntity? getById(int id) {
    return _box.get(id);
  }

  MuscleEntity? findByCode(String code) {
    final String normalizedCode = code.trim();
    for (final MuscleEntity muscle in _box.getAll()) {
      if (muscle.code == normalizedCode && muscle.deletedAtEpochMs == null) {
        return muscle;
      }
    }
    return null;
  }

  List<MuscleEntity> getAll() {
    return _box.getAll()..sort(_sortByCatalogOrder);
  }

  List<MuscleEntity> getAllActive() {
    return _box
        .getAll()
        .where(
          (MuscleEntity muscle) =>
              muscle.isActive && muscle.deletedAtEpochMs == null,
        )
        .toList()
      ..sort(_sortByCatalogOrder);
  }

  Map<String, int> duplicateCodeCounts() {
    final Map<String, int> counts = <String, int>{};
    for (final MuscleEntity muscle in _box.getAll()) {
      counts[muscle.code] = (counts[muscle.code] ?? 0) + 1;
    }
    counts.removeWhere((String _, int count) => count < 2);
    return counts;
  }

  void _prepareForSave(MuscleEntity muscle) {
    final int nowEpochMs = _clock.nowEpochMs();
    if (muscle.uuid.trim().isEmpty) {
      muscle.uuid = _uuidGenerator.generate();
    }
    if (muscle.createdAtEpochMs == 0) {
      muscle.createdAtEpochMs = nowEpochMs;
    }
    muscle.updatedAtEpochMs = nowEpochMs;
  }

  void _normalize(MuscleEntity muscle) {
    muscle.code = muscle.code.trim();
    muscle.displayNameIt = muscle.displayNameIt.trim();
    muscle.displayNameEn = muscle.displayNameEn.trim();
    muscle.groupCode = muscle.groupCode.trim();
    muscle.bodyRegionCode = muscle.bodyRegionCode.trim();
  }

  void _validate(MuscleEntity muscle) {
    if (muscle.code.isEmpty) {
      throw ArgumentError.value(muscle.code, 'code', 'Code is required.');
    }
    if (muscle.displayNameIt.isEmpty) {
      throw ArgumentError.value(
        muscle.displayNameIt,
        'displayNameIt',
        'Italian display name is required.',
      );
    }
    if (muscle.displayNameEn.isEmpty) {
      throw ArgumentError.value(
        muscle.displayNameEn,
        'displayNameEn',
        'English display name is required.',
      );
    }
    if (muscle.groupCode.isEmpty) {
      throw ArgumentError.value(
        muscle.groupCode,
        'groupCode',
        'Group code is required.',
      );
    }
    if (muscle.bodyRegionCode.isEmpty) {
      throw ArgumentError.value(
        muscle.bodyRegionCode,
        'bodyRegionCode',
        'Body region code is required.',
      );
    }
  }

  void _ensureCodeIsUnique(MuscleEntity muscle) {
    final MuscleEntity? existingMuscle = findByCode(muscle.code);
    if (existingMuscle != null && existingMuscle.id != muscle.id) {
      throw StateError('Muscle code already exists.');
    }
  }

  int _sortByCatalogOrder(MuscleEntity a, MuscleEntity b) {
    final int sortOrderComparison = a.sortOrder.compareTo(b.sortOrder);
    if (sortOrderComparison != 0) {
      return sortOrderComparison;
    }
    return a.code.compareTo(b.code);
  }
}
