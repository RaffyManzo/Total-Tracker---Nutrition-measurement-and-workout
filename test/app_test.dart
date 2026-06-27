import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/app/app.dart';

void main() {
  testWidgets('shows the initial setup screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TotalTrackerApp()));

    expect(find.text('Total Tracker'), findsOneWidget);
    expect(find.text('Configurazione iniziale completata'), findsOneWidget);
  });
}
