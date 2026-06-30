import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_search_field.dart';
import '../data/mock_tracking_catalog.dart';
import '../domain/mock_tracking_models.dart';
import 'widgets/mock_tracking_widgets.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final String normalized = query.trim().toLowerCase();
    final List<MockRecipe> recipes = MockTrackingCatalog.recipes
        .where(
          (MockRecipe recipe) =>
              normalized.isEmpty ||
              recipe.title.toLowerCase().contains(normalized) ||
              recipe.tags.any(
                (String tag) => tag.toLowerCase().contains(normalized),
              ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Ricette')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/forms/recipe'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuova ricetta'),
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
            hintText: 'Cerca ricetta o tag...',
            onChanged: (String value) => setState(() => query = value),
          ),
          const SizedBox(height: AppSpacing.xl),
          ...recipes.map(
            (MockRecipe recipe) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: MockSectionCard(
                title: recipe.title,
                subtitle:
                    '${recipe.subtitle} · ${recipe.kcalPerServing.toStringAsFixed(0)} kcal/porzione · ${recipe.totalMinutes} min',
                icon: Icons.menu_book_rounded,
                onTap: () => context.push('/recipes/${recipe.id}'),
                trailing: MockStatusChip(label: recipe.difficulty),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
