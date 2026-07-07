import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../data/entities/ingredient_entity.dart';

class MealIngredientBatchSelection {
  const MealIngredientBatchSelection({
    required this.ingredient,
    required this.grams,
  });

  final IngredientEntity ingredient;
  final double grams;
}

class MealIngredientBatchPickerSheet extends StatefulWidget {
  const MealIngredientBatchPickerSheet({
    required this.ingredients,
    super.key,
  });

  final List<IngredientEntity> ingredients;

  @override
  State<MealIngredientBatchPickerSheet> createState() =>
      _MealIngredientBatchPickerSheetState();
}

class _MealIngredientBatchPickerSheetState
    extends State<MealIngredientBatchPickerSheet> {
  final TextEditingController _queryController = TextEditingController();
  final GlobalKey<FormState> _quantityFormKey = GlobalKey<FormState>();
  final Set<int> _selectedIds = <int>{};
  final Map<int, String> _gramsById = <int, String>{};
  int _step = 0;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<IngredientEntity> get _selectedIngredients => widget.ingredients
      .where((IngredientEntity item) => _selectedIds.contains(item.id))
      .toList(growable: false);
  List<IngredientEntity> get _filteredIngredients {
    final String clean = _queryController.text.trim().toLowerCase();
    if (clean.isEmpty) return const <IngredientEntity>[];
    return widget.ingredients
        .where((IngredientEntity ingredient) {
          return ingredient.name.toLowerCase().contains(clean) ||
              ingredient.brand.toLowerCase().contains(clean) ||
              ingredient.barcode.toLowerCase().contains(clean);
        })
        .take(10)
        .toList(growable: false);
  }

  void _toggle(IngredientEntity ingredient) {
    setState(() {
      if (_selectedIds.remove(ingredient.id)) {
        _gramsById.remove(ingredient.id);
      } else {
        _selectedIds.add(ingredient.id);
        _gramsById.putIfAbsent(ingredient.id, () => '100');
      }
    });
  }

  void _continue() {
    if (_selectedIds.isEmpty) return;
    if (_step == 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _step = 1);
      return;
    }
    if (!(_quantityFormKey.currentState?.validate() ?? false)) return;
    final List<MealIngredientBatchSelection> result =
        <MealIngredientBatchSelection>[
      for (final IngredientEntity ingredient in _selectedIngredients)
        MealIngredientBatchSelection(
          ingredient: ingredient,
          grams: double.parse(
            (_gramsById[ingredient.id] ?? '100').replaceAll(',', '.'),
          ),
        ),
    ];
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop<List<MealIngredientBatchSelection>>(result);
  }

  @override
  Widget build(BuildContext context) {
    final List<IngredientEntity> selected = _selectedIngredients;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.48,
      maxChildSize: 0.96,
      builder: (BuildContext context, ScrollController scrollController) {
        return SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _step == 0
                                ? 'Seleziona alimenti'
                                : 'Inserisci le quantità',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            '${_selectedIds.length} selezionati',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Chiudi',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _step == 0
                    ? _buildSelectionList(context, scrollController)
                    : _buildQuantityList(context, scrollController, selected),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          if (_step == 0) {
                            Navigator.of(context).pop();
                          } else {
                            FocusManager.instance.primaryFocus?.unfocus();
                            setState(() => _step = 0);
                          }
                        },
                        icon: Icon(
                          _step == 0
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.arrow_back_rounded,
                        ),
                        label: Text(_step == 0 ? 'Chiudi' : 'Indietro'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _selectedIds.isEmpty ? null : _continue,
                        icon: Icon(
                          _step == 0
                              ? Icons.arrow_forward_rounded
                              : Icons.check_rounded,
                        ),
                        label: Text(_step == 0 ? 'Continua' : 'Conferma'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectionList(
    BuildContext context,
    ScrollController scrollController,
  ) {
    final List<IngredientEntity> filtered = _filteredIngredients;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      children: <Widget>[
        TextField(
          controller: _queryController,
          decoration: const InputDecoration(
            labelText: 'Cerca per nome, brand o barcode',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.md),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: Text(
                _queryController.text.trim().isEmpty
                    ? 'Usa la barra di ricerca per caricare fino a 10 alimenti.'
                    : 'Nessun alimento trovato.',
              ),
            ),
          )
        else
          for (final IngredientEntity ingredient in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: CheckboxListTile(
                  value: _selectedIds.contains(ingredient.id),
                  onChanged: (_) => _toggle(ingredient),
                  title: Text(ingredient.name),
                  subtitle: Text(
                    ingredient.brand.trim().isEmpty
                        ? '${ingredient.kcalPerReference.round()} kcal / 100 g'
                        : ingredient.brand,
                  ),
                  secondary: const Icon(Icons.inventory_2_outlined),
                  controlAffinity: ListTileControlAffinity.trailing,
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildQuantityList(
    BuildContext context,
    ScrollController scrollController,
    List<IngredientEntity> selected,
  ) {
    return Form(
      key: _quantityFormKey,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        children: <Widget>[
          for (final IngredientEntity ingredient in selected)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.inventory_2_outlined),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              ingredient.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (ingredient.brand.trim().isNotEmpty)
                              Text(
                                ingredient.brand,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      SizedBox(
                        width: 112,
                        child: TextFormField(
                          key: ValueKey<String>('grams-${ingredient.id}'),
                          initialValue: _gramsById[ingredient.id] ?? '100',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Quantità',
                            suffixText: 'g',
                          ),
                          onChanged: (String value) {
                            _gramsById[ingredient.id] = value;
                          },
                          validator: (String? value) {
                            final double? grams = double.tryParse(
                              (value ?? '').trim().replaceAll(',', '.'),
                            );
                            if (grams == null || grams <= 0) {
                              return 'Valore non valido';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
