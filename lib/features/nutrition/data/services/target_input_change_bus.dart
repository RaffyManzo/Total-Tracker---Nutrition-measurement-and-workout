import 'dart:async';

import '../../../../core/diagnostics/app_diagnostics.dart';
import '../../../../core/diagnostics/tracked_broadcast_bus.dart';

enum TargetInputChangeKind {
  meal,
  dailyActivity,
  scaleMeasurement,
  tapeMeasurement,
  workout,
  profile,
  modelPolicy,
  importBatch,
  manualHistoricalRecalculation,
}

class TargetInputChanged {
  const TargetInputChanged({
    required this.kind,
    required this.fromDateKey,
    this.toDateKey,
    required this.reasonCode,
    required this.sourceRevision,
    this.sourceEntityUuid,
    this.eventId = '',
    this.operationId = '',
    this.publishedAtEpochMs = 0,
  });

  final TargetInputChangeKind kind;
  final String fromDateKey;
  final String? toDateKey;
  final String reasonCode;
  final int sourceRevision;
  final String? sourceEntityUuid;
  final String eventId;
  final String operationId;
  final int publishedAtEpochMs;
}

class TargetSnapshotsUpdated {
  const TargetSnapshotsUpdated({
    required this.fromDateKey,
    required this.toDateKey,
    required this.updatedDays,
    required this.skippedDays,
    required this.triggerReasons,
    this.causeEventId = '',
    this.operationId = '',
    this.coalescedEventCount = 0,
    this.queueWaitMs = 0,
    this.recalculationMs = 0,
  });

  final String fromDateKey;
  final String toDateKey;
  final int updatedDays;
  final int skippedDays;
  final List<String> triggerReasons;
  final String causeEventId;
  final String operationId;
  final int coalescedEventCount;
  final int queueWaitMs;
  final int recalculationMs;
}

class TargetInputChangeBus {
  TargetInputChangeBus._();

  static final TrackedBroadcastBus<TargetInputChanged> _inputBus =
      TrackedBroadcastBus<TargetInputChanged>(sync: true);
  static final TrackedBroadcastBus<TargetSnapshotsUpdated> _updatedBus =
      TrackedBroadcastBus<TargetSnapshotsUpdated>(sync: true);

  static int _eventSequence = 0;
  static int _recalculationRequests = 0;
  static int _recalculationExecutions = 0;
  static int _uiRefreshRequests = 0;
  static int _uiRefreshExecutions = 0;

  static Stream<TargetInputChanged> get inputChanges => _inputBus.stream;
  static Stream<TargetSnapshotsUpdated> get snapshotUpdates =>
      _updatedBus.stream;

  static TrackedBroadcastMetrics get inputMetrics => _inputBus.metrics;
  static TrackedBroadcastMetrics get updateMetrics => _updatedBus.metrics;

  static int get recalculationRequests => _recalculationRequests;
  static int get recalculationExecutions => _recalculationExecutions;
  static int get uiRefreshRequests => _uiRefreshRequests;
  static int get uiRefreshExecutions => _uiRefreshExecutions;

  static void publishInput(TargetInputChanged event) {
    final TargetInputChanged enriched =
        event.eventId.isEmpty || event.publishedAtEpochMs == 0
            ? TargetInputChanged(
                kind: event.kind,
                fromDateKey: event.fromDateKey,
                toDateKey: event.toDateKey,
                reasonCode: event.reasonCode,
                sourceRevision: event.sourceRevision,
                sourceEntityUuid: event.sourceEntityUuid,
                eventId: event.eventId.isEmpty
                    ? _nextEventId('target')
                    : event.eventId,
                operationId: event.operationId,
                publishedAtEpochMs: event.publishedAtEpochMs == 0
                    ? DateTime.now().millisecondsSinceEpoch
                    : event.publishedAtEpochMs,
              )
            : event;

    _inputBus.publish(enriched);
    unawaited(
      AppDiagnostics.instance.info(
        'pubsub.target_input.publish',
        data: <String, Object?>{
          'eventId': enriched.eventId,
          'operationId': enriched.operationId,
          'kind': enriched.kind.name,
          'dateFrom': enriched.fromDateKey,
          'dateTo': enriched.toDateKey ?? enriched.fromDateKey,
          'reason': enriched.reasonCode,
          'sourceUuidHash': _privacyHash(enriched.sourceEntityUuid),
          'sourceRevision': enriched.sourceRevision,
          ..._inputBus.metrics.toJson(),
          'recalculationRequests': _recalculationRequests,
          'recalculationExecutions': _recalculationExecutions,
        },
      ),
    );
  }

  static void publishUpdated(TargetSnapshotsUpdated event) {
    _updatedBus.publish(event);
    unawaited(
      AppDiagnostics.instance.info(
        'pubsub.target_input.updated',
        data: <String, Object?>{
          'causeEventId': event.causeEventId,
          'operationId': event.operationId,
          'dateFrom': event.fromDateKey,
          'dateTo': event.toDateKey,
          'updatedDays': event.updatedDays,
          'skippedByInputHash': event.skippedDays,
          'triggerReasonCount': event.triggerReasons.length,
          'coalescedEventCount': event.coalescedEventCount,
          'queueWaitMs': event.queueWaitMs,
          'recalculationMs': event.recalculationMs,
          ..._updatedBus.metrics.toJson(),
          'uiRefreshRequests': _uiRefreshRequests,
          'uiRefreshExecutions': _uiRefreshExecutions,
        },
      ),
    );
  }

  static void recordRecalculationRequested({bool coalesced = false}) {
    _recalculationRequests += 1;
    if (coalesced) {
      _inputBus.recordCoalesced();
    }
  }

  static void recordRecalculationExecution() {
    _recalculationExecutions += 1;
  }

  static void recordUiRefreshRequested() {
    _uiRefreshRequests += 1;
  }

  static void recordUiRefreshExecution() {
    _uiRefreshExecutions += 1;
  }

  static void debugResetMetricsForTests() {
    _inputBus.resetMetricsForTests();
    _updatedBus.resetMetricsForTests();
    _recalculationRequests = 0;
    _recalculationExecutions = 0;
    _uiRefreshRequests = 0;
    _uiRefreshExecutions = 0;
  }

  static String _nextEventId(String prefix) {
    _eventSequence += 1;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_eventSequence';
  }

  static String _privacyHash(String? value) {
    final String input = value?.trim() ?? '';
    if (input.isEmpty) {
      return '';
    }
    var hash = 0x811c9dc5;
    for (final int unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
