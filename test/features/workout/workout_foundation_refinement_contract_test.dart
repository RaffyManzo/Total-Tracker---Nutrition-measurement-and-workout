import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('refinement does not remove workout foundation or calorie contract', () {
    final String transfer = File(
      'lib/features/transfer/data/total_tracker_transfer_service.dart',
    ).readAsStringSync();
    final Directory entities = Directory(
      'lib/features/workout/data/entities',
    );
    expect(entities.existsSync(), isTrue);
    final String workoutSource = entities
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'))
        .map((File file) => file.readAsStringSync())
        .join('\n');

    expect(transfer, contains('workout'));
    expect(workoutSource, contains('estimatedKcalBurned'));
  });
}
