import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/objectbox_providers.dart';
import '../../../core/preferences/food_service_preferences.dart';
import '../data/entities/ingredient_entity.dart';
import '../data/providers/open_nutrition_providers.dart';
import '../data/services/unified_ingredient_search_service.dart';
import '../domain/nutrition_codes.dart';

class UnifiedIngredientSearchScreen extends ConsumerStatefulWidget {
  const UnifiedIngredientSearchScreen({
    super.key,
    this.selectionMode = false,
  });

  final bool selectionMode;

  @override
  ConsumerState<UnifiedIngredientSearchScreen> createState() =>
      _UnifiedIngredientSearchScreenState();
}

class _UnifiedIngredientSearchScreenState
    extends ConsumerState<UnifiedIngredientSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  String _query = '';
  int _localPage = 0;
  int _catalogPage = 0;
  bool _localExpanded = true;
  bool _catalogExpanded = true;
  bool _loading = true;
  Object? _localError;
  Object? _catalogError;
  UnifiedIngredientSearchPage _local = const UnifiedIngredientSearchPage(
    items: <UnifiedIngredientSearchItem>[],
    page: 0,
    hasNext: false,
    hasPrevious: false,
  );
  UnifiedIngredientSearchPage _catalog = const UnifiedIngredientSearchPage(
    items: <UnifiedIngredientSearchItem>[],
    page: 0,
    hasNext: false,
    hasPrevious: false,
  );
  bool _catalogAvailable = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_reload);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _localError = null;
      _catalogError = null;
    });
    final service = ref.read(unifiedIngredientSearchServiceProvider);
    UnifiedIngredientSearchPage local = _local;
    UnifiedIngredientSearchPage catalog = _catalog;
    Object? localError;
    Object? catalogError;
    var available = false;

    try {
      local = await service.searchPersonal(query: _query, page: _localPage);
    } catch (error) {
      localError = error;
    }

    try {
      available = await service.isOpenNutritionAvailable();
      if (_query.trim().isNotEmpty && available) {
        catalog = await service.searchOpenNutrition(
          query: _query,
          page: _catalogPage,
        );
      } else {
        catalog = const UnifiedIngredientSearchPage(
          items: <UnifiedIngredientSearchItem>[],
          page: 0,
          hasNext: false,
          hasPrevious: false,
        );
      }
    } catch (error) {
      catalogError = error;
    }

    if (!mounted) return;
    setState(() {
      _local = local;
      _catalog = catalog;
      _catalogAvailable = available;
      _localError = localError;
      _catalogError = catalogError;
      _loading = false;
    });
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
        _localPage = 0;
        _catalogPage = 0;
      });
      _reload();
    });
  }

  Future<void> _select(UnifiedIngredientSearchItem item) async {
    final service = ref.read(unifiedIngredientSearchServiceProvider);
    final IngredientEntity ingredient = item.personalIngredient ??
        service.promote(item.openNutritionFood!);
    ref.invalidate(openNutritionCatalogCountProvider);
    if (!mounted) return;
    if (widget.selectionMode) {
      context.pop(ingredient);
    } else {
      await context.push('/food/ingredients/${ingredient.id}');
      await _reload();
    }
  }

  Future<void> _showCreateSheet() async {
    final preferences = ref.read(foodServicePreferencesProvider);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Nuovo ingrediente',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scegli come aggiungere l’alimento. Il catalogo '
                  'OpenNutrition viene interrogato soltanto durante una ricerca.',
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Inserimento manuale'),
                  subtitle: const Text('Crea un alimento personale.'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.push('/food/ingredients/new').then((_) => _reload());
                  },
                ),
                ListTile(
                  enabled: preferences.openFoodFactsEnabled,
                  leading: const Icon(Icons.qr_code_scanner_outlined),
                  title: const Text('Open Food Facts'),
                  subtitle: Text(
                    preferences.openFoodFactsEnabled
                        ? 'Scansiona il barcode o cerca online.'
                        : 'Servizio disabilitato nelle impostazioni.',
                  ),
                  onTap: preferences.openFoodFactsEnabled
                      ? () {
                          Navigator.of(sheetContext).pop();
                          context.push('/food/ingredients/scan').then((_) => _reload());
                        }
                      : null,
                ),
                if (_catalogAvailable)
                  ListTile(
                    leading: const Icon(Icons.storage_outlined),
                    title: const Text('Catalogo OpenNutrition'),
                    subtitle: const Text(
                      'Digita almeno due caratteri nella barra di ricerca.',
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _searchFocusNode.requestFocus();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectionMode ? 'Seleziona alimento' : 'Ingredienti'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('Nuovo'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: <Widget>[
            TextField(
              controller: _controller,
              focusNode: _searchFocusNode,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cerca alimento, marca o barcode',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _controller.clear();
                          _onQueryChanged('');
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            if (!searching) ...<Widget>[
              _SectionHeader(
                title: 'Ingredienti recenti',
                subtitle: 'Massimo 50 elementi già importati o personali.',
                expanded: true,
                onToggle: null,
              ),
              const SizedBox(height: 8),
              if (_localError != null)
                _ErrorCard(error: _localError!, onRetry: _reload)
              else if (_local.items.isEmpty && !_loading)
                const _EmptyCard(
                  message: 'Nessun ingrediente presente. Usa “Nuovo”.',
                )
              else
                ..._local.items.map(
                  (UnifiedIngredientSearchItem item) => _IngredientCard(
                    item: item,
                    onTap: () => _select(item),
                  ),
                ),
            ] else ...<Widget>[
              _SectionHeader(
                title: 'Importati da OpenFoodFacts e Personali',
                subtitle: '${_local.items.length} risultati nella pagina',
                expanded: _localExpanded,
                onToggle: () => setState(() => _localExpanded = !_localExpanded),
              ),
              if (_localExpanded) ...<Widget>[
                const SizedBox(height: 8),
                if (_localError != null)
                  _ErrorCard(error: _localError!, onRetry: _reload)
                else if (_local.items.isEmpty && !_loading)
                  const _EmptyCard(message: 'Nessun risultato locale.')
                else
                  ..._local.items.map(
                    (UnifiedIngredientSearchItem item) => _IngredientCard(
                      item: item,
                      onTap: () => _select(item),
                    ),
                  ),
                _Pager(
                  page: _local.page,
                  hasPrevious: _local.hasPrevious,
                  hasNext: _local.hasNext,
                  onPrevious: () {
                    setState(() => _localPage -= 1);
                    _reload();
                  },
                  onNext: () {
                    setState(() => _localPage += 1);
                    _reload();
                  },
                ),
              ],
              const SizedBox(height: 12),
              if (_catalogAvailable) ...<Widget>[
                _SectionHeader(
                  title: 'Catalogo OpenNutrition',
                  subtitle: '${_catalog.items.length} risultati nella pagina',
                  expanded: _catalogExpanded,
                  onToggle: () =>
                      setState(() => _catalogExpanded = !_catalogExpanded),
                ),
                if (_catalogExpanded) ...<Widget>[
                  const SizedBox(height: 8),
                  if (_query.length < 2)
                    const _EmptyCard(
                      message: 'Digita almeno due caratteri.',
                    )
                  else if (_catalogError != null)
                    _ErrorCard(error: _catalogError!, onRetry: _reload)
                  else if (_catalog.items.isEmpty && !_loading)
                    const _EmptyCard(
                      message: 'Nessun risultato nel catalogo OpenNutrition.',
                    )
                  else
                    ..._catalog.items.map(
                      (UnifiedIngredientSearchItem item) => _IngredientCard(
                        item: item,
                        onTap: () => _select(item),
                      ),
                    ),
                  _Pager(
                    page: _catalog.page,
                    hasPrevious: _catalog.hasPrevious,
                    hasNext: _catalog.hasNext,
                    onPrevious: () {
                      setState(() => _catalogPage -= 1);
                      _reload();
                    },
                    onNext: () {
                      setState(() => _catalogPage += 1);
                      _reload();
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Dati OpenNutrition: ODbL 1.0 / modified DbCL 1.0. '
                      'I record derivati da Open Food Facts mantengono la relativa attribuzione.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ] else
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.storage_outlined),
                    title: const Text('Catalogo OpenNutrition non disponibile'),
                    subtitle: const Text(
                      'Installalo e abilita la ricerca dalle impostazioni.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/opennutrition'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onToggle,
  });

  final String title;
  final String subtitle;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onToggle,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: onToggle == null
            ? null
            : Icon(expanded ? Icons.expand_less : Icons.expand_more),
      ),
    );
  }
}

class _IngredientCard extends StatelessWidget {
  const _IngredientCard({required this.item, required this.onTap});

  final UnifiedIngredientSearchItem item;
  final VoidCallback onTap;

  IconData get _sourceIcon {
    switch (item.sourceTypeCode) {
      case IngredientSourceTypeCodes.openNutrition:
        return Icons.storage_outlined;
      case IngredientSourceTypeCodes.openFoodFacts:
        return Icons.qr_code_2_outlined;
      default:
        return Icons.person_outline;
    }
  }

  String get _sourceLabel {
    switch (item.sourceTypeCode) {
      case IngredientSourceTypeCodes.openNutrition:
        return 'OpenNutrition';
      case IngredientSourceTypeCodes.openFoodFacts:
        return 'Open Food Facts';
      default:
        return 'Personale';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: _IngredientImage(source: item.imageUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (item.brand.isNotEmpty)
                      Text(
                        item.brand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.kcalPer100g.toStringAsFixed(0)} kcal · '
                      'P ${item.proteinPer100g.toStringAsFixed(1)} · '
                      'C ${item.carbsPer100g.toStringAsFixed(1)} · '
                      'G ${item.fatPer100g.toStringAsFixed(1)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: _sourceLabel,
                child: Semantics(
                  label: _sourceLabel,
                  child: Icon(_sourceIcon),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IngredientImage extends StatelessWidget {
  const _IngredientImage({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(
      color: Color(0x11000000),
      child: Icon(Icons.restaurant_outlined),
    );
    final value = source.trim();
    if (value.isEmpty) return fallback;
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
      return Image.network(
        value,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    if (value.startsWith('assets/')) {
      return Image.asset(
        value,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    return Image.file(
      File(value),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    if (!hasPrevious && !hasNext) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        IconButton(
          onPressed: hasPrevious ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('${page + 1}'),
        IconButton(
          onPressed: hasNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(message)));
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('Ricerca non riuscita'),
        subtitle: Text(error.toString()),
        trailing: IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
      ),
    );
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
              heroTag:
                  'ingredient-search-${widget.targetType}-${widget.targetId}',
              tooltip: 'Aggiungi alimento',
              onPressed: _selectAndAdd,
              icon: const Icon(Icons.add),
              label: const Text('Alimento'),
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
        const SnackBar(content: Text('Identificativo destinazione non valido.')),
      );
      return;
    }
    if (widget.targetType == 'meal') {
      ref.read(mealRepositoryProvider).addIngredientItem(
            mealId: id,
            ingredient: ingredient,
            grams: grams,
          );
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
        builder: (BuildContext dialogContext) => AlertDialog(
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
