import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diagnostics session identity includes current schema versions', () {
    final String diagnostics =
        File('lib/core/diagnostics/app_diagnostics.dart').readAsStringSync();

    for (final String token in <String>[
      'diagnosticsSchemaVersion',
      'appVersion',
      'buildNumber',
      'transferSchemaVersion',
      'objectBoxModelVersion',
      'buildMode',
    ]) {
      expect(diagnostics, contains(token));
    }
  });

  test('pubsub diagnostics hash entity identifiers', () {
    final String targetBus = File(
      'lib/features/nutrition/data/services/target_input_change_bus.dart',
    ).readAsStringSync();

    expect(targetBus, contains('sourceUuidHash'));
    expect(targetBus, contains('_privacyHash'));
    expect(targetBus, isNot(contains("'sourceEntityUuid':")));
  });
}
