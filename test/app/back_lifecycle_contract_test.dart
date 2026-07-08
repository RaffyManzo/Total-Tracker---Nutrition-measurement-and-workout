import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android back and lifecycle diagnostics are bounded and resettable', () {
    final String back = File('lib/app/back_navigation.dart').readAsStringSync();
    final String food = File(
      'lib/features/nutrition/presentation/food_v01_screens.dart',
    ).readAsStringSync();

    expect(back, contains('Duration(milliseconds: 1500)'));
    expect(back, contains('Premi di nuovo indietro per uscire'));
    expect(back, contains('void resetExitAttempt()'));
    expect(food, contains('dashboardBackController.resetExitAttempt()'));
    expect(food, contains('lifecycle.resume.started'));
    expect(food, contains('lifecycle.resume.completed'));
    expect(food, contains('activeSubscriptions'));
    expect(food, contains('queueDepth'));
  });
}
