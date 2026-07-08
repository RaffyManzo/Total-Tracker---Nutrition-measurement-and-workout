import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scale device creation guards async callbacks after route pop', () {
    final String source = File(
      'lib/features/nutrition/presentation/'
      'scale_device_configuration_screen.dart',
    ).readAsStringSync();

    expect(source, contains('finally'));
    expect(source, contains('controller.dispose()'));
    expect(source, contains('if (!mounted || name == null'));
    expect(source, contains('if (!mounted) return;'));
    expect(source, contains('_confirmAssignUnspecified()'));
  });
}
