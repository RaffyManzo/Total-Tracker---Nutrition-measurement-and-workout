import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/app/app.dart';

void main() {
  testWidgets('shows the persistent app home hubs',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TotalTrackerApp()));

    expect(find.text('Total Tracker'), findsOneWidget);
    expect(find.text('Alimentazione e monitoraggio'), findsOneWidget);
    expect(find.text('Allenamento'), findsOneWidget);
  });
}
