import 'dart:async';

enum TargetInputChangeKind {
  meal,
  dailyActivity,
  scaleMeasurement,
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
  });

  final TargetInputChangeKind kind;
  final String fromDateKey;
  final String? toDateKey;
  final String reasonCode;
  final int sourceRevision;
  final String? sourceEntityUuid;
}

class TargetSnapshotsUpdated {
  const TargetSnapshotsUpdated({
    required this.fromDateKey,
    required this.toDateKey,
    required this.updatedDays,
    required this.skippedDays,
    required this.triggerReasons,
  });

  final String fromDateKey;
  final String toDateKey;
  final int updatedDays;
  final int skippedDays;
  final List<String> triggerReasons;
}

class TargetInputChangeBus {
  TargetInputChangeBus._();

  static final StreamController<TargetInputChanged> _inputController =
      StreamController<TargetInputChanged>.broadcast(sync: true);
  static final StreamController<TargetSnapshotsUpdated> _updatedController =
      StreamController<TargetSnapshotsUpdated>.broadcast(sync: true);

  static Stream<TargetInputChanged> get inputChanges => _inputController.stream;
  static Stream<TargetSnapshotsUpdated> get snapshotUpdates =>
      _updatedController.stream;

  static void publishInput(TargetInputChanged event) {
    if (!_inputController.isClosed) _inputController.add(event);
  }

  static void publishUpdated(TargetSnapshotsUpdated event) {
    if (!_updatedController.isClosed) _updatedController.add(event);
  }
}
