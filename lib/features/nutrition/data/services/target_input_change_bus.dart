import 'dart:async';

import '../../../../core/diagnostics/app_diagnostics.dart';

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

  static final StreamController<TargetInputChanged> _inputController =
      StreamController<TargetInputChanged>.broadcast(sync: true);
  static final StreamController<TargetSnapshotsUpdated> _updatedController =
      StreamController<TargetSnapshotsUpdated>.broadcast(sync: true);
  static int _eventSequence = 0;
  static int _published = 0;
  static int _updates = 0;

  static Stream<TargetInputChanged> get inputChanges => _inputController.stream;
  static Stream<TargetSnapshotsUpdated> get snapshotUpdates =>
      _updatedController.stream;

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
    _published += 1;
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
          'subscriberCount': _inputController.hasListener ? 1 : 0,
          'published': _published,
        },
      ),
    );
    if (!_inputController.isClosed) _inputController.add(enriched);
  }

  static void publishUpdated(TargetSnapshotsUpdated event) {
    _updates += 1;
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
          'uiRefreshes': _updatedController.hasListener ? 1 : 0,
          'updates': _updates,
        },
      ),
    );
    if (!_updatedController.isClosed) _updatedController.add(event);
  }

  static String _nextEventId(String prefix) {
    _eventSequence += 1;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_eventSequence';
  }

  static String _privacyHash(String? value) {
    final String input = value?.trim() ?? '';
    if (input.isEmpty) return '';
    int hash = 0x811c9dc5;
    for (final int unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
