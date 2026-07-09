import '../../../../core/identifiers/uuid_generator.dart';
import '../../../../core/pagination/paged_result.dart';
import '../../../../core/time/clock.dart';
import '../../../../objectbox.g.dart';
import '../entities/nutrition_tracking_entities.dart';
import '../services/scale_measurement_validator.dart';
import '../services/target_input_change_bus.dart';
import '../services/target_input_mutation_service.dart';

class MeasurementHistoryItem {
  const MeasurementHistoryItem.scale(this.scale) : tape = null;
  const MeasurementHistoryItem.tape(this.tape) : scale = null;

  final ScaleMeasurementEntity? scale;
  final TapeMeasurementEntity? tape;

  bool get isScale => scale != null;
  String get dateKey => scale?.dateKey ?? tape!.dateKey;
  int get id => scale?.id ?? tape!.id;
  int get updatedAtEpochMs => scale?.updatedAtEpochMs ?? tape!.updatedAtEpochMs;
}

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
    final Query<ScaleMeasurementEntity> query = _scaleBox
        .query(_scalePageCondition())
        .order(
          ScaleMeasurementEntity_.dateKey,
          flags: Order.descending,
        )
        .order(
          ScaleMeasurementEntity_.id,
          flags: Order.descending,
        )
        .build();
    try {
      return query.find();
    } finally {
      query.close();
    }
  }

  List<TapeMeasurementEntity> getTapeMeasurements() {
    final Query<TapeMeasurementEntity> query = _tapeBox
        .query(_tapePageCondition())
        .order(
          TapeMeasurementEntity_.dateKey,
          flags: Order.descending,
        )
        .order(
          TapeMeasurementEntity_.id,
          flags: Order.descending,
        )
        .build();
    try {
      return query.find();
    } finally {
      query.close();
    }
  }

  List<TapeMeasurementEntryEntity> getTapeEntries(int tapeMeasurementId) {
    if (tapeMeasurementId <= 0) {
      return const <TapeMeasurementEntryEntity>[];
    }
    final Query<TapeMeasurementEntryEntity> query = _tapeEntryBox
        .query(
          TapeMeasurementEntryEntity_.deletedAtEpochMs.isNull().and(
                TapeMeasurementEntryEntity_.tapeMeasurement.equals(
                  tapeMeasurementId,
                ),
              ),
        )
        .order(TapeMeasurementEntryEntity_.position)
        .order(TapeMeasurementEntryEntity_.id)
        .build();
    try {
      return query.find();
    } finally {
      query.close();
    }
  }

  ScaleMeasurementEntity? findScaleByDate(String dateKey) {
    final Query<ScaleMeasurementEntity> query = _scaleBox
        .query(
          ScaleMeasurementEntity_.deletedAtEpochMs
              .isNull()
              .and(ScaleMeasurementEntity_.dateKey.equals(dateKey.trim())),
        )
        .order(
          ScaleMeasurementEntity_.measurementTime,
          flags: Order.descending,
        )
        .order(
          ScaleMeasurementEntity_.updatedAtEpochMs,
          flags: Order.descending,
        )
        .order(ScaleMeasurementEntity_.id, flags: Order.descending)
        .build();
    query.limit = 1;
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  ScaleMeasurementEntity? latestScaleOnOrBefore(String dateKey) {
    final Query<ScaleMeasurementEntity> query = _scaleBox
        .query(
          ScaleMeasurementEntity_.deletedAtEpochMs
              .isNull()
              .and(ScaleMeasurementEntity_.weightKg.notNull())
              .and(ScaleMeasurementEntity_.dateKey.lessOrEqual(dateKey)),
        )
        .order(ScaleMeasurementEntity_.dateKey, flags: Order.descending)
        .order(ScaleMeasurementEntity_.id, flags: Order.descending)
        .build();
    query.limit = 1;
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
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
    final PagedResult<ScaleMeasurementEntity> page =
        loadScaleMeasurementPage(page: 1, pageSize: 1);
    return page.items.isEmpty ? null : page.items.first;
  }

  TapeMeasurementEntity? latestTape() {
    final PagedResult<TapeMeasurementEntity> page =
        loadTapeMeasurementPage(page: 1, pageSize: 1);
    return page.items.isEmpty ? null : page.items.first;
  }

  int activeScaleRevision() {
    final Query<ScaleMeasurementEntity> query =
        _scaleBox.query(_scalePageCondition()).build();
    final PropertyQuery<int> propertyQuery =
        query.property(ScaleMeasurementEntity_.updatedAtEpochMs);
    try {
      if (propertyQuery.count() == 0) {
        return 0;
      }
      return propertyQuery.max();
    } finally {
      propertyQuery.close();
      query.close();
    }
  }

  PagedResult<ScaleMeasurementEntity> loadScaleMeasurementPage({
    required int page,
    int pageSize = 10,
    String? fromDateKey,
    String? toDateKey,
  }) {
    final int safePage = PagedResult.normalizePage(page);
    final int safePageSize = PagedResult.normalizePageSize(pageSize);
    final Query<ScaleMeasurementEntity> query = _scaleBox
        .query(
          _scalePageCondition(
            fromDateKey: fromDateKey,
            toDateKey: toDateKey,
          ),
        )
        .order(ScaleMeasurementEntity_.dateKey, flags: Order.descending)
        .order(ScaleMeasurementEntity_.id, flags: Order.descending)
        .build();
    try {
      final int totalCount = query.count();
      query.offset = (safePage - 1) * safePageSize;
      query.limit = safePageSize;
      return PagedResult<ScaleMeasurementEntity>(
        items: query.find(),
        page: safePage,
        pageSize: safePageSize,
        totalCount: totalCount,
      );
    } finally {
      query.close();
    }
  }

  PagedResult<TapeMeasurementEntity> loadTapeMeasurementPage({
    required int page,
    int pageSize = 10,
    String? fromDateKey,
    String? toDateKey,
  }) {
    final int safePage = PagedResult.normalizePage(page);
    final int safePageSize = PagedResult.normalizePageSize(pageSize);
    final Query<TapeMeasurementEntity> query = _tapeBox
        .query(
          _tapePageCondition(
            fromDateKey: fromDateKey,
            toDateKey: toDateKey,
          ),
        )
        .order(TapeMeasurementEntity_.dateKey, flags: Order.descending)
        .order(TapeMeasurementEntity_.id, flags: Order.descending)
        .build();
    try {
      final int totalCount = query.count();
      query.offset = (safePage - 1) * safePageSize;
      query.limit = safePageSize;
      return PagedResult<TapeMeasurementEntity>(
        items: query.find(),
        page: safePage,
        pageSize: safePageSize,
        totalCount: totalCount,
      );
    } finally {
      query.close();
    }
  }

  int countScaleMeasurements({
    String? fromDateKey,
    String? toDateKey,
  }) {
    final Query<ScaleMeasurementEntity> query = _scaleBox
        .query(
          _scalePageCondition(
            fromDateKey: fromDateKey,
            toDateKey: toDateKey,
          ),
        )
        .build();
    try {
      return query.count();
    } finally {
      query.close();
    }
  }

  int countTapeMeasurements({
    String? fromDateKey,
    String? toDateKey,
  }) {
    final Query<TapeMeasurementEntity> query = _tapeBox
        .query(
          _tapePageCondition(
            fromDateKey: fromDateKey,
            toDateKey: toDateKey,
          ),
        )
        .build();
    try {
      return query.count();
    } finally {
      query.close();
    }
  }

  PagedResult<MeasurementHistoryItem> loadMeasurementHistoryPage({
    required int page,
    int pageSize = 10,
    String type = 'all',
    String? fromDateKey,
    String? toDateKey,
  }) {
    final int safePage = PagedResult.normalizePage(page);
    final int safePageSize = PagedResult.normalizePageSize(pageSize);
    final String cleanType = type == 'scale' || type == 'tape' ? type : 'all';
    if (cleanType == 'scale') {
      final PagedResult<ScaleMeasurementEntity> result =
          loadScaleMeasurementPage(
        page: safePage,
        pageSize: safePageSize,
        fromDateKey: fromDateKey,
        toDateKey: toDateKey,
      );
      return PagedResult<MeasurementHistoryItem>(
        items: <MeasurementHistoryItem>[
          for (final ScaleMeasurementEntity item in result.items)
            MeasurementHistoryItem.scale(item),
        ],
        page: result.page,
        pageSize: result.pageSize,
        totalCount: result.totalCount,
      );
    }
    if (cleanType == 'tape') {
      final PagedResult<TapeMeasurementEntity> result = loadTapeMeasurementPage(
        page: safePage,
        pageSize: safePageSize,
        fromDateKey: fromDateKey,
        toDateKey: toDateKey,
      );
      return PagedResult<MeasurementHistoryItem>(
        items: <MeasurementHistoryItem>[
          for (final TapeMeasurementEntity item in result.items)
            MeasurementHistoryItem.tape(item),
        ],
        page: result.page,
        pageSize: result.pageSize,
        totalCount: result.totalCount,
      );
    }

    final int boundedLimit = safePage * safePageSize;
    final Query<ScaleMeasurementEntity> scaleQuery = _scaleBox
        .query(
          _scalePageCondition(
            fromDateKey: fromDateKey,
            toDateKey: toDateKey,
          ),
        )
        .order(ScaleMeasurementEntity_.dateKey, flags: Order.descending)
        .order(ScaleMeasurementEntity_.updatedAtEpochMs,
            flags: Order.descending)
        .order(ScaleMeasurementEntity_.id, flags: Order.descending)
        .build();
    final Query<TapeMeasurementEntity> tapeQuery = _tapeBox
        .query(
          _tapePageCondition(
            fromDateKey: fromDateKey,
            toDateKey: toDateKey,
          ),
        )
        .order(TapeMeasurementEntity_.dateKey, flags: Order.descending)
        .order(TapeMeasurementEntity_.updatedAtEpochMs, flags: Order.descending)
        .order(TapeMeasurementEntity_.id, flags: Order.descending)
        .build();
    try {
      final int totalCount = scaleQuery.count() + tapeQuery.count();
      scaleQuery.limit = boundedLimit;
      tapeQuery.limit = boundedLimit;
      final List<MeasurementHistoryItem> merged = <MeasurementHistoryItem>[
        for (final ScaleMeasurementEntity item in scaleQuery.find())
          MeasurementHistoryItem.scale(item),
        for (final TapeMeasurementEntity item in tapeQuery.find())
          MeasurementHistoryItem.tape(item),
      ]..sort((MeasurementHistoryItem a, MeasurementHistoryItem b) {
          final int dateCompare = b.dateKey.compareTo(a.dateKey);
          if (dateCompare != 0) return dateCompare;
          final int revisionCompare =
              b.updatedAtEpochMs.compareTo(a.updatedAtEpochMs);
          if (revisionCompare != 0) return revisionCompare;
          if (a.isScale != b.isScale) return a.isScale ? -1 : 1;
          return b.id.compareTo(a.id);
        });
      final int offset = (safePage - 1) * safePageSize;
      final List<MeasurementHistoryItem> items = offset >= merged.length
          ? const <MeasurementHistoryItem>[]
          : merged.skip(offset).take(safePageSize).toList(growable: false);
      return PagedResult<MeasurementHistoryItem>(
        items: items,
        page: safePage,
        pageSize: safePageSize,
        totalCount: totalCount,
      );
    } finally {
      tapeQuery.close();
      scaleQuery.close();
    }
  }

  ScaleMeasurementEntity saveScale(ScaleMeasurementEntity measurement) {
    _normalizeScale(measurement);
    const ScaleMeasurementValidator().validateOrThrow(measurement);
    _prepareScale(measurement);
    _store.runInTransaction(TxMode.write, () {
      measurement.id = _scaleBox.put(measurement);
      TargetInputMutationService.enqueueInCurrentTransaction(
        _store,
        kind: TargetInputChangeKind.scaleMeasurement,
        fromDateKey: measurement.dateKey,
        reasonCode: 'scale_measurement_saved',
        sourceEntityUuid: measurement.uuid,
        sourceRevision: measurement.updatedAtEpochMs,
      );
    });
    TargetInputMutationService.publishAfterCommit(
      kind: TargetInputChangeKind.scaleMeasurement,
      fromDateKey: measurement.dateKey,
      reasonCode: 'scale_measurement_saved',
      sourceEntityUuid: measurement.uuid,
      sourceRevision: measurement.updatedAtEpochMs,
    );
    return measurement;
  }

  ScaleMeasurementEntity softDeleteScale(
    ScaleMeasurementEntity measurement,
  ) {
    if (measurement.id == 0 || _scaleBox.get(measurement.id) == null) {
      throw ArgumentError.value(
        measurement.id,
        'id',
        'Scale measurement not found.',
      );
    }
    final int now = _clock.nowEpochMs();
    measurement.deletedAtEpochMs ??= now;
    measurement.updatedAtEpochMs = now;
    _store.runInTransaction(TxMode.write, () {
      measurement.id = _scaleBox.put(measurement);
      TargetInputMutationService.enqueueInCurrentTransaction(
        _store,
        kind: TargetInputChangeKind.scaleMeasurement,
        fromDateKey: measurement.dateKey,
        reasonCode: 'scale_measurement_deleted',
        sourceEntityUuid: measurement.uuid,
        sourceRevision: now,
      );
    });
    TargetInputMutationService.publishAfterCommit(
      kind: TargetInputChangeKind.scaleMeasurement,
      fromDateKey: measurement.dateKey,
      reasonCode: 'scale_measurement_deleted',
      sourceEntityUuid: measurement.uuid,
      sourceRevision: now,
    );
    return measurement;
  }

  TapeMeasurementEntity saveTapeWithEntries(
    TapeMeasurementEntity measurement,
    List<TapeMeasurementEntryEntity> entries,
  ) {
    late final TapeMeasurementEntity savedMeasurement;
    _store.runInTransaction(TxMode.write, () {
      _normalizeTape(measurement);
      _prepareTape(measurement);
      measurement.id = _tapeBox.put(measurement);
      final int now = measurement.updatedAtEpochMs;
      final List<TapeMeasurementEntryEntity> oldEntries =
          getTapeEntries(measurement.id);
      if (oldEntries.isNotEmpty) {
        for (final TapeMeasurementEntryEntity entry in oldEntries) {
          entry.deletedAtEpochMs ??= now;
          entry.updatedAtEpochMs = now;
        }
        _tapeEntryBox.putMany(oldEntries);
      }
      for (int index = 0; index < entries.length; index += 1) {
        final TapeMeasurementEntryEntity entry = entries[index];
        entry.position = index;
        _prepareTapeEntry(entry);
        entry.tapeMeasurement.target = measurement;
        entry.id = _tapeEntryBox.put(entry);
      }
      TargetInputMutationService.enqueueInCurrentTransaction(
        _store,
        kind: TargetInputChangeKind.tapeMeasurement,
        fromDateKey: measurement.dateKey,
        reasonCode: 'tape_measurement_saved',
        sourceEntityUuid: measurement.uuid,
        sourceRevision: measurement.updatedAtEpochMs,
      );
      savedMeasurement = measurement;
    });
    TargetInputMutationService.publishAfterCommit(
      kind: TargetInputChangeKind.tapeMeasurement,
      fromDateKey: savedMeasurement.dateKey,
      reasonCode: 'tape_measurement_saved',
      sourceEntityUuid: savedMeasurement.uuid,
      sourceRevision: savedMeasurement.updatedAtEpochMs,
    );
    return savedMeasurement;
  }

  TapeMeasurementEntity softDeleteTape(
    TapeMeasurementEntity measurement,
  ) {
    if (measurement.id == 0 || _tapeBox.get(measurement.id) == null) {
      throw ArgumentError.value(
        measurement.id,
        'id',
        'Tape measurement not found.',
      );
    }
    final int now = _clock.nowEpochMs();
    measurement.deletedAtEpochMs ??= now;
    measurement.updatedAtEpochMs = now;
    _store.runInTransaction(TxMode.write, () {
      measurement.id = _tapeBox.put(measurement);
      final List<TapeMeasurementEntryEntity> entries =
          getTapeEntries(measurement.id);
      if (entries.isNotEmpty) {
        for (final TapeMeasurementEntryEntity entry in entries) {
          entry.deletedAtEpochMs ??= now;
          entry.updatedAtEpochMs = now;
        }
        _tapeEntryBox.putMany(entries);
      }
      TargetInputMutationService.enqueueInCurrentTransaction(
        _store,
        kind: TargetInputChangeKind.tapeMeasurement,
        fromDateKey: measurement.dateKey,
        reasonCode: 'tape_measurement_deleted',
        sourceEntityUuid: measurement.uuid,
        sourceRevision: now,
      );
    });
    TargetInputMutationService.publishAfterCommit(
      kind: TargetInputChangeKind.tapeMeasurement,
      fromDateKey: measurement.dateKey,
      reasonCode: 'tape_measurement_deleted',
      sourceEntityUuid: measurement.uuid,
      sourceRevision: now,
    );
    return measurement;
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
    final String reliabilityCode =
        measurement.reliabilityCode.trim().toLowerCase();
    measurement.reliabilityCode =
        reliabilityCode == 'low' || reliabilityCode == 'bassa'
            ? 'low'
            : 'normal';
    measurement.weightAnomalyConfirmationKey =
        measurement.weightAnomalyConfirmationKey.trim();
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

  Condition<ScaleMeasurementEntity> _scalePageCondition({
    String? fromDateKey,
    String? toDateKey,
  }) {
    Condition<ScaleMeasurementEntity> condition =
        ScaleMeasurementEntity_.deletedAtEpochMs.isNull();
    final String? cleanFrom = fromDateKey?.trim();
    if (cleanFrom != null && cleanFrom.isNotEmpty) {
      condition = condition.and(ScaleMeasurementEntity_.dateKey.greaterOrEqual(
        cleanFrom,
      ));
    }
    final String? cleanTo = toDateKey?.trim();
    if (cleanTo != null && cleanTo.isNotEmpty) {
      condition = condition.and(ScaleMeasurementEntity_.dateKey.lessOrEqual(
        cleanTo,
      ));
    }
    return condition;
  }

  Condition<TapeMeasurementEntity> _tapePageCondition({
    String? fromDateKey,
    String? toDateKey,
  }) {
    Condition<TapeMeasurementEntity> condition =
        TapeMeasurementEntity_.deletedAtEpochMs.isNull();
    final String? cleanFrom = fromDateKey?.trim();
    if (cleanFrom != null && cleanFrom.isNotEmpty) {
      condition = condition.and(TapeMeasurementEntity_.dateKey.greaterOrEqual(
        cleanFrom,
      ));
    }
    final String? cleanTo = toDateKey?.trim();
    if (cleanTo != null && cleanTo.isNotEmpty) {
      condition = condition.and(TapeMeasurementEntity_.dateKey.lessOrEqual(
        cleanTo,
      ));
    }
    return condition;
  }
}
