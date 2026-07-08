import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transfer coverage audit records current schema acceptance markers', () {
    final String audit = File('TRANSFER_COVERAGE_AUDIT.md').readAsStringSync();

    for (final String token in <String>[
      'APP_VERSION_BASE=0.1.0+19',
      'TRANSFER_SCHEMA_VERSION=2',
      'TRANSFER_CURRENT_MODEL_COVERAGE=COMPLETE_ACTIVE_PORTABLE_STATE',
      'TRANSFER_PREVIOUS_VERSION_IMPORT=COVERED_BY_CODEC_VERSION_1_COMPAT',
      'TRANSFER_EMPTY_STORE_ROUNDTRIP=COVERED_BY_TRANSFER_TESTS',
      'TRANSFER_CORRUPTION_ROLLBACK=COVERED_BY_CODEC_SECURITY_TESTS',
      'ScaleMeasurementEntity',
      'TapeMeasurementEntity',
      'Workout',
    ]) {
      expect(audit, contains(token));
    }
  });
}
