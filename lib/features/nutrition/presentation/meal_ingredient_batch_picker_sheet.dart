import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/pagination/paged_result.dart';
import '../data/entities/ingredient_entity.dart';

typedef IngredientPageLoader = FutureOr<PagedResult<IngredientEntity>>
    Function({
  required int page,
  required int pageSize,
  required String search,
  String brand,
});

class MealIngredientBatchSelection {
  const MealIngredientBatchSelection({
    required this.ingredient,
    required this.grams,
  });

  final IngredientEntity ingredient;
  final double grams;
}

class MealIngredientBatchPickerController {
  _MealIngredientBatchPickerSheetState? _state;

  bool get isAttached => _state != null;

  void expand() => unawaited(
        _state?._setExtent(
                _MealIngredientBatchPickerSheetState._expandedExtent) ??
            Future<void>.value(),
      );

  void collapse() => unawaited(
        _state?._setExtent(
              _MealIngredientBatchPickerSheetState._collapsedExtent,
            ) ??
            Future<void>.value(),
      );

  Future<void> handleBack() async {
    await _state?._handleBack();
  }

  void _attach(_MealIngredientBatchPickerSheetState state) {
    _state = state;
  }

  void _detach(_MealIngredientBatchPickerSheetState state) {
    if (_state == state) {
      _state = null;
    }
  }
}

class MealIngredientBatchPickerSheet extends StatefulWidget {
  const MealIngredientBatchPickerSheet({
    required this.onConfirm,
    required this.onDiscard,
    this.loadPage,
    this.ingredients = const <IngredientEntity>[],
    this.controller,
    super.key,
  });

  final IngredientPageLoader? loadPage;
  final List<IngredientEntity> ingredients;
  final ValueChanged<List<MealIngredientBatchSelection>> onConfirm;
  final VoidCallback onDiscard;
  final MealIngredientBatchPickerController? controller;

  @override
  State<MealIngredientBatchPickerSheet> createState() =>
      _MealIngredientBatchPickerSheetState();
}

