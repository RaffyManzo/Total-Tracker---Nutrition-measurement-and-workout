import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/objectbox_providers.dart';
import '../../../shared/widgets/tt_global_nav_fab.dart';
import '../data/entities/ingredient_entity.dart';
import '../data/providers/open_nutrition_providers.dart';
import '../data/services/unified_ingredient_search_service.dart';

class UnifiedIngredientSearchScreen extends ConsumerStatefulWidget {
  const UnifiedIngredientSearchScreen({this.selectionMode = false, super.key});

  final bool selectionMode;

  @override
  ConsumerState<UnifiedIngredientSearchScreen> createState() =>
      _UnifiedIngredientSearchScreenState();
}

class _UnifiedIngredientSearchScreenState
    extends ConsumerState<UnifiedIngredientSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _scope = UnifiedIngredientSearchScopeCodes.all;
  int _page = 0;
  bool _loading = false;
  String _error = '';
  UnifiedIngredientSearchPage _result = const UnifiedIngredientSearchPage(
    items: <UnifiedIngredientSearchItem>[],
    page: 0,
    hasNext: false,
    hasPrevious: false,
  );

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_search);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.selectionMode ? 'Scegli ingrediente' : 'Ingredienti',
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Impostazioni OpenNutrition',
            onPressed: () => context.push('/settings/opennutrition'),
            icon: const Icon(Icons.storage),
          ),
          if (!widget.selectionMode)
            IconButton(
              tooltip: 'Scanner barcode',
              onPressed: () => context.push('/food/ingredients/scan'),
              icon: const Icon(Icons.qr_code_scanner_rounded),
            ),
        ],
      ),
      bottomNavigationBar: widget.selectionMode
          ? null
          : const TtFoodBottomNavBar(activeItem: TtFoodNavItem.none),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          widget.selectionMode ? 24 : 120,
        ),
        children: <Widget>[
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Cerca alimento',
              prefixIcon: Icon(Icons.search_rounded),
              helperText:
                  'OpenNutrition si attiva da 2 caratteri. Massimo 25 risultati per pagina.',
            ),
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () {
                _page = 0;
                _search();
              });
            },
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(
                value: UnifiedIngredientSearchScopeCodes.all,
                label: Text('Tutti'),
              ),
              ButtonSegment<String>(
                value: UnifiedIngredientSearchScopeCodes.personal,
                label: Text('I miei'),
              ),
              ButtonSegment<String>(
                value: UnifiedIngredientSearchScopeCodes.openNutrition,
                label: Text('OpenNutrition'),
              ),
            ],
            selected: <String>{_scope},
            onSelectionChanged: (selection) {
              setState(() {
                _scope = selection.first;
                _page = 0;
              });
              _search();
            },
          ),
          const SizedBox(height: 12),
          if (_scope == UnifiedIngredientSearchScopeCodes.all)
            const _PriorityInfoCard(),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error.isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error),
              ),
            )
          else if (_result.items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Nessun risultato. Installa OpenNutrition dalle impostazioni '
                  'oppure crea un ingrediente personale.',
                ),
              ),
            )
          else
            ..._buildResults(context),
          if (!_loading && _result.items.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _result.hasPrevious
                        ? () {
                            _page -= 1;
                            _search();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: const Text('Precedenti 25'),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Pagina ${_result.page + 1}'),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _result.hasNext
                        ? () {
                            _page += 1;
                            _search();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: const Text('Successivi 25'),
                  ),
                ),
              ],
            ),
          ],
          if (_result.items.any((item) => !item.isPersonal)) ...<Widget>[
            const SizedBox(height: 16),
            const _AttributionCard(),
          ],
        ],
      ),
      floatingActionButton: widget.selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/food/ingredients/new'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuovo'),
            ),
    );
  }

  List<Widget> _buildResults(BuildContext context) {
    final widgets = <Widget>[];
    var lastPersonal = false;
    for (final item in _result.items) {
      if (widgets.isEmpty || item.isPersonal != lastPersonal) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
            child: Text(
              item.isPersonal ? 'I miei ingredienti' : 'Catalogo OpenNutrition',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        );
      }
      lastPersonal = item.isPersonal;
      widgets.add(
        _IngredientResultCard(item: item, onTap: () => _select(item)),
      );
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  Future<void> _search() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final result = await ref
          .read(unifiedIngredientSearchServiceProvider)
          .search(query: _controller.text, scopeCode: _scope, page: _page);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(UnifiedIngredientSearchItem item) async {
    IngredientEntity ingredient;
    if (item.isPersonal) {
      ingredient = item.personalIngredient!;
    } else {
      ingredient = ref
          .read(unifiedIngredientSearchServiceProvider)
          .promote(item.openNutritionFood!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Importato da OpenNutrition nei tuoi ingredienti.'),
          ),
        );
      }
    }
    if (!mounted) return;
    if (widget.selectionMode) {
      context.pop<IngredientEntity>(ingredient);
    } else {
      context.push('/food/ingredients/${ingredient.id}');
    }
  }
}

