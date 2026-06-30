import 'package:objectbox/objectbox.dart';

import '../../../../core/identifiers/uuid_generator.dart';
import '../../../../core/time/clock.dart';
import '../entities/nutrition_tracking_entities.dart';

class MeasurementRepository {
  MeasurementRepository(
    Store store, {
    Clock clock = const Clock(),
    UuidGenerator? uuidGenerator,
  })  : _store = store,
        _clock = clock,
        _uuidGenerator = uuidGenerator ?? UuidGenerator();

  final Store _store;
  final Clock _clock;
  final UuidGenerator _uuidGenerator;

  Box<ScaleMeasurementEntity> get _scaleBox {
    return _store.box<ScaleMeasurementEntity>();
  }

  Box<TapeMeasurementEntity> get _tapeBox {
    return _store.box<TapeMeasurementEntity>();
  }

  Box<TapeMeasurementEntryEntity> get _tapeEntryBox {
    return _store.box<TapeMeasurementEntryEntity>();
  }

  List<ScaleMeasurementEntity> getScaleMeasurements() {
    return _scaleBox
        .getAll()
        .where((ScaleMeasurementEntity item) => item.deletedAtEpochMs == null)
        .toList()
      ..sort((ScaleMeasurementEntity a, ScaleMeasurementEntity b) {
        return b.dateKey.compareTo(a.dateKey);
      });
  }

  List<TapeMeasurementEntity> getTapeMeasurements() {
    return _tapeBox
        .getAll()
        .where((TapeMeasurementEntity item) => item.deletedAtEpochMs == null)
        .toList()
      ..sort((TapeMeasurementEntity a, TapeMeasurementEntity b) {
        return b.dateKey.compareTo(a.dateKey);
      });
  }

  List<TapeMeasurementEntryEntity> getTapeEntries(int tapeMeasurementId) {
    return _tapeEntryBox
        .getAll()
        .where(
          (TapeMeasurementEntryEntity entry) =>
              entry.tapeMeasurement.targetId == tapeMeasurementId &&
              entry.deletedAtEpochMs == null,
        )
        .toList()
      ..sort((TapeMeasurementEntryEntity a, TapeMeasurementEntryEntity b) {
        return a.position.compareTo(b.position);
      });
  }

  ScaleMeasurementEntity? findScaleByDate(String dateKey) {
    final List<ScaleMeasurementEntity> matches = getScaleMeasurements()
        .where((ScaleMeasurementEntity item) => item.dateKey == dateKey)
        .toList();
    if (matches.isEmpty) {
      return null;
    }
    matches.sort((ScaleMeasurementEntity a, ScaleMeasurementEntity b) {
      final int timeCompare = b.measurementTime.compareTo(a.measurementTime);
      if (timeCompare != 0) {
        return timeCompare;
      }
      return b.updatedAtEpochMs.compareTo(a.updatedAtEpochMs);
    });
    return matches.first;
  }

  ScaleMeasurementEntity? latestScaleOnOrBefore(String dateKey) {
    final List<ScaleMeasurementEntity> matches = getScaleMeasurements()
        .where(
          (ScaleMeasurementEntity item) =>
              item.weightKg != null && item.dateKey.compareTo(dateKey) <= 0,
        )
        .toList();
    if (matches.isEmpty) {
      return null;
    }
    return matches.first;
  }

  List<TapeMeasurementEntryEntity> latestTapeEntriesForCode(String code) {
    final List<TapeMeasurementEntryEntity> entries =
        <TapeMeasurementEntryEntity>[];
    for (final TapeMeasurementEntity measurement in getTapeMeasurements()) {
      entries.addAll(
        getTapeEntries(measurement.id).where(
          (TapeMeasurementEntryEntity entry) =>
              entry.measurementCode == code && entry.valueCm != null,
        ),
      );
    }
    return entries;
  }

  ScaleMeasurementEntity? latestScale() {
    final List<ScaleMeasurementEntity> items = getScaleMeasurements();
    return items.isEmpty ? null : items.first;
  }

