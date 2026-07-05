import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../back_navigation.dart';
import '../../features/nutrition/data/services/open_food_facts_service.dart';
import '../../features/nutrition/presentation/food_v01_screens.dart';
import '../../features/nutrition/presentation/ingredient_create_screen.dart';
import '../../features/nutrition/presentation/measurement_screens.dart';
import '../../features/nutrition/presentation/open_food_facts_screens.dart';
import '../../features/nutrition/presentation/open_nutrition_settings_screen.dart';
import '../../features/nutrition/presentation/unified_ingredient_search_screen.dart';
import '../../features/profile/presentation/app_navigation_settings_screen.dart';
import '../../features/profile/presentation/device_permissions_screen.dart';
import '../../features/profile/presentation/food_service_settings_screen.dart';
import '../../features/profile/presentation/notification_settings_screen.dart';
import '../../features/profile/presentation/profile_settings_hub_screen.dart';
import '../../features/profile/presentation/profile_settings_screen.dart';
import '../../features/transfer/presentation/transfer_center_screen.dart';
import '../../features/workout/presentation/workout_screens.dart';

final GoRouter appRouter = _createAppRouter();

GoRouter _createAppRouter() {
  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      ShellRoute(
        builder: (
          BuildContext context,
          GoRouterState state,
          Widget child,
        ) {
          return DashboardBackScope(child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) {
              return const FoodHubScreen();
            },
          ),
          GoRoute(
            path: '/food',
            builder: (BuildContext context, GoRouterState state) {
              return const FoodHubScreen();
            },
          ),
          GoRoute(
            path: '/food/week',
            builder: (BuildContext context, GoRouterState state) {
              return const FoodWeekScreen();
            },
          ),
          GoRoute(
            path: '/food/days',
            builder: (BuildContext context, GoRouterState state) {
              return const FoodDaysScreen();
            },
          ),
          GoRoute(
            path: '/food/days/:date',
            builder: (BuildContext context, GoRouterState state) {
              return FoodDayDetailScreen(date: state.pathParameters['date']!);
            },
          ),
          GoRoute(
            path: '/food/meals',
            builder: (BuildContext context, GoRouterState state) {
              return const FoodMealsScreen();
            },
          ),
          GoRoute(
            path: '/food/meals/:id',
            builder: (BuildContext context, GoRouterState state) {
              return OpenNutritionImportOverlay(
                targetType: 'meal',
                targetId: state.pathParameters['id']!,
                child: FoodMealDetailScreen(
                  id: state.pathParameters['id']!,
                  initialDate: state.uri.queryParameters['date'],
                  initialSlot: state.uri.queryParameters['slot'],
                ),
              );
            },
          ),
          GoRoute(
            path: '/food/ingredients',
            builder: (BuildContext context, GoRouterState state) {
              return const UnifiedIngredientSearchScreen();
            },
          ),
          GoRoute(
            path: '/food/ingredients/search',
            builder: (BuildContext context, GoRouterState state) {
              return UnifiedIngredientSearchScreen(
                selectionMode: state.uri.queryParameters['select'] == '1',
              );
            },
          ),
          GoRoute(
            path: '/food/ingredients/create',
            builder: (BuildContext context, GoRouterState state) {
              return const IngredientCreateScreen();
            },
          ),
          GoRoute(
            path: '/food/ingredients/scan',
            builder: (BuildContext context, GoRouterState state) {
              return const OpenFoodFactsScannerScreen();
            },
          ),
          GoRoute(
            path: '/food/ingredients/off/product/:barcode',
            builder: (BuildContext context, GoRouterState state) {
              return OpenFoodFactsProductPreviewScreen(
                barcode: state.pathParameters['barcode']!,
                initialProduct: state.extra is OpenFoodFactsProduct
                    ? state.extra! as OpenFoodFactsProduct
                    : null,
              );
            },
          ),
          GoRoute(
            path: '/food/ingredients/:id',
            builder: (BuildContext context, GoRouterState state) {
              return IngredientDetailScreen(
                id: state.pathParameters['id']!,
              );
            },
          ),
          GoRoute(
            path: '/food/recipes',
            builder: (BuildContext context, GoRouterState state) {
              return const RecipesScreen();
            },
          ),
          GoRoute(
            path: '/food/recipes/:id',
            builder: (BuildContext context, GoRouterState state) {
              return OpenNutritionImportOverlay(
                targetType: 'recipe',
                targetId: state.pathParameters['id']!,
                child: RecipeDetailScreen(id: state.pathParameters['id']!),
              );
            },
          ),
          GoRoute(
            path: '/settings',
            builder: (BuildContext context, GoRouterState state) {
              return const ProfileSettingsHubScreen();
            },
          ),
          GoRoute(
            path: '/settings/section',
            builder: (BuildContext context, GoRouterState state) {
              return ProfileSettingsScreen(
                sectionCode: state.uri.queryParameters['section'],
              );
            },
          ),
          GoRoute(
            path: '/settings/legacy',
            builder: (BuildContext context, GoRouterState state) {
              return const ProfileSettingsScreen();
            },
          ),
          GoRoute(
            path: '/settings/opennutrition',
            builder: (BuildContext context, GoRouterState state) {
              return const OpenNutritionSettingsScreen();
            },
          ),
          GoRoute(
            path: '/settings/notifications',
            builder: (BuildContext context, GoRouterState state) {
              return const NotificationSettingsScreen();
            },
          ),
          GoRoute(
            path: '/settings/device-permissions',
            builder: (BuildContext context, GoRouterState state) {
              return const DevicePermissionsScreen();
            },
          ),
          GoRoute(
            path: '/settings/food-services',
            builder: (BuildContext context, GoRouterState state) {
              return const FoodServiceSettingsScreen();
            },
          ),
          GoRoute(
            path: '/settings/navigation',
            builder: (BuildContext context, GoRouterState state) {
              return const AppNavigationSettingsScreen();
            },
          ),
          GoRoute(
            path: '/settings/transfer',
            builder: (BuildContext context, GoRouterState state) {
              return const TransferCenterScreen();
            },
          ),
          GoRoute(
            path: '/measurements',
            builder: (BuildContext context, GoRouterState state) {
              return const MeasurementsHubScreen();
            },
          ),
          GoRoute(
            path: '/measurements/scale',
            builder: (BuildContext context, GoRouterState state) {
              return const ScaleMeasurementsScreen();
            },
          ),
          GoRoute(
            path: '/measurements/tape',
            builder: (BuildContext context, GoRouterState state) {
              return const TapeMeasurementsScreen();
            },
          ),
          GoRoute(
            path: '/workout',
            builder: (BuildContext context, GoRouterState state) {
              return const WorkoutHubScreen();
            },
          ),
          GoRoute(
            path: '/workout/exercises',
            builder: (BuildContext context, GoRouterState state) {
              return const WorkoutDisabledScreen();
            },
          ),
          GoRoute(
            path: '/workout/routines',
            builder: (BuildContext context, GoRouterState state) {
              return const WorkoutDisabledScreen();
            },
          ),
          GoRoute(
            path: '/workout/plans',
            builder: (BuildContext context, GoRouterState state) {
              return const WorkoutDisabledScreen();
            },
          ),
          GoRoute(
            path: '/workout/sessions',
            builder: (BuildContext context, GoRouterState state) {
              return const WorkoutDisabledScreen();
            },
          ),
        ],
      ),
    ],
  );
  installDashboardBackDispatcher(router);
  return router;
}
