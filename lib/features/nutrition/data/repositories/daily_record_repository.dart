import 'package:objectbox/objectbox.dart';

import '../../../../core/identifiers/uuid_generator.dart';
import '../../../../core/time/clock.dart';
import '../entities/nutrition_tracking_entities.dart';
import '../food_data_refresh_bus.dart';
import '../services/target_input_change_bus.dart';
import '../services/target_input_mutation_service.dart';

class DailyRecordRepository {
  DailyRecordRepository(
    Store store, {
    Clock clock = const Clock(),
    UuidGenerator? uuidGenerator,
  })  : _store = store,
        _clock = clock,
        _uuidGenerator = uuidGenerator ?? UuidGenerator();

  final Store _store;
  final Clock _clock;
  final UuidGenerator _uuidGenerator;

  Box<DailyRecordEntity> get _box => _store.box<DailyRecordEntity>();

  DailyRecordEntity save(DailyRecordEntity record) {
    _normalize(record);
    _validate(record);
    final DailyRecordEntity? stored =
        record.id == 0 ? findByDate(record.dateKey) : _box.get(record.id);
    final int? previousSteps = stored?.steps;
    final int? previousStepGoal = stored?.stepGoal;
    final double? previousActiveEffective = stored?.activeEffectiveKcal;
    final double? previousActiveActual = stored?.activeKcalActual;
    final double? previousActiveReference = stored?.activeRefKcal;
    final double? previousTarget = stored?.targetKcal;
    _prepareForSave(record);
    final bool predictionInputsChanged = stored != null &&
        (previousSteps != record.steps ||
            previousStepGoal != record.stepGoal ||
            previousActiveEffective != record.activeEffectiveKcal ||
            previousActiveActual != record.activeKcalActual ||
            previousActiveReference != record.activeRefKcal ||
            previousTarget != record.targetKcal);
    final bool newRecordWithInputs = stored == null &&
        (record.steps > 0 ||
            record.stepGoal > 0 ||
            (record.activeEffectiveKcal ?? 0) > 0 ||
            (record.activeKcalActual ?? 0) > 0 ||
            (record.activeRefKcal ?? 0) > 0 ||
            (record.targetKcal ?? 0) > 0);
    final bool changed = predictionInputsChanged || newRecordWithInputs;
    _store.runInTransaction(TxMode.write, () {
      record.id = _box.put(record);
      if (changed) {
        TargetInputMutationService.enqueueInCurrentTransaction(
          _store,
          kind: TargetInputChangeKind.dailyActivity,
          fromDateKey: record.dateKey,
          reasonCode: 'daily_record_input_changed',
          sourceEntityUuid: record.uuid,
          sourceRevision: record.updatedAtEpochMs,
        );
      }
    });
    if (changed) {
      TargetInputMutationService.publishAfterCommit(
        kind: TargetInputChangeKind.dailyActivity,
        fromDateKey: record.dateKey,
        reasonCode: 'daily_record_input_changed',
        sourceEntityUuid: record.uuid,
        sourceRevision: record.updatedAtEpochMs,
      );
      FoodDataRefreshBus.publishDailyRecord(
        dateKey: record.dateKey,
        steps: record.steps,
        reason: 'prediction_input_changed',
      );
    }
    return record;
  }

  void saveCalculatedSnapshots(List<DailyRecordEntity> records) {
    if (records.isEmpty) return;
    _store.runInTransaction(TxMode.write, () {
      for (final DailyRecordEntity record in records) {
        _normalize(record);
        _validate(record);
        _prepareForSave(record);
      }
      _box.putMany(records);
    });
  }

  DailyRecordEntity upsertImported(DailyRecordEntity importedRecord) {
    final DailyRecordEntity? existing =
        findByUuid(importedRecord.uuid) ?? findByDate(importedRecord.dateKey);
    if (existing != null) {
      importedRecord.id = existing.id;
      importedRecord.createdAtEpochMs = existing.createdAtEpochMs;
    }
    return save(importedRecord);
  }

  DailyRecordEntity? findByUuid(String uuid) {
    for (final DailyRecordEntity record in _box.getAll()) {
      if (record.uuid == uuid && record.deletedAtEpochMs == null) {
        return record;
      }
    }
    return null;
  }

  DailyRecordEntity? findByDate(String dateKey) {
    for (final DailyRecordEntity record in _box.getAll()) {
      if (record.dateKey == dateKey && record.deletedAtEpochMs == null) {
        return record;
      }
    }
    return null;
  }

  DailyRecordEntity? getById(int id) {
    final DailyRecordEntity? record = _box.get(id);
    if (record == null || record.deletedAtEpochMs != null) {
      return null;
    }
    return record;
  }

  List<DailyRecordEntity> getAllActive() {
    return _box
        .getAll()
        .where((DailyRecordEntity record) => record.deletedAtEpochMs == null)
        .toList()
      ..sort((DailyRecordEntity a, DailyRecordEntity b) {
        return b.dateKey.compareTo(a.dateKey);
      });
  }

  List<DailyRecordEntity> listBetween(String from, String to) {
    return getAllActive()
        .where(
          (DailyRecordEntity record) =>
              record.dateKey.compareTo(from) >= 0 &&
              record.dateKey.compareTo(to) <= 0,
        )
        .toList()
      ..sort((DailyRecordEntity a, DailyRecordEntity b) {
        return a.dateKey.compareTo(b.dateKey);
      });
  }

