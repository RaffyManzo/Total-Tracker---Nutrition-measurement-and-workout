import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/presentation/unified_ingredient_search_screen.dart';

void main() {
  testWidgets(
    'refresh host recreates a dependent child without lifecycle assertions',
    (WidgetTester tester) async {
      int builds = 0;
      int disposals = 0;

      Widget buildApp(int revision) {
        return MaterialApp(
          home: Scaffold(
            body: OpenNutritionImportChildHost(
              revision: revision,
              builder: (BuildContext context, int currentRevision) {
                builds += 1;
                return _InheritedDependentProbe(
                  key: ValueKey<int>(currentRevision),
                  revision: currentRevision,
                  onDispose: () => disposals += 1,
                );
              },
            ),
          ),
        );
      }

      await tester.pumpWidget(buildApp(0));
      expect(find.text('Revision 0'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(buildApp(1));
      await tester.pump();

      expect(find.text('Revision 1'), findsOneWidget);
      expect(find.text('Revision 0'), findsNothing);
      expect(builds, greaterThanOrEqualTo(2));
      expect(disposals, 1);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}

class _InheritedDependentProbe extends StatefulWidget {
  const _InheritedDependentProbe({
    required this.revision,
    required this.onDispose,
    super.key,
  });

  final int revision;
  final VoidCallback onDispose;

  @override
  State<_InheritedDependentProbe> createState() =>
      _InheritedDependentProbeState();
}

class _InheritedDependentProbeState extends State<_InheritedDependentProbe> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium;
    return Text(
      'Revision ${widget.revision}',
      style: style,
    );
  }
}
