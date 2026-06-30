import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_filter_chip.dart';
import '../../../../shared/widgets/tt_search_field.dart';
import '../data/mock_ingredient_catalog.dart';
import '../domain/mock_ingredient.dart';
import 'widgets/ingredient_card.dart';

class IngredientListScreen extends StatefulWidget {
  const IngredientListScreen({super.key});

  @override
  State<IngredientListScreen> createState() => _IngredientListScreenState();
}

class _IngredientListScreenState extends State<IngredientListScreen> {
  String query = '';
  String filter = 'Tutti';

  List<MockIngredient> get filteredItems {
    final String normalizedQuery = query.trim().toLowerCase();

    return MockIngredientCatalog.items.where((MockIngredient item) {
      final bool matchesQuery = normalizedQuery.isEmpty ||
          item.name.toLowerCase().contains(normalizedQuery) ||
          item.brand.toLowerCase().contains(normalizedQuery) ||
          item.barcode.contains(normalizedQuery);

      final bool matchesFilter = filter == 'Tutti' ||
          (filter == 'Manuali' && item.sourceType == 'manuale') ||
          (filter == 'Barcode' && item.sourceType == 'open_food_facts_barcode');

      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<MockIngredient> items = filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingredienti'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Cerca online',
            onPressed: () => context.push('/ingredients/search-online'),
            icon: const Icon(Icons.cloud_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/ingredients/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuovo'),
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
            hintText: 'Cerca ingrediente, marca o barcode...',
            onChanged: (String value) {
              setState(() {
                query = value;
              });
            },
            onFilterPressed: () {},
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <String>['Tutti', 'Manuali', 'Barcode']
                  .map(
                    (String label) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: TtFilterChip(
                        label: label,
                        selected: filter == label,
                        onSelected: (_) {
                          setState(() {
                            filter = label;
                          });
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (items.isEmpty)
            const _EmptyIngredientsState()
          else
            ...items.map(
              (MockIngredient ingredient) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: IngredientCard(
                  ingredient: ingredient,
                  onTap: () => context.push('/ingredients/${ingredient.id}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyIngredientsState extends StatelessWidget {
  const _EmptyIngredientsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.search_off_rounded,
            size: 54,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Nessun ingrediente trovato',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
