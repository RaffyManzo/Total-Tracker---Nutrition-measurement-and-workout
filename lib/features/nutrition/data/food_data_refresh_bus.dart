import 'dart:async';

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
    this.currentCalories,
    this.steps,
    this.reason = '',
  });

  final FoodDataChangeKind kind;
  final String dateKey;
  final int revision;
  final double? currentCalories;
  final int? steps;
  final String reason;
}

class FoodDataRefreshBus {
  FoodDataRefreshBus._();

  static final StreamController<FoodDataChange> _controller =
      StreamController<FoodDataChange>.broadcast();
  static int _revision = 0;
  static FoodDataChange? _lastChange;

  static Stream<FoodDataChange> get changes => _controller.stream;
  static int get revision => _revision;
  static FoodDataChange? get lastChange => _lastChange;

  static void publishMeal({
    required String dateKey,
    required double currentCalories,
    String reason = 'meal_changed',
  }) {
    _publish(
      FoodDataChange(
        kind: FoodDataChangeKind.meal,
        dateKey: dateKey,
        currentCalories: currentCalories,
        revision: ++_revision,
        reason: reason,
      ),
    );
  }

  static void publishDailyRecord({
    required String dateKey,
    required int steps,
    String reason = 'daily_record_changed',
  }) {
    _publish(
      FoodDataChange(
        kind: FoodDataChangeKind.dailyRecord,
        dateKey: dateKey,
        steps: steps,
        revision: ++_revision,
        reason: reason,
      ),
    );
  }

  static void publishManualRefresh(String dateKey) {
    _publish(
      FoodDataChange(
        kind: FoodDataChangeKind.manualRefresh,
        dateKey: dateKey,
        revision: ++_revision,
        reason: 'manual_refresh',
      ),
    );
  }

  static void _publish(FoodDataChange change) {
    _lastChange = change;
    if (!_controller.isClosed) {
      _controller.add(change);
    }
  }
}