  DailyRecordEntity? latest() {
    final List<DailyRecordEntity> records = getAllActive();
    if (records.isEmpty) {
      return null;
    }
    return records.first;
  }

  DailyRecordEntity ensureForDate(String dateKey) {
    final DailyRecordEntity? existing = findByDate(dateKey);
    if (existing != null) {
      return existing;
    }
    final DailyRecordEntity record = createEmpty(dateKey);
    record.uuid = 'auto-day:$dateKey';
    return save(record);
  }

  DailyRecordEntity softDelete(DailyRecordEntity record) {
    if (record.id == 0 || _box.get(record.id) == null) {
      throw ArgumentError.value(record.id, 'id', 'Daily record not found.');
    }
    final int now = _clock.nowEpochMs();
    record.deletedAtEpochMs ??= now;
    record.updatedAtEpochMs = now;
    _store.runInTransaction(TxMode.write, () {
      record.id = _box.put(record);
      TargetInputMutationService.enqueueInCurrentTransaction(
        _store,
        kind: TargetInputChangeKind.dailyActivity,
        fromDateKey: record.dateKey,
        reasonCode: 'daily_record_deleted_incremental',
        sourceEntityUuid: record.uuid,
        sourceRevision: now,
      );
    });
    TargetInputMutationService.publishAfterCommit(
      kind: TargetInputChangeKind.dailyActivity,
      fromDateKey: record.dateKey,
      reasonCode: 'daily_record_deleted_incremental',
      sourceEntityUuid: record.uuid,
      sourceRevision: now,
    );
    return record;
  }

  DailyRecordEntity createEmpty(String dateKey) {
    final int now = _clock.nowEpochMs();
    final DateTime date = _requireDate(dateKey);
    return DailyRecordEntity(
      uuid: '',
      dateKey: dateKey,
      weekCode: _isoWeekCode(date),
      weekdayCode: _weekdayCode(date.weekday),
      weekdayLabel: _weekdayLabel(date.weekday),
      weekdayIndex: date.weekday,
      createdAtEpochMs: now,
      updatedAtEpochMs: now,
    );
  }

  void _prepareForSave(DailyRecordEntity record) {
    final int now = _clock.nowEpochMs();
    if (record.uuid.trim().isEmpty) {
      record.uuid = _uuidGenerator.generate();
    }
    if (record.createdAtEpochMs == 0) {
      record.createdAtEpochMs = now;
    }
    record.updatedAtEpochMs = now;
  }

  void _normalize(DailyRecordEntity record) {
    record.uuid = record.uuid.trim();
    record.dateKey = record.dateKey.trim();
    final DateTime date = _requireDate(record.dateKey);
    if (record.weekCode.trim().isEmpty) {
      record.weekCode = _isoWeekCode(date);
    }
    if (record.weekdayCode.trim().isEmpty) {
      record.weekdayCode = _weekdayCode(date.weekday);
    }
    if (record.weekdayLabel.trim().isEmpty) {
      record.weekdayLabel = _weekdayLabel(date.weekday);
    }
    record.weekdayIndex = date.weekday;
    record.targetStatusCode = record.targetStatusCode.trim();
    record.activeStatusCode = record.activeStatusCode.trim();
    record.weightReliabilityCode = record.weightReliabilityCode.trim();
    record.freeMealModeCode = record.freeMealModeCode.trim();
    record.freeMealReliabilityCode = record.freeMealReliabilityCode.trim();
    record.sleepQualityCode = record.sleepQualityCode.trim();
    record.notes = record.notes.trim();
  }

  void _validate(DailyRecordEntity record) {
    _requireDate(record.dateKey);
    if (record.stepGoal < 0 || record.steps < 0) {
      throw ArgumentError.value(
          record.steps, 'steps', 'Steps cannot be negative.');
    }
  }

  DateTime _requireDate(String dateKey) {
    final RegExpMatch? match =
        RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(dateKey);
    if (match == null) {
      throw ArgumentError.value(dateKey, 'dateKey', 'Use YYYY-MM-DD.');
    }
    final int year = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int day = int.parse(match.group(3)!);
    final DateTime date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw ArgumentError.value(dateKey, 'dateKey', 'Invalid calendar date.');
    }
    return date;
  }

  String _weekdayCode(int weekday) {
    return const <int, String>{
      DateTime.monday: 'lunedi',
      DateTime.tuesday: 'martedi',
      DateTime.wednesday: 'mercoledi',
      DateTime.thursday: 'giovedi',
      DateTime.friday: 'venerdi',
      DateTime.saturday: 'sabato',
      DateTime.sunday: 'domenica',
    }[weekday]!;
  }

  String _weekdayLabel(int weekday) {
    return const <int, String>{
      DateTime.monday: 'Lunedi',
      DateTime.tuesday: 'Martedi',
      DateTime.wednesday: 'Mercoledi',
      DateTime.thursday: 'Giovedi',
      DateTime.friday: 'Venerdi',
      DateTime.saturday: 'Sabato',
      DateTime.sunday: 'Domenica',
    }[weekday]!;
  }

  String _isoWeekCode(DateTime date) {
    final int week = _isoWeekNumber(date);
    return '${date.year}-W${week.toString().padLeft(2, '0')}';
  }

  int _isoWeekNumber(DateTime date) {
    final DateTime thursday = date.add(Duration(days: 4 - date.weekday));
    final DateTime firstThursday = DateTime(thursday.year, 1, 4);
    return 1 + thursday.difference(firstThursday).inDays ~/ 7;
  }
}
