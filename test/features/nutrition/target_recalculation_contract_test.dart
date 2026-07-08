import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'startup host resumes persistent incremental recalculation after database readiness',
    () {
      final String app = File('lib/app/app.dart').readAsStringSync();
      final String host = File(
        'lib/features/nutrition/presentation/'
        'target_recalculation_coordinator_host.dart',
      ).readAsStringSync();
      final String coordinator = File(
        'lib/features/nutrition/data/services/'
        'target_recalculation_coordinator.dart',
      ).readAsStringSync();

      expect(app, contains('TargetRecalculationCoordinatorHost'));
      expect(app, isNot(contains('TargetRecalculationGate')));
      expect(host, contains('databaseInitializationStatusProvider'));
      expect(host, contains('status.isReady'));
      expect(host, contains('coordinator.start()'));
      expect(host, contains('TargetInputChangeBus.snapshotUpdates.listen'));
      expect(coordinator, contains('_invalidations.recoverInterrupted()'));
      expect(coordinator, contains('TargetInputChangeBus.inputChanges.listen'));
      expect(coordinator, contains('schedule(immediate: true)'));
      expect(coordinator, contains('if (_running)'));
      expect(coordinator, contains('_rerunRequested = true'));
      expect(coordinator, contains('pubsub.target_recalculation.started'));
      expect(coordinator, contains('queueWaitMs'));
      expect(coordinator, contains('coalescedEventCount'));
    },
  );

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
