import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_app_card.dart';
import '../../../../shared/widgets/tt_primary_button.dart';
import '../../../../shared/widgets/tt_section_header.dart';
import '../data/mock_tracking_catalog.dart';
import '../domain/mock_tracking_models.dart';
import 'widgets/mock_tracking_widgets.dart';

class MealDetailScreen extends StatelessWidget {
  const MealDetailScreen({
    required this.mealId,
    super.key,
  });

  final String mealId;

  @override
  Widget build(BuildContext context) {
    final MockMeal? meal = MockTrackingCatalog.mealById(mealId);
    if (meal == null) {
      return const Scaffold(body: Center(child: Text('Pasto non trovato')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettaglio pasto'),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.push('/forms/meal'),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: <Widget>[
          Text(meal.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('${meal.dateLabel} · ${meal.mode}'),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: <Widget>[
              Expanded(
                child: MockMetricTile(
                  label: 'Calorie',
                  value: '${meal.kcal.toStringAsFixed(0)} kcal',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: MockMetricTile(
                  label: 'Proteine',
                  value: '${meal.protein.toStringAsFixed(0)} g',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: MockMetricTile(
                  label: 'Carboidrati',
                  value: '${meal.carbs.toStringAsFixed(0)} g',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: MockMetricTile(
                  label: 'Grassi',
                  value: '${meal.fat.toStringAsFixed(0)} g',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Elementi'),
          const SizedBox(height: AppSpacing.md),
          TtAppCard(
            child: Column(
              children: meal.items
                  .map(
                    (String item) => Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: MockInfoRow(label: 'Voce', value: item),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (meal.notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sectionGap),
            const TtSectionHeader(title: 'Note'),
            const SizedBox(height: AppSpacing.md),
            TtAppCard(child: Text(meal.notes)),
          ],
          const SizedBox(height: AppSpacing.xl),
          TtPrimaryButton(
            label: 'Modifica pasto',
            icon: Icons.edit_outlined,
            onPressed: () => context.push('/forms/meal'),
          ),
        ],
      ),
    );
  }
}
