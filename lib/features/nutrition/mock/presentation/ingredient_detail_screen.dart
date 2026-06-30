import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_app_card.dart';
import '../../../../shared/widgets/tt_primary_button.dart';
import '../../../../shared/widgets/tt_section_header.dart';
import '../data/mock_ingredient_catalog.dart';
import '../domain/mock_ingredient.dart';

class IngredientDetailScreen extends StatelessWidget {
  const IngredientDetailScreen({
    required this.ingredientId,
    super.key,
  });

  final String ingredientId;

  @override
  Widget build(BuildContext context) {
    final MockIngredient? ingredient = MockIngredientCatalog.byId(ingredientId);

    if (ingredient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ingrediente')),
        body: const Center(child: Text('Ingrediente non trovato')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettaglio ingrediente'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Modifica',
            onPressed: () => context.push(
              '/ingredients/new/manual',
              extra: ingredient,
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.screenVertical,
          AppSpacing.screenHorizontal,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          Text(
            ingredient.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${ingredient.brand} Â· ${ingredient.quantity}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.xl),
          TtAppCard(
            child: Column(
              children: <Widget>[
                _MainNutritionValue(
                  value: ingredient.kcal100.toStringAsFixed(0),
                  label: 'kcal / 100 ${ingredient.unit}',
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _NutritionMetric(
                        label: 'Proteine',
                        value: '${ingredient.protein100.toStringAsFixed(1)} g',
                      ),
                    ),
                    Expanded(
                      child: _NutritionMetric(
                        label: 'Carboidrati',
                        value: '${ingredient.carbs100.toStringAsFixed(1)} g',
                      ),
                    ),
                    Expanded(
                      child: _NutritionMetric(
                        label: 'Grassi',
                        value: '${ingredient.fat100.toStringAsFixed(1)} g',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Valori nutrizionali'),
          const SizedBox(height: AppSpacing.md),
          TtAppCard(
            child: Column(
              children: <Widget>[
                _DetailRow(
                  label: 'Fibre',
                  value: '${ingredient.fiber100.toStringAsFixed(1)} g',
                ),
                const Divider(height: AppSpacing.xl),
                _DetailRow(
                  label: 'Zuccheri',
                  value: '${ingredient.sugar100.toStringAsFixed(1)} g',
                ),
                const Divider(height: AppSpacing.xl),
                _DetailRow(
                  label: 'Sale',
                  value: '${ingredient.salt100.toStringAsFixed(2)} g',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Informazioni'),
          const SizedBox(height: AppSpacing.md),
          TtAppCard(
            child: Column(
              children: <Widget>[
                _DetailRow(label: 'UnitÃ  base', value: ingredient.unit),
                const Divider(height: AppSpacing.xl),
                _DetailRow(
                  label: 'Barcode',
                  value: ingredient.barcode.isEmpty
                      ? 'Non presente'
                      : ingredient.barcode,
                ),
                const Divider(height: AppSpacing.xl),
                _DetailRow(
                  label: 'Categorie',
                  value: ingredient.categories.join(', '),
                ),
                const Divider(height: AppSpacing.xl),
                _DetailRow(
                  label: 'Origine',
                  value: ingredient.sourceName,
                ),
              ],
            ),
          ),
          if (ingredient.notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sectionGap),
            const TtSectionHeader(title: 'Note'),
            const SizedBox(height: AppSpacing.md),
            TtAppCard(child: Text(ingredient.notes)),
          ],
          const SizedBox(height: AppSpacing.sectionGap),
          TtPrimaryButton(
            label: 'Modifica ingrediente',
            icon: Icons.edit_outlined,
            onPressed: () => context.push(
              '/ingredients/new/manual',
              extra: ingredient,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Archiviazione simulata nella versione mock',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Archivia ingrediente'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MainNutritionValue extends StatelessWidget {
  const _MainNutritionValue({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _NutritionMetric extends StatelessWidget {
  const _NutritionMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}
