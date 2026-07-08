import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('food and target buses expose causal diagnostics', () {
    final String foodBus =
        File('lib/features/nutrition/data/food_data_refresh_bus.dart')
            .readAsStringSync();
    final String targetBus = File(
      'lib/features/nutrition/data/services/target_input_change_bus.dart',
    ).readAsStringSync();
    final String coordinator = File(
      'lib/features/nutrition/data/services/'
      'target_recalculation_coordinator.dart',
    ).readAsStringSync();

    for (final String token in <String>[
      'eventId',
      'operationId',
      'publishedAtEpochMs',
      'subscriberCount',
      'queueWaitMs',
      'coalescedEventCount',
    ]) {
      expect(foodBus + targetBus + coordinator, contains(token));
    }

    expect(foodBus, contains('pubsub.food.publish'));
    expect(foodBus, contains('pubsub.food.subscriber'));
    expect(targetBus, contains('pubsub.target_input.publish'));
    expect(targetBus, contains('sourceUuidHash'));
    expect(targetBus, contains('skippedByInputHash'));
    expect(coordinator, contains('pubsub.target_recalculation.started'));
  });
}