  TapeMeasurementEntity? latestTape() {
    final List<TapeMeasurementEntity> items = getTapeMeasurements();
    return items.isEmpty ? null : items.first;
  }

  ScaleMeasurementEntity saveScale(ScaleMeasurementEntity measurement) {
    _normalizeScale(measurement);
    _prepareScale(measurement);
    measurement.id = _scaleBox.put(measurement);
    return measurement;
  }

  TapeMeasurementEntity saveTapeWithEntries(
    TapeMeasurementEntity measurement,
    List<TapeMeasurementEntryEntity> entries,
  ) {
    return _store.runInTransaction(TxMode.write, () {
      _normalizeTape(measurement);
      _prepareTape(measurement);
      measurement.id = _tapeBox.put(measurement);
      final List<int> oldEntryIds = getTapeEntries(measurement.id)
          .map((TapeMeasurementEntryEntity entry) => entry.id)
          .toList();
      if (oldEntryIds.isNotEmpty) {
        _tapeEntryBox.removeMany(oldEntryIds);
      }
      for (int index = 0; index < entries.length; index += 1) {
        final TapeMeasurementEntryEntity entry = entries[index];
        entry.position = index;
        _prepareTapeEntry(entry);
        entry.tapeMeasurement.target = measurement;
        entry.id = _tapeEntryBox.put(entry);
      }
      return measurement;
    });
  }

  void _prepareScale(ScaleMeasurementEntity measurement) {
    final int now = _clock.nowEpochMs();
    if (measurement.uuid.trim().isEmpty) {
      measurement.uuid = _uuidGenerator.generate();
    }
    if (measurement.createdAtEpochMs == 0) {
      measurement.createdAtEpochMs = now;
    }
    measurement.updatedAtEpochMs = now;
  }

  void _normalizeScale(ScaleMeasurementEntity measurement) {
    measurement.uuid = measurement.uuid.trim();
    measurement.dateKey = measurement.dateKey.trim();
    measurement.title = measurement.title.trim();
    measurement.weightSourceCode = measurement.weightSourceCode.trim().isEmpty
        ? 'manual'
        : measurement.weightSourceCode.trim();
    measurement.measurementTime = measurement.measurementTime.trim();
    measurement.device = measurement.device.trim();
    measurement.reliabilityCode = measurement.reliabilityCode.trim().isEmpty
        ? 'normal'
        : measurement.reliabilityCode.trim();
    measurement.notes = measurement.notes.trim();
    if (measurement.title.isEmpty) {
      measurement.title = 'Bilancia - ${measurement.dateKey}';
    }
  }

  void _prepareTape(TapeMeasurementEntity measurement) {
    final int now = _clock.nowEpochMs();
    if (measurement.uuid.trim().isEmpty) {
      measurement.uuid = _uuidGenerator.generate();
    }
    if (measurement.createdAtEpochMs == 0) {
      measurement.createdAtEpochMs = now;
    }
    measurement.updatedAtEpochMs = now;
  }

  void _normalizeTape(TapeMeasurementEntity measurement) {
    measurement.uuid = measurement.uuid.trim();
    measurement.dateKey = measurement.dateKey.trim();
    measurement.title = measurement.title.trim();
    measurement.measurementTime = measurement.measurementTime.trim();
    measurement.reliabilityCode = measurement.reliabilityCode.trim().isEmpty
        ? 'normal'
        : measurement.reliabilityCode.trim();
    measurement.notes = measurement.notes.trim();
    if (measurement.title.isEmpty) {
      measurement.title = 'Metro - ${measurement.dateKey}';
    }
  }

  void _prepareTapeEntry(TapeMeasurementEntryEntity entry) {
    final int now = _clock.nowEpochMs();
    if (entry.uuid.trim().isEmpty) {
      entry.uuid = _uuidGenerator.generate();
    }
    if (entry.createdAtEpochMs == 0) {
      entry.createdAtEpochMs = now;
    }
    entry.updatedAtEpochMs = now;
  }
}
