import 'dart:async';

import '../../../core/diagnostics/app_diagnostics.dart';

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

  static final StreamController<FoodDataChange> _controller =
      StreamController<FoodDataChange>.broadcast();
  static int _revision = 0;
  static int _eventSequence = 0;
  static int _published = 0;
  static FoodDataChange? _lastChange;

  static Stream<FoodDataChange> get changes => _controller.stream;
  static int get revision => _revision;
  static FoodDataChange? get lastChange => _lastChange;
  static int get publishedCount => _published;

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

  static void publishManualRefresh(String dateKey, {String operationId = ''}) {
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
    _published += 1;
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
          'subscriberCount': _controller.hasListener ? 1 : 0,
          'coalescedEventCount': change.coalescedEventCount,
          'hasCalories': change.currentCalories != null,
          'hasSteps': change.steps != null,
          'published': _published,
        },
      ),
    );
    if (!_controller.isClosed) {
      _controller.add(change);
    }
  }

  static void recordSubscriberRun(
    String subscriberName,
    FoodDataChange change, {
    bool skipped = false,
  }) {
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
        },
      ),
    );
  }

  static String _nextEventId(String prefix) {
    _eventSequence += 1;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_eventSequence';
  }
}
