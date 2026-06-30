import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_app_card.dart';
import '../../../../shared/widgets/tt_primary_button.dart';
import '../../../../shared/widgets/tt_section_header.dart';
import '../data/mock_tracking_catalog.dart';
import '../domain/mock_tracking_models.dart';
import 'widgets/mock_tracking_widgets.dart';

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({
    required this.recipeId,
    super.key,
  });

  final String recipeId;

  @override
  Widget build(BuildContext context) {
    final MockRecipe? recipe = MockTrackingCatalog.recipeById(recipeId);
    if (recipe == null) {
      return const Scaffold(body: Center(child: Text('Ricetta non trovata')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dettaglio ricetta')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: <Widget>[
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.soup_kitchen_rounded,
              size: 82,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(recipe.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(recipe.subtitle),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            children: recipe.tags
                .map((String tag) => Chip(label: Text(tag)))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          Row(
            children: <Widget>[
              Expanded(
                child: MockMetricTile(
                  label: 'Per porzione',
                  value: '${recipe.kcalPerServing.toStringAsFixed(0)} kcal',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MockMetricTile(
                  label: 'Tempo',
                  value: '${recipe.totalMinutes} min',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Ingredienti'),
          const SizedBox(height: AppSpacing.md),
          TtAppCard(
            child: Column(
              children: recipe.ingredients
                  .map(
                    (String item) => Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: MockInfoRow(label: 'Ingrediente', value: item),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Procedimento'),
          const SizedBox(height: AppSpacing.md),
          TtAppCard(
            child: Column(
              children: List<Widget>.generate(
                recipe.steps.length,
                (int index) => Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      CircleAvatar(
                        radius: 14,
                        child: Text('${index + 1}'),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: Text(recipe.steps[index])),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          TtPrimaryButton(
            label: 'Modifica ricetta',
            icon: Icons.edit_outlined,
            onPressed: () => context.push('/forms/recipe'),
          ),
        ],
      ),
    );
  }
}
