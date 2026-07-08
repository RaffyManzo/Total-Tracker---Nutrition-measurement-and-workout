import 'dart:async';

import '../../../../core/diagnostics/app_diagnostics.dart';
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
  int _coalescedEventCount = 0;
  int _lastScheduleEpochMs = 0;
  String _lastCauseEventId = '';
  String _lastOperationId = '';

  void start() {
    if (_subscription != null) return;
    _invalidations.recoverInterrupted();
    _subscription = TargetInputChangeBus.inputChanges.listen(
      (TargetInputChanged event) {
        _coalescedEventCount += 1;
        _lastCauseEventId = event.eventId;
        _lastOperationId = event.operationId;
        _lastScheduleEpochMs = DateTime.now().millisecondsSinceEpoch;
        schedule(cause: event);
      },
    );
    schedule(immediate: true);
  }

  void schedule({bool immediate = false, TargetInputChanged? cause}) {
    _timer?.cancel();
    if (cause != null) {
      unawaited(
        AppDiagnostics.instance.info(
          'pubsub.target_recalculation.scheduled',
          data: <String, Object?>{
            'causeEventId': cause.eventId,
            'operationId': cause.operationId,
            'kind': cause.kind.name,
            'dateFrom': cause.fromDateKey,
            'dateTo': cause.toDateKey ?? cause.fromDateKey,
            'coalescedEventCount': _coalescedEventCount,
          },
        ),
      );
    }
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
        final int drainStartedAt = DateTime.now().millisecondsSinceEpoch;
        final int queueWaitMs = _lastScheduleEpochMs == 0
            ? 0
            : drainStartedAt - _lastScheduleEpochMs;
        final int coalesced = _coalescedEventCount;
        _coalescedEventCount = 0;
        final Stopwatch recalculationWatch = Stopwatch()..start();
        unawaited(
          AppDiagnostics.instance.info(
            'pubsub.target_recalculation.started',
            data: <String, Object?>{
              'causeEventId': _lastCauseEventId,
              'operationId': _lastOperationId,
              'dateFrom': batch.fromDateKey,
              'dateTo': batch.toDateKey,
              'reasonCount': batch.reasonCodes.length,
              'coalescedEventCount': coalesced,
              'queueWaitMs': queueWaitMs,
            },
          ),
        );
        try {
          final TargetRecalculationReport report =
              await _recalculation.recalculateExistingRange(
            fromDateKey: batch.fromDateKey,
            toDateKey: batch.toDateKey,
            inputRevisionSeed: batch.inputRevisionSeed,
          );
          recalculationWatch.stop();
          _invalidations.complete(batch);
          TargetInputChangeBus.publishUpdated(
            TargetSnapshotsUpdated(
              fromDateKey: batch.fromDateKey,
              toDateKey: batch.toDateKey,
              updatedDays: report.updatedDays,
              skippedDays: report.skippedDays,
              triggerReasons: batch.reasonCodes,
              causeEventId: _lastCauseEventId,
              operationId: _lastOperationId,
              coalescedEventCount: coalesced,
              queueWaitMs: queueWaitMs,
              recalculationMs: recalculationWatch.elapsedMilliseconds,
            ),
          );
        } on Object catch (error) {
          recalculationWatch.stop();
          unawaited(
            AppDiagnostics.instance.error(
              'pubsub.target_recalculation.failed',
              error: error,
              data: <String, Object?>{
                'causeEventId': _lastCauseEventId,
                'operationId': _lastOperationId,
                'dateFrom': batch.fromDateKey,
                'dateTo': batch.toDateKey,
                'coalescedEventCount': coalesced,
                'queueWaitMs': queueWaitMs,
                'recalculationMs': recalculationWatch.elapsedMilliseconds,
              },
            ),
          );
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
