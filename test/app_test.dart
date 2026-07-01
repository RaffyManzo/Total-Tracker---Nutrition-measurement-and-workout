import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/app/app.dart';
import 'package:total_tracker/core/database/objectbox_providers.dart';
import 'package:total_tracker/features/nutrition/data/entities/nutrition_tracking_entities.dart';
import 'package:total_tracker/features/nutrition/data/repositories/meal_repository.dart';
import 'package:total_tracker/features/nutrition/data/repositories/measurement_repository.dart';
import 'package:total_tracker/features/nutrition/data/services/food_analytics_service.dart';
import 'package:total_tracker/features/nutrition/presentation/food_v01_screens.dart';
import 'package:total_tracker/features/workout/data/repositories/workout_session_repository.dart';

import 'helpers/objectbox_test_helper.dart';

void main() {
  testWidgets('shows the Food Plan dashboard', (WidgetTester tester) async {
    final database = await openTestDatabase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          objectBoxDatabaseProvider.overrideWithValue(database),
          databaseInitializationStatusProvider.overrideWithValue(
            const DatabaseInitializationStatus.ready(),
          ),
          foodHubV01Provider.overrideWith((ref) async {
            final analytics = FoodAnalyticsService(
              meals: MealRepository(database.store),
              measurements: MeasurementRepository(database.store),
              workoutSessions: WorkoutSessionRepository(database.store),
            );
            return FoodHubV01Data(
              latest: null,
              latestMeals: const <MealWithItems>[],
              allMeals: const <MealWithItems>[],
              days: const <DailyRecordEntity>[],
              ingredients: const [],
              recipes: const [],
              scaleMeasurements: const [],
              tapeMeasurements: const [],
              analytics: analytics,
              adaptiveSummary: analytics.adaptiveSummaryForWeek(
                monday: DateTime(2026, 6, 22),
                allDays: const <DailyRecordEntity>[],
              ),
              profile: null,
            );
          }),
        ],
        child: const TotalTrackerApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Riepilogo giornaliero'), findsOneWidget);
  });
}
