import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_search_field.dart';
import '../data/mock_tracking_catalog.dart';
import '../domain/mock_tracking_models.dart';
import 'widgets/mock_tracking_widgets.dart';

class MealsScreen extends StatefulWidget {
  const MealsScreen({super.key});

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final String normalized = query.trim().toLowerCase();
    final List<MockMeal> meals = MockTrackingCatalog.meals
        .where(
          (MockMeal meal) =>
              normalized.isEmpty ||
              meal.title.toLowerCase().contains(normalized) ||
              meal.mealType.toLowerCase().contains(normalized),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Pasti')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/forms/meal'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuovo pasto'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.screenVertical,
          AppSpacing.screenHorizontal,
          100,
        ),
        children: <Widget>[
          TtSearchField(
            hintText: 'Cerca pasto...',
            onChanged: (String value) => setState(() => query = value),
          ),
          const SizedBox(height: AppSpacing.xl),
          ...meals.map(
            (MockMeal meal) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: MockSectionCard(
                title: meal.title,
                subtitle:
                    '${meal.dateLabel} · ${meal.kcal.toStringAsFixed(0)} kcal · '
                    'P ${meal.protein.toStringAsFixed(0)} C ${meal.carbs.toStringAsFixed(0)} G ${meal.fat.toStringAsFixed(0)}',
                icon: Icons.lunch_dining_rounded,
                onTap: () => context.push('/meals/${meal.id}'),
                trailing: MockStatusChip(label: meal.mode),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