class _MealIngredientBatchPickerSheetState
    extends State<MealIngredientBatchPickerSheet> {
  static const int _pageSize = 10;
  static const double _collapsedExtent = 0.22;
  static const double _middleExtent = 0.56;
  static const double _expandedExtent = 0.92;

  final TextEditingController _queryController = TextEditingController();
  final GlobalKey<FormState> _quantityFormKey = GlobalKey<FormState>();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final Map<int, IngredientEntity> _selectedById = <int, IngredientEntity>{};
  final Map<int, String> _gramsById = <int, String>{};
  final Map<String, PagedResult<IngredientEntity>> _pageCache =
      <String, PagedResult<IngredientEntity>>{};

  List<IngredientEntity> _items = const <IngredientEntity>[];
  Timer? _searchDebounce;
  int _page = 1;
  int _totalCount = 0;
  int _requestId = 0;
  int _step = 0;
  bool _loading = false;
  bool _confirming = false;
  String _error = '';
  double _extent = _expandedExtent;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _queryController.addListener(_onSearchChanged);
    unawaited(_loadPage(page: 1));
  }

  @override
  void didUpdateWidget(MealIngredientBatchPickerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.loadPage != widget.loadPage ||
        oldWidget.ingredients != widget.ingredients) {
      _pageCache.clear();
      unawaited(_loadPage(page: 1));
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _searchDebounce?.cancel();
    _queryController.removeListener(_onSearchChanged);
    _queryController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  List<IngredientEntity> get _selectedIngredients =>
      _selectedById.values.toList(growable: false)
        ..sort((IngredientEntity a, IngredientEntity b) {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

  bool get _isCollapsed => _extent <= _collapsedExtent + 0.02;

  int get _totalPages {
    if (_totalCount <= 0) return 0;
    return (_totalCount / _pageSize).ceil();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 260), () {
      _pageCache.clear();
      unawaited(_loadPage(page: 1));
    });
  }

  Future<void> _loadPage({required int page}) async {
    final int safePage = PagedResult.normalizePage(page);
    final String search = _queryController.text.trim();
    final String cacheKey = '$search::$safePage';
    final PagedResult<IngredientEntity>? cached = _pageCache[cacheKey];
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _page = cached.page;
        _items = cached.items;
        _totalCount = cached.totalCount;
        _error = '';
        _loading = false;
      });
      return;
    }

    final int requestId = ++_requestId;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }
    try {
      final PagedResult<IngredientEntity> result = await Future.value(
        widget.loadPage == null
            ? _loadLocalPage(page: safePage, search: search)
            : widget.loadPage!(
                page: safePage,
                pageSize: _pageSize,
                search: search,
                brand: '',
              ),
      );
      if (!mounted || requestId != _requestId) {
        return;
      }
      _pageCache[cacheKey] = result;
      setState(() {
        _page = result.page;
        _items = result.items;
        _totalCount = result.totalCount;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  PagedResult<IngredientEntity> _loadLocalPage({
    required int page,
    required String search,
  }) {
    final String clean = search.toLowerCase();
    final List<IngredientEntity> filtered =
        widget.ingredients.where((IngredientEntity ingredient) {
      return ingredient.deletedAtEpochMs == null &&
          !ingredient.isArchived &&
          (clean.isEmpty ||
              ingredient.name.toLowerCase().contains(clean) ||
              ingredient.brand.toLowerCase().contains(clean) ||
              ingredient.barcode.toLowerCase().contains(clean));
    }).toList(growable: false)
          ..sort((IngredientEntity a, IngredientEntity b) {
            final int nameCompare =
                a.name.toLowerCase().compareTo(b.name.toLowerCase());
            if (nameCompare != 0) return nameCompare;
            return a.id.compareTo(b.id);
          });
    final int start = (page - 1) * _pageSize;
    final int end = (start + _pageSize).clamp(0, filtered.length).toInt();
    return PagedResult<IngredientEntity>(
      items: start >= filtered.length
          ? const <IngredientEntity>[]
          : filtered.sublist(start, end),
      page: page,
      pageSize: _pageSize,
      totalCount: filtered.length,
    );
  }

  void _toggle(IngredientEntity ingredient) {
    setState(() {
      if (_selectedById.remove(ingredient.id) != null) {
        _gramsById.remove(ingredient.id);
      } else {
        _selectedById[ingredient.id] = ingredient;
        _gramsById.putIfAbsent(ingredient.id, () => '100');
      }
    });
  }

  Future<void> _setExtent(double value) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final double next = value.clamp(_collapsedExtent, _expandedExtent);
    if (mounted) {
      setState(() => _extent = next);
    }
    if (_sheetController.isAttached) {
      await _sheetController.animateTo(
        next,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _handleBack() async {
    if (_selectedById.isNotEmpty) {
      await _setExtent(_collapsedExtent);
      return;
    }
    widget.onDiscard();
  }

  Future<void> _requestClose() async {
    if (_selectedById.isEmpty) {
      widget.onDiscard();
      return;
    }
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Scartare la selezione?'),
        content: Text(
          'Hai selezionato ${_selectedById.length} alimenti. '
          'Puoi mantenere il pannello compresso e continuare a usare la pagina, '
          'oppure scartare le quantita inserite.',
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
      await _setExtent(_collapsedExtent);
    }
  }

  void _continue() {
    if (_selectedById.isEmpty || _confirming) return;
    if (_step == 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _step = 1;
        _extent = _expandedExtent;
      });
      unawaited(_setExtent(_expandedExtent));
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
    _confirming = true;
    widget.onConfirm(result);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(_handleBack());
        }
      },
      child: DraggableScrollableSheet(
        controller: _sheetController,
        expand: false,
        initialChildSize: _expandedExtent,
        minChildSize: _collapsedExtent,
        maxChildSize: _expandedExtent,
        snap: true,
        snapSizes: const <double>[_collapsedExtent, _middleExtent],
        builder: (BuildContext context, ScrollController scrollController) {
          return NotificationListener<DraggableScrollableNotification>(
            onNotification: (DraggableScrollableNotification notification) {
              if ((_extent - notification.extent).abs() > 0.01) {
                setState(() => _extent = notification.extent);
              }
              return false;
            },
            child: Padding(
              padding: EdgeInsets.only(bottom: keyboardBottom),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
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
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    child: _isCollapsed
                        ? _buildCollapsed(context, scrollController)
                        : _buildExpanded(context, scrollController),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dragHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(
        _setExtent(_isCollapsed ? _middleExtent : _collapsedExtent),
      ),
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

  Widget _buildCollapsed(
    BuildContext context,
    ScrollController scrollController,
  ) {
    final int count = _selectedById.length;
    return ListView(
      controller: scrollController,
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: <Widget>[
        _dragHandle(),
        SizedBox(
          height: 88,
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
                        'Trascina o tocca la maniglia per espandere.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Espandi il selettore',
                  onPressed: () => unawaited(_setExtent(_expandedExtent)),
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                ),
                if (count > 0)
                  IconButton.filledTonal(
                    tooltip: _step == 0
                        ? 'Continua con le quantita'
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

  Widget _buildExpanded(
    BuildContext context,
    ScrollController scrollController,
  ) {
    final List<IngredientEntity> selected = _selectedIngredients;
    return Column(
      children: <Widget>[
        _dragHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.sm,
            AppSpacing.sm,
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
                          : 'Inserisci le quantita',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${_selectedById.length} selezionati',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Comprimi mantenendo la selezione',
                onPressed: () => unawaited(_setExtent(_collapsedExtent)),
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
        if (_step == 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: TextField(
              key: const ValueKey<String>('ingredient-picker-search'),
              controller: _queryController,
              decoration: const InputDecoration(
                labelText: 'Cerca per nome, brand o barcode',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
        Expanded(
          child: _step == 0
              ? _buildSelectionList(context, scrollController)
              : _buildQuantityList(context, selected, scrollController),
        ),
        _buildFooter(context),
      ],
    );
  }

  Widget _buildSelectionList(
    BuildContext context,
    ScrollController scrollController,
  ) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text('Ricerca non riuscita: $_error'),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            _queryController.text.trim().isEmpty
                ? 'Nessun alimento salvato.'
                : 'Nessun alimento trovato.',
          ),
        ),
      );
    }
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      itemCount: _items.length,
      itemBuilder: (BuildContext context, int index) {
        final IngredientEntity ingredient = _items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: CheckboxListTile(
              value: _selectedById.containsKey(ingredient.id),
              onChanged: (_) => _toggle(ingredient),
              title: Text(ingredient.name),
              subtitle: Text(
                ingredient.brand.trim().isEmpty
                    ? '${ingredient.kcalPerReference.round()} kcal / 100 g'
                    : ingredient.brand,
              ),
              secondary: _IngredientThumbnail(imageUrl: ingredient.imageUrl),
              controlAffinity: ListTileControlAffinity.trailing,
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuantityList(
    BuildContext context,
    List<IngredientEntity> selected,
    ScrollController scrollController,
  ) {
    return Form(
      key: _quantityFormKey,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        itemCount: selected.length,
        itemBuilder: (BuildContext context, int index) {
          final IngredientEntity ingredient = selected[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    _IngredientThumbnail(imageUrl: ingredient.imageUrl),
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
                          labelText: 'Quantita',
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
          );
        },
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final bool hasPrevious = _page > 1;
    final bool hasNext = _totalPages > 0 && _page < _totalPages;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_step == 0)
              Row(
                children: <Widget>[
                  IconButton.outlined(
                    tooltip: 'Pagina precedente',
                    onPressed: hasPrevious && !_loading
                        ? () => unawaited(_loadPage(page: _page - 1))
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      _totalPages == 0
                          ? '0 risultati'
                          : 'Pagina $_page di $_totalPages',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: 'Pagina successiva',
                    onPressed: hasNext && !_loading
                        ? () => unawaited(_loadPage(page: _page + 1))
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            if (_step == 0) const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (_step == 0) {
                        unawaited(_setExtent(_collapsedExtent));
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
                    onPressed: _selectedById.isEmpty ? null : _continue,
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
          ],
        ),
      ),
    );
  }
}

class _IngredientThumbnail extends StatelessWidget {
  const _IngredientThumbnail({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Icon(
      Icons.inventory_2_outlined,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final String clean = imageUrl.trim();
    if (clean.isEmpty) {
      return _frame(fallback);
    }
    final Uri? uri = Uri.tryParse(clean);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return _frame(
        Image.network(
          clean,
          fit: BoxFit.cover,
          cacheWidth: 96,
          cacheHeight: 96,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }
    final File file = File(clean);
    return _frame(
      Image.file(
        file,
        fit: BoxFit.cover,
        cacheWidth: 96,
        cacheHeight: 96,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  Widget _frame(Widget child) {
    return SizedBox.square(
      dimension: 44,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(
          color: Colors.black12,
          child: Center(child: child),
        ),
      ),
    );
  }
}
