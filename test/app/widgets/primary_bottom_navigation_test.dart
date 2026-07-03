import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/app/widgets/primary_bottom_navigation.dart';
import 'package:total_tracker/shared/widgets/tt_global_nav_fab.dart';

void main() {
  testWidgets('legacy wrapper renders the global navigation surface',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: PrimaryBottomNavigation(
            currentSection: 'food',
          ),
        ),
      ),
    );

    expect(find.byType(TtFoodBottomNavBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.manage_accounts_outlined), findsOneWidget);
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
  });
}
