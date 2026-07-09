import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/core/diagnostics/tracked_broadcast_bus.dart';

void main() {
  test('counts every subscriber and every pending delivery', () async {
    final TrackedBroadcastBus<int> bus = TrackedBroadcastBus<int>();
    final List<int> first = <int>[];
    final List<int> second = <int>[];
    final StreamSubscription<int> a = bus.stream.listen(first.add);
    final StreamSubscription<int> b = bus.stream.listen(second.add);

    expect(bus.metrics.registeredSubscribers, 2);
    bus.publish(7);
    expect(bus.metrics.pendingDeliveries, 2);

    await Future<void>.delayed(Duration.zero);
    expect(first, <int>[7]);
    expect(second, <int>[7]);
    expect(bus.metrics.pendingDeliveries, 0);
    expect(bus.metrics.callbacksCompleted, 2);

    await a.cancel();
    expect(bus.metrics.registeredSubscribers, 1);
    bus.publish(9);
    await Future<void>.delayed(Duration.zero);
    expect(first, <int>[7]);
    expect(second, <int>[7, 9]);

    bus.recordSkipped(2);
    bus.recordCoalesced(3);
    expect(bus.metrics.callbacksSkipped, 2);
    expect(bus.metrics.coalescedEvents, 3);
    await b.cancel();
    expect(bus.metrics.registeredSubscribers, 0);
  });

  test('paused subscriber contributes to queue depth until cancellation',
      () async {
    final TrackedBroadcastBus<int> bus = TrackedBroadcastBus<int>();
    final StreamSubscription<int> subscription = bus.stream.listen((_) {});
    subscription.pause();

    bus.publish(1);
    bus.publish(2);
    expect(bus.metrics.registeredSubscribers, 1);
    expect(bus.metrics.pendingDeliveries, 2);

    await subscription.cancel();
    expect(bus.metrics.registeredSubscribers, 0);
    expect(bus.metrics.pendingDeliveries, 0);
  });

  test('sync bus drains queue before publish returns', () async {
    final TrackedBroadcastBus<int> bus = TrackedBroadcastBus<int>(sync: true);
    final StreamSubscription<int> subscription = bus.stream.listen((_) {});
    bus.publish(1);
    expect(bus.metrics.pendingDeliveries, 0);
    expect(bus.metrics.callbacksCompleted, 1);
    await subscription.cancel();
  });
}
