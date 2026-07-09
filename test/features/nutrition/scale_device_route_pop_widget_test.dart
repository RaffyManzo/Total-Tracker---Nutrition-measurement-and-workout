import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:total_tracker/core/database/objectbox_providers.dart';
import 'package:total_tracker/features/nutrition/presentation/scale_device_configuration_screen.dart';

import '../../helpers/objectbox_test_helper.dart';

const Duration _frameStep = Duration(milliseconds: 50);
const Timeout _widgetTestTimeout = Timeout(Duration(minutes: 1));

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 120,
}) async {
  for (var index = 0; index < maxPumps; index += 1) {
    await tester.pump(_frameStep);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  throw TestFailure(
    'Widget not found after ${maxPumps * _frameStep.inMilliseconds} ms.',
  );
}

Future<void> _pumpFrames(WidgetTester tester, {int count = 20}) async {
  for (var index = 0; index < count; index += 1) {
    await tester.pump(_frameStep);
  }
}

void main() {
  testWidgets(
    'popping the route during device creation has no late callback',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final database = await openTestDatabase();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            objectBoxDatabaseProvider.overrideWithValue(database),
            databaseInitializationStatusProvider.overrideWithValue(
              const DatabaseInitializationStatus.ready(),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const ScaleDeviceConfigurationScreen(),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await _pumpUntilFound(
        tester,
        find.text('Configura nuovo dispositivo'),
      );
      await tester.tap(find.text('Configura nuovo dispositivo').last);
      await _pumpUntilFound(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Test scale');

      final NavigatorState navigator = tester.state<NavigatorState>(
        find.byType(Navigator),
      );
      await tester.tap(find.text('Salva'));
      navigator.pop();
      await _pumpUntilFound(tester, find.text('Open'));
      await _pumpFrames(tester);

      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    timeout: _widgetTestTimeout,
  );

  testWidgets(
    'partial creation can be closed, reopened and completed',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final database = await openTestDatabase();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            objectBoxDatabaseProvider.overrideWithValue(database),
            databaseInitializationStatusProvider.overrideWithValue(
              const DatabaseInitializationStatus.ready(),
            ),
          ],
          child: const MaterialApp(
            home: ScaleDeviceConfigurationScreen(),
          ),
        ),
      );

      await _pumpUntilFound(
        tester,
        find.text('Configura nuovo dispositivo'),
      );
      await tester.tap(find.text('Configura nuovo dispositivo').last);
      await _pumpUntilFound(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Partial scale');
      await tester.binding.handlePopRoute();
      await _pumpUntilFound(
        tester,
        find.text('Configura nuovo dispositivo'),
      );

      expect(find.text('Configura nuovo dispositivo'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Configura nuovo dispositivo').last);
      await _pumpUntilFound(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Completed scale');
      await tester.tap(find.text('Salva'));
      await _pumpUntilFound(tester, find.text('Solo nomi equivalenti'));
      await tester.tap(find.text('Solo nomi equivalenti'));
      await _pumpUntilFound(tester, find.text('Completed scale'));
      await _pumpFrames(tester, count: 4);

      expect(find.text('Completed scale'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
    timeout: _widgetTestTimeout,
  );
}
