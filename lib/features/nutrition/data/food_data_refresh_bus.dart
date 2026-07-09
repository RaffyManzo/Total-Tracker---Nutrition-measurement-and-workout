import 'dart:async';

import '../../../core/diagnostics/app_diagnostics.dart';
import '../../../core/diagnostics/tracked_broadcast_bus.dart';

enum FoodDataChangeKind {
  meal,
  dailyRecord,
  manualRefresh,
}

class FoodDataChange {
  const FoodDataChange({
    required this.kind,
    required this.dateKey,
    required this.revision,
    required this.eventId,
    required this.publishedAtEpochMs,
    this.currentCalories,
    this.steps,
    this.reason = '',
    this.operationId = '',
    this.coalescedEventCount = 0,
  });

  final FoodDataChangeKind kind;
  final String dateKey;
  final int revision;
  final String eventId;
  final int publishedAtEpochMs;
  final double? currentCalories;
  final int? steps;
  final String reason;
  final String operationId;
  final int coalescedEventCount;
}

class FoodDataRefreshBus {
  FoodDataRefreshBus._();

  static final TrackedBroadcastBus<FoodDataChange> _bus =
      TrackedBroadcastBus<FoodDataChange>();
  static int _revision = 0;
  static int _eventSequence = 0;
  static FoodDataChange? _lastChange;

  static Stream<FoodDataChange> get changes => _bus.stream;
  static int get revision => _revision;
  static FoodDataChange? get lastChange => _lastChange;
  static int get publishedCount => _bus.metrics.publishedEvents;
  static int get subscriberCount => _bus.metrics.registeredSubscribers;
  static int get pendingDeliveries => _bus.metrics.pendingDeliveries;
  static TrackedBroadcastMetrics get runtimeMetrics => _bus.metrics;

  static void publishMeal({
    required String dateKey,
    required double currentCalories,
    String reason = 'meal_changed',
    String operationId = '',
  }) {
    _publish(
      FoodDataChange(
        kind: FoodDataChangeKind.meal,
        dateKey: dateKey,
        currentCalories: currentCalories,
        revision: ++_revision,
        eventId: _nextEventId('food'),
        publishedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        reason: reason,
        operationId: operationId,
      ),
    );
  }

  static void publishDailyRecord({
    required String dateKey,
    required int steps,
    String reason = 'daily_record_changed',
    String operationId = '',
  }) {
    _publish(
      FoodDataChange(
        kind: FoodDataChangeKind.dailyRecord,
        dateKey: dateKey,
        steps: steps,
        revision: ++_revision,
        eventId: _nextEventId('food'),
        publishedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        reason: reason,
        operationId: operationId,
      ),
    );
  }

  static void publishManualRefresh(
    String dateKey, {
    String operationId = '',
  }) {
    _publish(
      FoodDataChange(
        kind: FoodDataChangeKind.manualRefresh,
        dateKey: dateKey,
        revision: ++_revision,
        eventId: _nextEventId('food'),
        publishedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        reason: 'manual_refresh',
        operationId: operationId,
      ),
    );
  }

  static void _publish(FoodDataChange change) {
    _lastChange = change;
    _bus.publish(change);
    final TrackedBroadcastMetrics metrics = _bus.metrics;
    unawaited(
      AppDiagnostics.instance.info(
        'pubsub.food.publish',
        data: <String, Object?>{
          'eventId': change.eventId,
          'operationId': change.operationId,
          'kind': change.kind.name,
          'dateFrom': change.dateKey,
          'dateTo': change.dateKey,
          'reason': change.reason,
          'revision': change.revision,
          ...metrics.toJson(),
          'hasCalories': change.currentCalories != null,
          'hasSteps': change.steps != null,
        },
      ),
    );
  }

  static void recordSubscriberRun(
    String subscriberName,
    FoodDataChange change, {
    bool skipped = false,
  }) {
    if (skipped) {
      _bus.recordSkipped();
    }
    unawaited(
      AppDiagnostics.instance.info(
        'pubsub.food.subscriber',
        data: <String, Object?>{
          'eventId': change.eventId,
          'operationId': change.operationId,
          'subscriberName': subscriberName,
          'kind': change.kind.name,
          'dateFrom': change.dateKey,
          'dateTo': change.dateKey,
          'queueWaitMs':
              DateTime.now().millisecondsSinceEpoch - change.publishedAtEpochMs,
          'skipped': skipped,
          ..._bus.metrics.toJson(),
        },
      ),
    );
  }

  static void debugResetMetricsForTests() => _bus.resetMetricsForTests();

  static String _nextEventId(String prefix) {
    _eventSequence += 1;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_eventSequence';
  }
}
