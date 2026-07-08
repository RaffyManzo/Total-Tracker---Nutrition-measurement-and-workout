import 'dart:async';

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

/// Opens a persistent, non-modal sheet.
///
/// Unlike [showModalBottomSheet], a persistent sheet has no modal barrier. When
/// the user collapses it, the visible page remains usable while the compact bar
/// clearly communicates that the selection is still active.
Future<List<MealIngredientBatchSelection>?>
    showPersistentMealIngredientBatchPicker(
  BuildContext context, {
  required List<IngredientEntity> ingredients,
}) {
  final Completer<List<MealIngredientBatchSelection>?> completer =
      Completer<List<MealIngredientBatchSelection>?>();
  late final PersistentBottomSheetController controller;

  void complete(List<MealIngredientBatchSelection>? result) {
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  controller = showBottomSheet(
    context: context,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (BuildContext sheetContext) {
      return MealIngredientBatchPickerSheet(
        ingredients: ingredients,
        onConfirm: (List<MealIngredientBatchSelection> result) {
          complete(result);
          controller.close();
        },
        onDiscard: () {
          complete(null);
          controller.close();
        },
      );
    },
  );

  controller.closed.whenComplete(() => complete(null));
  return completer.future;
}

class MealIngredientBatchPickerSheet extends StatefulWidget {
  const MealIngredientBatchPickerSheet({
    required this.ingredients,
    required this.onConfirm,
    required this.onDiscard,
    super.key,
  });

  final List<IngredientEntity> ingredients;
  final ValueChanged<List<MealIngredientBatchSelection>> onConfirm;
  final VoidCallback onDiscard;

  @override
  State<MealIngredientBatchPickerSheet> createState() =>
      _MealIngredientBatchPickerSheetState();
}

class _MealIngredientBatchPickerSheetState
    extends State<MealIngredientBatchPickerSheet> {
  static const double _collapsedExtent = 0.18;
  static const double _middleExtent = 0.48;
  static const double _expandedExtent = 0.92;
  static const List<double> _snapExtents = <double>[
    _collapsedExtent,
    _middleExtent,
    _expandedExtent,
  ];

  final TextEditingController _queryController = TextEditingController();
  final GlobalKey<FormState> _quantityFormKey = GlobalKey<FormState>();
  final Set<int> _selectedIds = <int>{};
  final Map<int, String> _gramsById = <int, String>{};
  final ScrollController _scrollController = ScrollController();

  int _step = 0;
  double _extent = _expandedExtent;
  double _dragStartExtent = _expandedExtent;
  double _dragDeltaDy = 0;

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
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
        .take(25)
        .toList(growable: false);
  }

  bool get _isCollapsed => _extent <= 0.25;

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

  void _setExtent(double value) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _extent = value.clamp(_collapsedExtent, _expandedExtent).toDouble();
    });
  }

  void _onDragStart(DragStartDetails details) {
    _dragStartExtent = _extent;
    _dragDeltaDy = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final double height = MediaQuery.sizeOf(context).height;
    if (height <= 0) return;
    _dragDeltaDy += details.primaryDelta ?? 0;
    final double next = _dragStartExtent - _dragDeltaDy / height;
    setState(() {
      _extent = next.clamp(0.10, _expandedExtent).toDouble();
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_extent < _collapsedExtent && _selectedIds.isEmpty) {
      widget.onDiscard();
      return;
    }
    final double nearest = _snapExtents.reduce(
      (double a, double b) =>
          (_extent - a).abs() <= (_extent - b).abs() ? a : b,
    );
    _setExtent(nearest);
  }

  Future<void> _requestClose() async {
    if (_selectedIds.isEmpty) {
      widget.onDiscard();
      return;
    }
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Scartare la selezione?'),
        content: Text(
          'Hai selezionato ${_selectedIds.length} alimenti. '
          'Puoi mantenere il pannello compresso e continuare a usare la pagina, '
          'oppure scartare le quantità inserite.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Mantieni e comprimi'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Scarta e chiudi'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (discard == true) {
      widget.onDiscard();
    } else {
      _setExtent(_collapsedExtent);
    }
  }

  void _continue() {
    if (_selectedIds.isEmpty) return;
    if (_step == 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _step = 1;
        _extent = _expandedExtent;
      });
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
    widget.onConfirm(result);
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double targetHeight =
        (screenHeight * _extent).clamp(118.0, screenHeight * 0.94).toDouble();
    final ColorScheme colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: _selectedIds.isEmpty,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          if (_isCollapsed) {
            _requestClose();
          } else {
            _setExtent(_collapsedExtent);
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: targetHeight,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child:
              _isCollapsed ? _buildCollapsed(context) : _buildExpanded(context),
        ),
      ),
    );
  }

  Widget _dragHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      onTap: () => _setExtent(_isCollapsed ? _middleExtent : _collapsedExtent),
      child: SizedBox(
        height: 28,
        child: Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsed(BuildContext context) {
    final int count = _selectedIds.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _dragHandle(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  count == 0
                      ? Icons.add_shopping_cart_outlined
                      : Icons.shopping_basket_rounded,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        count == 0
                            ? 'Selettore alimenti aperto'
                            : '$count alimenti mantenuti',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        'Il pannello è compresso: la pagina resta utilizzabile.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Espandi il selettore',
                  onPressed: () => _setExtent(_expandedExtent),
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                ),
                if (count > 0)
                  IconButton.filledTonal(
                    tooltip: _step == 0
                        ? 'Continua con le quantità'
                        : 'Conferma gli alimenti',
                    onPressed: _continue,
                    icon: Icon(
                      _step == 0
                          ? Icons.arrow_forward_rounded
                          : Icons.check_rounded,
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Chiudi il selettore',
                    onPressed: _requestClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpanded(BuildContext context) {
    final List<IngredientEntity> selected = _selectedIngredients;
    return Column(
      children: <Widget>[
        _dragHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
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
                      '${_selectedIds.length} selezionati · trascina in basso per comprimere',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Comprimi mantenendo la selezione',
                onPressed: () => _setExtent(_collapsedExtent),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              IconButton(
                tooltip: 'Chiudi',
                onPressed: _requestClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: _step == 0
              ? _buildSelectionList(context)
              : _buildQuantityList(context, selected),
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
                      _setExtent(_collapsedExtent);
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
                  label: Text(_step == 0 ? 'Comprimi' : 'Indietro'),
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
    );
  }

  Widget _buildSelectionList(BuildContext context) {
    final List<IngredientEntity> filtered = _filteredIngredients;
    return ListView(
      controller: _scrollController,
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
                    ? 'Usa la barra di ricerca per caricare gli alimenti.'
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
    List<IngredientEntity> selected,
  ) {
    return Form(
      key: _quantityFormKey,
      child: ListView(
        controller: _scrollController,
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
