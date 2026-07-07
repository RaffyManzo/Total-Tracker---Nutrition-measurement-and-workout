import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('portable transfer includes current target and scale fields', () {
    final String source = File(
      'lib/features/transfer/data/total_tracker_transfer_service.dart',
    ).readAsStringSync();

    for (final String token in <String>[
      '_dayToMapTheo5',
      '_applyTheo5DayFields(entity, item.data);',
      'targetSourceHash',
      'tdeeTheoreticalKcal',
      'tdeeObservedKcal',
      'observedConfidence',
      'activeKcalWorkoutCompleted',
      'dataCompletenessScore',
      '_scaleToMapTheo5',
      '_applyTheo5ScaleFields(entity, item.data);',
      'bodyFatPercent',
      'muscleMassKg',
      'waterPercent',
      'device',
      'weightAnomalyConfirmationKey',
      'targetModelVersion',
    ]) {
      expect(source, contains(token), reason: 'Missing transfer token: $token');
    }

    expect(source, isNot(contains('_dayFromMapTheo5')));
    expect(source, isNot(contains('_scaleFromMapTheo5')));
    expect(source, contains('id: overwrite ? existing.id : 0'));
    expect(
      source,
      contains('uuid: overwrite ? existing.uuid : _importUuid'),
    );
  });
}
