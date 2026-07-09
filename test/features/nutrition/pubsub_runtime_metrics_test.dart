import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/food_data_refresh_bus.dart';
import 'package:total_tracker/features/nutrition/data/services/target_input_change_bus.dart';

void main() {
  test('food bus reports real subscriber count and queue depth', () async {
    FoodDataRefreshBus.debugResetMetricsForTests();
    final List<FoodDataChange> received = <FoodDataChange>[];
    final StreamSubscription<FoodDataChange> first =
        FoodDataRefreshBus.changes.listen(received.add);
    final StreamSubscription<FoodDataChange> second =
        FoodDataRefreshBus.changes.listen(received.add);

    expect(FoodDataRefreshBus.subscriberCount, 2);
    FoodDataRefreshBus.publishManualRefresh('2026-07-09');
    expect(FoodDataRefreshBus.pendingDeliveries, 2);
    await Future<void>.delayed(Duration.zero);
    expect(received, hasLength(2));
    expect(FoodDataRefreshBus.pendingDeliveries, 0);

    await first.cancel();
    expect(FoodDataRefreshBus.subscriberCount, 1);
    await second.cancel();
    expect(FoodDataRefreshBus.subscriberCount, 0);
  });

  test('target bus distinguishes requests, executions and UI refreshes',
      () async {
    TargetInputChangeBus.debugResetMetricsForTests();
    final StreamSubscription<TargetInputChanged> input =
        TargetInputChangeBus.inputChanges.listen((_) {});
    final StreamSubscription<TargetSnapshotsUpdated> update =
        TargetInputChangeBus.snapshotUpdates.listen((_) {});

    TargetInputChangeBus.recordRecalculationRequested();
    TargetInputChangeBus.recordRecalculationRequested(coalesced: true);
    TargetInputChangeBus.recordRecalculationExecution();
    TargetInputChangeBus.recordUiRefreshRequested();
    TargetInputChangeBus.recordUiRefreshExecution();

    TargetInputChangeBus.publishInput(
      const TargetInputChanged(
        kind: TargetInputChangeKind.meal,
        fromDateKey: '2026-07-09',
        reasonCode: 'test',
        sourceRevision: 1,
      ),
    );

    expect(TargetInputChangeBus.inputMetrics.registeredSubscribers, 1);
    expect(TargetInputChangeBus.inputMetrics.coalescedEvents, 1);
    expect(TargetInputChangeBus.recalculationRequests, 2);
    expect(TargetInputChangeBus.recalculationExecutions, 1);
    expect(TargetInputChangeBus.uiRefreshRequests, 1);
    expect(TargetInputChangeBus.uiRefreshExecutions, 1);

    await input.cancel();
    await update.cancel();
  });
}
