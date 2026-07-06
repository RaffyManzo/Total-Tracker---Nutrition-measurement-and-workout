import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup gate forces a versioned and blocking recalculation', () {
    final String gate = File(
      'lib/features/nutrition/presentation/target_recalculation_gate.dart',
    ).readAsStringSync();
    final String app = File('lib/app/app.dart').readAsStringSync();

    expect(app, contains('TargetRecalculationGate'));
    expect(gate, contains('Ricalcolo iniziale dei target'));
    expect(gate, contains('Non chiudere l’app e non cambiare pagina'));
    expect(gate, contains('PopScope'));
    expect(gate, contains('canPop: false'));
    expect(gate, contains('targetSourceHash.startsWith'));
    expect(gate, contains('TargetModelConstants.modelVersion'));
  });

  test('settings save blocks navigation during atomic recalculation', () {
    final String settings = File(
      'lib/features/profile/presentation/profile_settings_screen.dart',
    ).readAsStringSync();

    expect(settings, contains('canPop: !_isApplying'));
    expect(settings, contains('Non chiudere questa pagina'));
    expect(settings, contains('saveWithDailyRecords'));
    expect(settings, contains('Aggiornamento target correnti/futuri'));
  });
}
