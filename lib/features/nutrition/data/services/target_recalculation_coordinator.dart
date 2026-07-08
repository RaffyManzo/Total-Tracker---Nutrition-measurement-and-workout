import 'dart:async';

import '../repositories/daily_record_repository.dart';
import 'target_input_change_bus.dart';
import 'target_invalidation_repository.dart';
import 'target_recalculation_service.dart';

class TargetRecalculationCoordinator {
  TargetRecalculationCoordinator({
    required TargetInvalidationRepository invalidations,
    required DailyRecordRepository dailyRecords,
    required TargetRecalculationService recalculation,
    this.debounce = const Duration(milliseconds: 350),
  })  : _invalidations = invalidations,
        _dailyRecords = dailyRecords,
        _recalculation = recalculation;

  final TargetInvalidationRepository _invalidations;
  final DailyRecordRepository _dailyRecords;
  final TargetRecalculationService _recalculation;
  final Duration debounce;

  StreamSubscription<TargetInputChanged>? _subscription;
  Timer? _timer;
  bool _running = false;
  bool _rerunRequested = false;

  void start() {
    if (_subscription != null) return;
    _invalidations.recoverInterrupted();
    _subscription = TargetInputChangeBus.inputChanges.listen((_) => schedule());
    schedule(immediate: true);
  }

  void schedule({bool immediate = false}) {
    _timer?.cancel();
    _timer = Timer(immediate ? Duration.zero : debounce, _drain);
  }

  Future<void> _drain() async {
    if (_running) {
      _rerunRequested = true;
      return;
    }
    _running = true;
    try {
      do {
        _rerunRequested = false;
        final allDays = _dailyRecords.getAllActive();
        if (allDays.isEmpty) return;
        final String lastDateKey = allDays
            .map((day) => day.dateKey)
            .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
        final TargetInvalidationBatch? batch = _invalidations.acquirePending(
          lastExistingDateKey: lastDateKey,
        );
        if (batch == null) return;
        try {
          final TargetRecalculationReport report =
              await _recalculation.recalculateExistingRange(
            fromDateKey: batch.fromDateKey,
            toDateKey: batch.toDateKey,
            inputRevisionSeed: batch.inputRevisionSeed,
          );
          _invalidations.complete(batch);
          TargetInputChangeBus.publishUpdated(
            TargetSnapshotsUpdated(
              fromDateKey: batch.fromDateKey,
              toDateKey: batch.toDateKey,
              updatedDays: report.updatedDays,
              skippedDays: report.skippedDays,
              triggerReasons: batch.reasonCodes,
            ),
          );
        } on Object catch (error) {
          _invalidations.fail(batch, error);
          _rerunRequested = _invalidations.pending().isNotEmpty;
        }
      } while (_rerunRequested || _invalidations.pending().isNotEmpty);
    } finally {
      _running = false;
      if (_rerunRequested) schedule(immediate: true);
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
  }
}
