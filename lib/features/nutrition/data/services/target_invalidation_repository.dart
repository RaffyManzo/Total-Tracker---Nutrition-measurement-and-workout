import 'package:objectbox/objectbox.dart';

import '../entities/nutrition_tracking_entities.dart';

class TargetInvalidationBatch {
  const TargetInvalidationBatch({
    required this.entities,
    required this.fromDateKey,
    required this.toDateKey,
    required this.isOpenEnded,
    required this.reasonCodes,
    required this.inputRevisionSeed,
  });

  final List<TargetInvalidationEntity> entities;
  final String fromDateKey;
  final String toDateKey;
  final bool isOpenEnded;
  final List<String> reasonCodes;
  final String inputRevisionSeed;
}

class TargetInvalidationRepository {
  TargetInvalidationRepository(this._store);

  static const int maxFailureCount = 3;

  final Store _store;
  Box<TargetInvalidationEntity> get _box =>
      _store.box<TargetInvalidationEntity>();

  void recoverInterrupted() {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final List<TargetInvalidationEntity> interrupted = _box
        .getAll()
        .where((item) => item.statusCode == 'processing')
        .toList(growable: false);
    if (interrupted.isEmpty) return;
    for (final TargetInvalidationEntity item in interrupted) {
      item.statusCode = 'pending';
      item.startedAtEpochMs = null;
      item.updatedAtEpochMs = now;
      item.lastErrorCode = 'recovered_after_interruption';
    }
    _box.putMany(interrupted);
  }

  List<TargetInvalidationEntity> pending() {
    final List<TargetInvalidationEntity> result = _box
        .getAll()
        .where((item) => item.statusCode == 'pending')
        .toList(growable: false)
      ..sort((a, b) => a.createdAtEpochMs.compareTo(b.createdAtEpochMs));
    return result;
  }

  TargetInvalidationBatch? acquirePending(
      {required String lastExistingDateKey}) {
    final List<TargetInvalidationEntity> items = pending();
    if (items.isEmpty) return null;
    final int now = DateTime.now().millisecondsSinceEpoch;
    _store.runInTransaction(TxMode.write, () {
      for (final TargetInvalidationEntity item in items) {
        item.statusCode = 'processing';
        item.startedAtEpochMs = now;
        item.updatedAtEpochMs = now;
      }
      _box.putMany(items);
    });

    String from = items.first.fromDateKey;
    String to = items.first.toDateKey;
    bool openEnded = to.isEmpty;
    final Set<String> reasons = <String>{};
    for (final TargetInvalidationEntity item in items) {
      if (item.fromDateKey.compareTo(from) < 0) from = item.fromDateKey;
      if (item.toDateKey.isEmpty) {
        openEnded = true;
      } else if (!openEnded && item.toDateKey.compareTo(to) > 0) {
        to = item.toDateKey;
      }
      if (item.reasonCode.trim().isNotEmpty) reasons.add(item.reasonCode);
    }
    if (openEnded) to = lastExistingDateKey;
    final List<String> revisionParts = items
        .map(
          (item) => <String>[
            item.kindCode,
            item.reasonCode,
            item.sourceEntityUuid,
            item.sourceRevision.toString(),
            item.fromDateKey,
            item.toDateKey,
          ].join(':'),
        )
        .toList(growable: false)
      ..sort();
    return TargetInvalidationBatch(
      entities: List<TargetInvalidationEntity>.unmodifiable(items),
      fromDateKey: from,
      toDateKey: to,
      isOpenEnded: openEnded,
      reasonCodes: reasons.toList()..sort(),
      inputRevisionSeed: revisionParts.join('|'),
    );
  }

  void complete(TargetInvalidationBatch batch) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    _store.runInTransaction(TxMode.write, () {
      for (final TargetInvalidationEntity item in batch.entities) {
        item.statusCode = 'completed';
        item.completedAtEpochMs = now;
        item.updatedAtEpochMs = now;
        item.lastErrorCode = '';
      }
      _box.putMany(batch.entities);
    });
  }

  void fail(TargetInvalidationBatch batch, Object error) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final String code = error.runtimeType.toString();
    _store.runInTransaction(TxMode.write, () {
      for (final TargetInvalidationEntity item in batch.entities) {
        item.failureCount += 1;
        item.statusCode =
            item.failureCount >= maxFailureCount ? 'failed' : 'pending';
        item.updatedAtEpochMs = now;
        item.lastErrorCode = code;
      }
      _box.putMany(batch.entities);
    });
  }

  void retryFailed() {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final List<TargetInvalidationEntity> failed = _box
        .getAll()
        .where((item) => item.statusCode == 'failed')
        .toList(growable: false);
    if (failed.isEmpty) return;
    for (final TargetInvalidationEntity item in failed) {
      item.statusCode = 'pending';
      item.failureCount = 0;
      item.lastErrorCode = '';
      item.updatedAtEpochMs = now;
    }
    _box.putMany(failed);
  }
}
