import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/app/lifecycle/app_lifecycle_transition_coordinator.dart';

void main() {
  test('distinguishes states, timestamps once and reconciles once', () {
    final AppLifecycleTransitionCoordinator coordinator =
        AppLifecycleTransitionCoordinator();
    final DateTime start = DateTime.utc(2026, 7, 9, 10);

    final LifecycleTransitionDecision inactive = coordinator.transition(
      AppLifecycleState.inactive,
      now: start,
    );
    expect(inactive.shouldReconcile, isFalse);
    expect(coordinator.backgroundedAt, isNull);

    coordinator.transition(
      AppLifecycleState.hidden,
      now: start.add(const Duration(seconds: 1)),
    );
    final DateTime firstBackground = coordinator.backgroundedAt!;
    coordinator.transition(
      AppLifecycleState.paused,
      now: start.add(const Duration(seconds: 2)),
    );
    expect(coordinator.backgroundedAt, firstBackground);

    final LifecycleTransitionDecision duplicatePaused = coordinator.transition(
      AppLifecycleState.paused,
      now: start.add(const Duration(seconds: 3)),
    );
    expect(duplicatePaused.duplicate, isTrue);

    final LifecycleTransitionDecision resumed = coordinator.transition(
      AppLifecycleState.resumed,
      now: start.add(const Duration(seconds: 11)),
    );
    expect(resumed.shouldReconcile, isTrue);
    expect(resumed.backgroundDurationMs, 10000);

    final LifecycleTransitionDecision duplicateResume = coordinator.transition(
      AppLifecycleState.resumed,
      now: start.add(const Duration(seconds: 12)),
    );
    expect(duplicateResume.shouldReconcile, isFalse);
    expect(duplicateResume.duplicate, isTrue);

    coordinator.completeResume(resumed.generation);
    expect(coordinator.resumeInFlight, isFalse);
    expect(coordinator.backgroundedAt, isNull);
  });

  test('detached cancels in-flight resume', () {
    final AppLifecycleTransitionCoordinator coordinator =
        AppLifecycleTransitionCoordinator();
    final DateTime now = DateTime.utc(2026, 7, 9);
    coordinator.transition(AppLifecycleState.paused, now: now);
    coordinator.transition(
      AppLifecycleState.resumed,
      now: now.add(const Duration(seconds: 1)),
    );
    coordinator.transition(
      AppLifecycleState.detached,
      now: now.add(const Duration(seconds: 2)),
    );
    expect(coordinator.detached, isTrue);
    expect(coordinator.resumeInFlight, isFalse);
  });
}