class OpenNutritionImportOverlay extends ConsumerStatefulWidget {
  const OpenNutritionImportOverlay({
    required this.targetType,
    required this.targetId,
    required this.child,
    super.key,
  });

  final String targetType;
  final String targetId;
  final Widget child;

  @override
  ConsumerState<OpenNutritionImportOverlay> createState() =>
      _OpenNutritionImportOverlayState();
}

class _OpenNutritionImportOverlayState
    extends ConsumerState<OpenNutritionImportOverlay> {
  int _revision = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        KeyedSubtree(key: ValueKey<int>(_revision), child: widget.child),
        Positioned(
          right: 16,
          bottom: 104,
          child: SafeArea(
            child: FloatingActionButton.extended(
              heroTag: 'opennutrition-${widget.targetType}-${widget.targetId}',
              tooltip: 'Aggiungi dal catalogo OpenNutrition',
              onPressed: _selectAndAdd,
              icon: const Icon(Icons.storage),
              label: const Text('Catalogo'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectAndAdd() async {
    final ingredient = await context.push<IngredientEntity>(
      '/food/ingredients/search?select=1',
    );
    if (ingredient == null || !mounted) return;
    final grams = await _askGrams(ingredient.name);
    if (grams == null || !mounted) return;
    final id = int.tryParse(widget.targetId);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Identificativo destinazione non valido.'),
        ),
      );
      return;
    }
    if (widget.targetType == 'meal') {
      ref
          .read(mealRepositoryProvider)
          .addIngredientItem(mealId: id, ingredient: ingredient, grams: grams);
    } else if (widget.targetType == 'recipe') {
      ref.read(recipeRepositoryProvider).addIngredientItem(
            recipeId: id,
            ingredient: ingredient,
            grams: grams,
          );
    } else {
      throw StateError(
        'Tipo destinazione non supportato: ${widget.targetType}',
      );
    }
    setState(() => _revision += 1);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${ingredient.name} aggiunto: ${grams.toStringAsFixed(0)} g.',
        ),
      ),
    );
  }

  Future<double?> _askGrams(String name) async {
    final controller = TextEditingController(text: '100');
    try {
      return await showDialog<double>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Quantità di $name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Grammi',
              suffixText: 'g',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(
                  controller.text.trim().replaceAll(',', '.'),
                );
                if (value == null || value <= 0) return;
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Aggiungi'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }
}

class _IngredientResultCard extends StatelessWidget {
  const _IngredientResultCard({required this.item, required this.onTap});
  final UnifiedIngredientSearchItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final external = item.openNutritionFood;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Icon(item.isPersonal ? Icons.person_outline : Icons.public),
        ),
        title: Text(item.displayName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (item.brand.isNotEmpty) Text(item.brand),
            Text('${item.kcalPer100g.toStringAsFixed(0)} kcal / 100 g'),
            if (external?.hasEstimatedValues == true)
              const Text('Contiene valori stimati o derivati'),
            if (external?.fromOpenFoodFacts == true)
              const Text('Fonte parziale: © Open Food Facts contributors'),
          ],
        ),
        trailing: Chip(label: Text(item.isPersonal ? 'MIO' : 'OPENNUTRITION')),
      ),
    );
  }
}

class _PriorityInfoCard extends StatelessWidget {
  const _PriorityInfoCard();
  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'I risultati personali sono sempre mostrati prima. OpenNutrition '
            'riempie gli spazi rimanenti fino al limite di 25.',
          ),
        ),
      );
}

class _AttributionCard extends StatelessWidget {
  const _AttributionCard();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Dati forniti da OpenNutrition. Database ODbL e contenuti con '
                'versione modificata della DbCL. Alcune voci: © Open Food '
                'Facts contributors.',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () => _launchAttributionUrl(
                      context,
                      'https://www.opennutrition.app',
                    ),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('OpenNutrition'),
                  ),
                  TextButton.icon(
                    onPressed: () => _launchAttributionUrl(
                      context,
                      'https://world.openfoodfacts.org',
                    ),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open Food Facts'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

Future<void> _launchAttributionUrl(BuildContext context, String value) async {
  final opened = await launchUrl(
    Uri.parse(value),
    mode: LaunchMode.externalApplication,
  );
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impossibile aprire il collegamento.')),
    );
  }
}
