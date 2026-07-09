import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FoodHub lifecycle uses distinct states and real queue metrics', () {
    final String source = File(
      'lib/features/nutrition/presentation/food_v01_screens.dart',
    ).readAsStringSync();

    expect(source, contains('AppLifecycleState.inactive'));
    expect(source, contains('AppLifecycleState.hidden'));
    expect(source, contains('AppLifecycleState.paused'));
    expect(source, contains('AppLifecycleState.resumed'));
    expect(source, contains('AppLifecycleState.detached'));
    expect(source, contains('_resumeReconcileInFlight'));
    expect(source, contains('_resumeReconcilePending'));
    expect(source, contains('lifecycle.resume.coalesced'));
    expect(source, contains('reconcilePasses'));
    expect(
        source, contains('_lastLifecycleState != AppLifecycleState.resumed'));
    expect(source, contains('FoodDataRefreshBus.pendingDeliveries'));
    expect(
        source,
        isNot(contains(
          "'queueDepth': FoodDataRefreshBus.publishedCount",
        )));
    expect(source, isNot(contains("'activeTimers': 0")));
    expect(source, isNot(contains("'activeOverlays': 0")));
  });
}
