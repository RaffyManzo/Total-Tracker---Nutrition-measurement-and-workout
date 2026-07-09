import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/app/widgets/delayed_loading_indicator.dart';

void main() {
  testWidgets('does not show for work completed before 200 ms', (
    WidgetTester tester,
  ) async {
    bool loading = true;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            update = setState;
            return DelayedLoadingIndicator(
              isLoading: loading,
              indicator: const Text('loading'),
              child: const Text('content'),
            );
          },
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 199));
    expect(find.text('loading'), findsNothing);
    update(() => loading = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('loading'), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('shows after threshold and respects minimum visible time', (
    WidgetTester tester,
  ) async {
    bool loading = true;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            update = setState;
            return DelayedLoadingIndicator(
              isLoading: loading,
              delay: const Duration(milliseconds: 200),
              minimumVisible: const Duration(milliseconds: 280),
              indicator: const Text('loading'),
              child: const Text('content'),
            );
          },
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('loading'), findsOneWidget);
    update(() => loading = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 279));
    expect(find.text('loading'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('loading'), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('dispose cancels delayed callbacks', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DelayedLoadingIndicator(
          indicator: Text('loading'),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
