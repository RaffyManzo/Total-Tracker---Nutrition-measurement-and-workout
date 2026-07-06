import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/primary_bottom_navigation.dart';
import '../../../core/database/objectbox_providers.dart';
import '../../../core/diagnostics/interaction_trace.dart';
import '../../../core/network/open_nutrition_network_access.dart';
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
  bool _selectionReturning = false;
  late final String _diagnosticScreenId;
  bool _diagnosticFirstBuild = false;

  String _query = '';
  int _localPage = 0;
  int _catalogPage = 0;
  int _offPage = 0;

  bool _localExpanded = true;
  bool _catalogExpanded = true;
  bool _offExpanded = true;
  bool _onlineSearchActive = false;
  bool _localLoading = true;
  bool _offLoading = false;
  bool _catalogLoading = false;
  int _searchGeneration = 0;
  String? _catalogBlockedMessage;
  bool _catalogAvailable = false;
  OpenNutritionSearchMode _catalogMode = OpenNutritionSearchMode.unavailable;
  bool _offAvailable = false;

  Object? _localError;
  Object? _catalogError;
  Object? _offError;

  UnifiedIngredientSearchPage _local = _emptyPage();
  UnifiedIngredientSearchPage _catalog = _emptyPage();
  UnifiedIngredientSearchPage _off = _emptyPage();

  static UnifiedIngredientSearchPage _emptyPage() {
    return const UnifiedIngredientSearchPage(
      items: <UnifiedIngredientSearchItem>[],
      page: 0,
      hasNext: false,
      hasPrevious: false,
    );
  }

  @override
  void initState() {
    super.initState();
    _diagnosticScreenId =
        DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    InteractionTrace.event(
      'ingredient_search.lifecycle_initialized',
      data: <String, Object?>{
        'screenId': _diagnosticScreenId,
        'selectionMode': widget.selectionMode,
        'controllerIdentity': identityHashCode(_controller),
        'focusIdentity': identityHashCode(_searchFocusNode),
      },
    );
    Future<void>.microtask(_reloadLocal);
  }

  @override
  void dispose() {
    InteractionTrace.event(
      'ingredient_search.lifecycle_dispose_started',
      data: <String, Object?>{
        'screenId': _diagnosticScreenId,
        'selectionReturning': _selectionReturning,
        'debounceActive': _debounce?.isActive ?? false,
        'controllerIdentity': identityHashCode(_controller),
        'focusIdentity': identityHashCode(_searchFocusNode),
        'focusHasFocus': _searchFocusNode.hasFocus,
        'primaryFocusPresent': FocusManager.instance.primaryFocus != null,
      },
    );
    _debounce?.cancel();
    _controller.dispose();
    _searchFocusNode.dispose();
    InteractionTrace.event(
      'ingredient_search.lifecycle_dispose_completed',
      data: <String, Object?>{'screenId': _diagnosticScreenId},
    );
    super.dispose();
  }

  bool get _canSearchOnline =>
      UnifiedIngredientSearchPolicy.canSearchOpenFoodFacts(_query) ||
      UnifiedIngredientSearchPolicy.canSearchOpenNutrition(_query);

  Future<void> _reloadLocal() async {
    if (!mounted) return;
    final int generation = ++_searchGeneration;
    final String query = _query;
    final UnifiedIngredientSearchService service =
        ref.read(unifiedIngredientSearchServiceProvider);
    setState(() {
      _localLoading = true;
      _local = _emptyPage();
      _localError = null;
    });
    try {
      final UnifiedIngredientSearchPage local = await service
          .searchPersonal(query: query, page: _localPage)
          .timeout(const Duration(seconds: 8));
      if (!_isCurrentSearch(generation)) return;
      setState(() {
        _local = local;
        _localError = null;
        _localLoading = false;
      });
    } on TimeoutException {
      if (!_isCurrentSearch(generation)) return;
      setState(() {
        _localError = TimeoutException(
          'La ricerca locale non ha risposto entro 8 secondi.',
        );
        _localLoading = false;
      });
    } catch (error) {
      if (!_isCurrentSearch(generation)) return;
      setState(() {
        _localError = error;
        _localLoading = false;
      });
    }
  }

  Future<void> _searchOnline() async {
    if (!mounted || !_canSearchOnline) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final int generation = ++_searchGeneration;
    final String query = _query;
    setState(() {
      _onlineSearchActive = true;
      _localExpanded = false;
      _offExpanded = true;
      _catalogExpanded = true;
      _offPage = 0;
      _catalogPage = 0;
      _off = _emptyPage();
      _catalog = _emptyPage();
      _offError = null;
      _catalogError = null;
      _catalogBlockedMessage = null;
      _offLoading = UnifiedIngredientSearchPolicy.canSearchOpenFoodFacts(query);
      _catalogLoading =
          UnifiedIngredientSearchPolicy.canSearchOpenNutrition(query);
    });
    await Future.wait<void>(<Future<void>>[
      _reloadOpenFoodFacts(generation: generation, query: query),
      _reloadOpenNutrition(generation: generation, query: query),
    ]);
  }

  Future<void> _reloadOpenFoodFacts({
    int? generation,
    String? query,
  }) async {
    if (!mounted) return;
    final int activeGeneration = generation ?? ++_searchGeneration;
    final String activeQuery = query ?? _query;
    final UnifiedIngredientSearchService service =
        ref.read(unifiedIngredientSearchServiceProvider);
    if (generation == null) {
      setState(() {
        _offLoading = true;
        _offError = null;
      });
    }
    try {
      final bool available = await service
          .isOpenFoodFactsAvailable()
          .timeout(const Duration(seconds: 5));
      if (!_isCurrentSearch(activeGeneration)) return;
      setState(() => _offAvailable = available);
      if (!available ||
          !UnifiedIngredientSearchPolicy.canSearchOpenFoodFacts(activeQuery)) {
        setState(() {
          _off = _emptyPage();
          _offError = null;
          _offLoading = false;
        });
        return;
      }
      final UnifiedIngredientSearchPage page = await service
          .searchOpenFoodFacts(query: activeQuery, page: _offPage)
          .timeout(const Duration(seconds: 25));
      if (!_isCurrentSearch(activeGeneration)) return;
      setState(() {
        _off = page;
        _offError = null;
        _offLoading = false;
      });
    } on TimeoutException {
      if (!_isCurrentSearch(activeGeneration)) return;
      setState(() {
        _offError = TimeoutException(
          'Open Food Facts non ha completato la ricerca entro 25 secondi.',
        );
        _offLoading = false;
      });
    } catch (error) {
      if (!_isCurrentSearch(activeGeneration)) return;
      setState(() {
        _offError = error;
        _offLoading = false;
      });
    }
  }

  Future<void> _reloadOpenNutrition({
    int? generation,
    String? query,
  }) async {
    if (!mounted) return;
    final int activeGeneration = generation ?? ++_searchGeneration;
    final String activeQuery = query ?? _query;
    final UnifiedIngredientSearchService service =
        ref.read(unifiedIngredientSearchServiceProvider);
    if (generation == null) {
      setState(() {
        _catalogLoading = true;
        _catalogError = null;
        _catalogBlockedMessage = null;
      });
    }

    OpenNutritionSearchMode mode = OpenNutritionSearchMode.unavailable;
    try {
      mode = await service
          .openNutritionSearchMode()
          .timeout(const Duration(seconds: 8));
      if (!_isCurrentSearch(activeGeneration)) return;
      setState(() {
        _catalogMode = mode;
        _catalogAvailable = mode != OpenNutritionSearchMode.unavailable;
      });
    } on TimeoutException {
      if (!_isCurrentSearch(activeGeneration)) return;
      setState(() {
        _catalogAvailable = false;
        _catalogError = TimeoutException(
          'La configurazione OpenNutrition non ha risposto entro 8 secondi.',
        );
        _catalogLoading = false;
      });
      return;
    } catch (error) {
      if (!_isCurrentSearch(activeGeneration)) return;
      setState(() {
        _catalogAvailable = false;
        _catalogError = error;
        _catalogLoading = false;
      });
      return;
    }

    if (mode == OpenNutritionSearchMode.unavailable ||
        !UnifiedIngredientSearchPolicy.canSearchOpenNutrition(activeQuery)) {
      if (!_isCurrentSearch(activeGeneration)) return;
      setState(() {
        _catalog = _emptyPage();
        _catalogLoading = false;
      });
      return;
    }

    try {
      final UnifiedIngredientSearchPage page = await service
          .searchOpenNutrition(query: activeQuery, page: _catalogPage)
          .timeout(const Duration(seconds: 25));
      if (!_isCurrentSearch(activeGeneration)) return;
      setState(() {
        _catalog = page;
        _catalogError = null;
        _catalogBlockedMessage = null;
        _catalogLoading = false;
      });
    } on OpenNutritionNetworkPolicyException catch (error) {
      if (!_isCurrentSearch(activeGeneration)) return;
      setState(() {
        _catalog = _emptyPage();
        _catalogError = null;
        _catalogBlockedMessage = error.message;
        _catalogLoading = false;
      });
    } on TimeoutException {
      if (!_isCurrentSearch(activeGeneration)) return;
      setState(() {
        _catalogError = TimeoutException(
          'OpenNutrition non ha completato la ricerca entro 25 secondi.',
        );
        _catalogLoading = false;
      });
    } catch (error) {
      if (!_isCurrentSearch(activeGeneration)) return;
      setState(() {
        _catalogError = error;
        _catalogLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _reloadLocal();
    if (_onlineSearchActive && mounted) {
      await _searchOnline();
    }
  }

  bool _isCurrentSearch(int generation) {
    return mounted && generation == _searchGeneration;
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final String normalized = value.trim();
    InteractionTrace.event(
      'ingredient_search.query_changed',
      data: <String, Object?>{
        'screenId': _diagnosticScreenId,
        'queryLength': normalized.runes.length,
      },
      sampleEvery: 4,
    );
    ++_searchGeneration;
    setState(() {
      _query = normalized;
      _localPage = 0;
      _catalogPage = 0;
      _offPage = 0;
      _onlineSearchActive = false;
      _localExpanded = true;
      _off = _emptyPage();
      _catalog = _emptyPage();
      _offError = null;
      _catalogError = null;
      _catalogBlockedMessage = null;
      _offLoading = false;
      _catalogLoading = false;
    });
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        _reloadLocal();
      }
    });
  }

  Future<void> _returnSelection(
    IngredientEntity ingredient,
  ) async {
    if (_selectionReturning || !mounted) {
      InteractionTrace.event(
        'ingredient_search.selection_ignored',
        data: <String, Object?>{
          'screenId': _diagnosticScreenId,
          'selectionReturning': _selectionReturning,
          'mounted': mounted,
        },
      );
      return;
    }
    _selectionReturning = true;
    _debounce?.cancel();
    ++_searchGeneration;
    InteractionTrace.event(
      'ingredient_search.selection_started',
      data: <String, Object?>{
        'screenId': _diagnosticScreenId,
        'controllerIdentity': identityHashCode(_controller),
        'focusIdentity': identityHashCode(_searchFocusNode),
        'focusHasFocusBeforeUnfocus': _searchFocusNode.hasFocus,
        'primaryFocusPresentBeforeUnfocus':
            FocusManager.instance.primaryFocus != null,
      },
    );
    FocusManager.instance.primaryFocus?.unfocus();

    final NavigatorState navigator = Navigator.of(context);
    if (!navigator.canPop()) {
      _selectionReturning = false;
      InteractionTrace.event(
        'ingredient_search.selection_without_route',
        data: <String, Object?>{
          'screenId': _diagnosticScreenId,
          'mounted': mounted,
        },
      );
      return;
    }
    InteractionTrace.event(
      'ingredient_search.selection_pop_requested',
      data: <String, Object?>{
        'screenId': _diagnosticScreenId,
        'mounted': mounted,
        'navigatorMounted': navigator.mounted,
        'focusHasFocusAfterUnfocus': _searchFocusNode.hasFocus,
        'primaryFocusPresentAfterUnfocus':
            FocusManager.instance.primaryFocus != null,
      },
    );
    navigator.pop<IngredientEntity>(ingredient);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      InteractionTrace.event(
        'ingredient_search.selection_post_frame',
        data: <String, Object?>{
          'screenId': _diagnosticScreenId,
          'mounted': mounted,
        },
      );
    });
  }

  Future<void> _select(
    UnifiedIngredientSearchItem item,
  ) async {
    if (item.isOpenFoodFacts) {
      final IngredientEntity? imported = await context.push<IngredientEntity>(
        '/food/ingredients/off/product/'
        '${Uri.encodeComponent(item.openFoodFactsProduct!.code)}',
        extra: item.openFoodFactsProduct,
      );
      if (imported == null || !mounted) return;
      await _afterImported(
        imported,
        openDetail: true,
      );
      return;
    }

    if (item.requiresOpenNutritionImportConfirmation) {
      final bool confirmed = await _confirmOpenNutritionImport(item);
      if (!confirmed || !mounted) return;
    }

    final UnifiedIngredientSearchService service =
        ref.read(unifiedIngredientSearchServiceProvider);
    final IngredientEntity ingredient =
        item.personalIngredient ?? service.promote(item.openNutritionFood!);
    ref.invalidate(openNutritionCatalogCountProvider);

    if (!mounted) return;
    if (widget.selectionMode) {
      await _returnSelection(ingredient);
      return;
    }

    await context.push(
      '/food/ingredients/${ingredient.id}',
    );
    await _reloadLocal();
  }

  Future<bool> _confirmOpenNutritionImport(
    UnifiedIngredientSearchItem item,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text(item.displayName),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (item.brand.isNotEmpty) Text(item.brand),
                  const SizedBox(height: 12),
                  Text(
                    '${item.kcalPer100g.toStringAsFixed(0)} kcal · '
                    'P ${item.proteinPer100g.toStringAsFixed(1)} · '
                    'C ${item.carbsPer100g.toStringAsFixed(1)} · '
                    'G ${item.fatPer100g.toStringAsFixed(1)} per 100 g',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.isStaticOpenNutrition
                        ? 'Il record proviene da uno shard HTTPS verificato '
                            'tramite SHA-256. Ricerca e ranking vengono '
                            'eseguiti localmente prima dell’importazione.'
                        : 'Il record verrà importato singolarmente da un '
                            'gateway HTTPS. La risposta è accettata solo dopo '
                            'verifica Ed25519, controllo temporale e '
                            'validazione dello schema.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fonte dati: OpenNutrition · ODbL 1.0 / DbCL modificata.',
                  ),
                  if (item.isMachineTranslatedOpenNutrition) ...<Widget>[
                    const SizedBox(height: 8),
                    const Text(
                      'Traduzione automatica con Google Translate, '
                      'eseguita sul dispositivo.',
                    ),
                  ],
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Annulla'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Importa'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _afterImported(
    IngredientEntity ingredient, {
    required bool openDetail,
  }) async {
    if (widget.selectionMode) {
      await _returnSelection(ingredient);
      return;
    }

    _debounce?.cancel();

    _controller.clear();
    setState(() {
      _query = '';
      _localPage = 0;
      _catalogPage = 0;
      _offPage = 0;
    });
    await _reloadLocal();
    if (!mounted) return;
    if (openDetail) {
      await context.push(
        '/food/ingredients/${ingredient.id}',
      );
      await _reloadLocal();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${ingredient.name} creato e aggiunto alla lista.',
        ),
      ),
    );
  }

  Future<void> _createManual() async {
    final IngredientEntity? created = await context.push<IngredientEntity>(
      '/food/ingredients/create',
    );
    if (created != null && mounted) {
      await _afterImported(
        created,
        openDetail: false,
      );
    }
  }

  Future<void> _scanOpenFoodFacts() async {
    final IngredientEntity? imported = await context.push<IngredientEntity>(
      '/food/ingredients/scan',
    );
    if (imported != null && mounted) {
      await _afterImported(
        imported,
        openDetail: true,
      );
    }
  }

  Future<void> _showCreateSheet() async {
    final FoodServicePreferencesController preferences =
        ref.read(foodServicePreferencesProvider);
    final String? action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Inserimento manuale'),
                  subtitle: const Text('Crea un alimento personale.'),
                  onTap: () => Navigator.pop(sheetContext, 'manual'),
                ),
                ListTile(
                  enabled: preferences.openFoodFactsEnabled,
                  leading: const Icon(Icons.qr_code_scanner_outlined),
                  title: const Text('Scansiona Open Food Facts'),
                  subtitle: const Text(
                    'Fotocamera o inserimento testuale del barcode.',
                  ),
                  onTap: preferences.openFoodFactsEnabled
                      ? () => Navigator.pop(sheetContext, 'scan')
                      : null,
                ),
                ListTile(
                  enabled: preferences.openFoodFactsEnabled,
                  leading: const Icon(Icons.travel_explore_outlined),
                  title: const Text('Cerca Open Food Facts'),
                  subtitle: const Text(
                    'Scrivi nella barra e avvia poi la ricerca online.',
                  ),
                  onTap: preferences.openFoodFactsEnabled
                      ? () => Navigator.pop(sheetContext, 'focus-off')
                      : null,
                ),
                if (_catalogAvailable)
                  ListTile(
                    leading: const Icon(Icons.storage_outlined),
                    title: const Text('Ricerca OpenNutrition'),
                    subtitle: const Text(
                      'Scrivi nella barra e premi “Cerca online”.',
                    ),
                    onTap: () => Navigator.pop(sheetContext, 'focus-catalog'),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    switch (action) {
      case 'manual':
        await _createManual();
        return;
      case 'scan':
        await _scanOpenFoodFacts();
        return;
      case 'focus-off':
        setState(() => _offExpanded = true);
        _searchFocusNode.requestFocus();
        return;
      case 'focus-catalog':
        setState(() => _catalogExpanded = true);
        _searchFocusNode.requestFocus();
        return;
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    if (!_diagnosticFirstBuild) {
      _diagnosticFirstBuild = true;
      InteractionTrace.event(
        'ingredient_search.lifecycle_first_build',
        data: <String, Object?>{
          'screenId': _diagnosticScreenId,
          'selectionMode': widget.selectionMode,
        },
      );
    }
    final bool searching = _query.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.selectionMode ? 'Seleziona alimento' : 'Ingredienti',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('Nuovo'),
      ),
      bottomNavigationBar: const PrimaryBottomNavigation(
        currentSection: 'food',
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: <Widget>[
            TextField(
              controller: _controller,
              focusNode: _searchFocusNode,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _reloadLocal(),
              decoration: InputDecoration(
                hintText: 'Cerca alimento, nome, brand o barcode',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _controller.clear();
                          _onQueryChanged('');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (searching)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _canSearchOnline ? _searchOnline : null,
                  icon: const Icon(Icons.travel_explore_rounded),
                  label: const Text('Cerca online'),
                ),
              ),
            if (searching)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'La digitazione filtra soltanto gli alimenti locali. '
                  'Premi il pulsante per interrogare le fonti online.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 16),
            if (_localLoading) const LinearProgressIndicator(),
            if (!searching)
              _buildRecentSection()
            else ...<Widget>[
              _buildLocalSection(),
              if (_onlineSearchActive) ...<Widget>[
                const SizedBox(height: 12),
                if (_offAvailable)
                  _buildOpenFoodFactsSection()
                else
                  const _EmptyCard(
                    message:
                        'Open Food Facts è disabilitato nelle impostazioni.',
                  ),
                const SizedBox(height: 12),
                if (_catalogAvailable)
                  _buildCatalogSection()
                else
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.storage_outlined),
                      title: const Text('OpenNutrition non disponibile'),
                      subtitle: const Text(
                        'La sorgente statica non è configurata nella build '
                        'oppure la ricerca è disabilitata nelle impostazioni.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/settings/opennutrition'),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SectionHeader(
          title: 'Ingredienti recenti',
          subtitle: 'Massimo 50 elementi già importati o personali.',
          expanded: true,
          onToggle: null,
        ),
        const SizedBox(height: 8),
        if (_localError != null)
          _ErrorCard(
            error: _localError!,
            onRetry: _reloadLocal,
          )
        else if (_local.items.isEmpty && !_localLoading)
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
      ],
    );
  }

  Widget _buildLocalSection() {
    return _SearchSection(
      title: 'Personali e già importati',
      subtitle: '${_local.items.length} risultati nella pagina',
      expanded: _localExpanded,
      onToggle: () {
        setState(
          () => _localExpanded = !_localExpanded,
        );
      },
      onRetry: _reloadLocal,
      error: _localError,
      emptyMessage: 'Nessun risultato locale.',
      items: _local.items,
      onItem: _select,
      pager: _Pager(
        page: _local.page,
        hasPrevious: _local.hasPrevious,
        hasNext: _local.hasNext,
        onPrevious: () {
          setState(() => _localPage -= 1);
          _reloadLocal();
        },
        onNext: () {
          setState(() => _localPage += 1);
          _reloadLocal();
        },
      ),
    );
  }

  Widget _buildCatalogSection() {
    final String subtitle;
    if (_catalogLoading) {
      subtitle =
          'Ricerca OpenNutrition in corso · fino a 20 tentativi automatici…';
    } else if (_catalogBlockedMessage != null) {
      subtitle = _catalogBlockedMessage!;
    } else if (_query.length < 3 &&
        _catalogMode == OpenNutritionSearchMode.staticIndex) {
      subtitle = 'Digita almeno tre caratteri';
    } else if (_query.length < 2) {
      subtitle = 'Digita almeno due caratteri';
    } else if (_catalogMode == OpenNutritionSearchMode.staticIndex) {
      subtitle = _catalog.items.any(
        (UnifiedIngredientSearchItem item) =>
            item.isMachineTranslatedOpenNutrition,
      )
          ? '${_catalog.items.length} risultati verificati · '
              'traduzione automatica con Google Translate'
          : '${_catalog.items.length} risultati verificati nella pagina';
    } else if (_catalogMode == OpenNutritionSearchMode.remote) {
      subtitle = '${_catalog.items.length} risultati firmati nella pagina';
    } else {
      subtitle = '${_catalog.items.length} risultati nella pagina';
    }

    final String emptyMessage;
    if (_catalogLoading) {
      emptyMessage = 'OpenNutrition sta elaborando la richiesta.';
    } else if (_catalogBlockedMessage != null) {
      emptyMessage = _catalogBlockedMessage!;
    } else if (_catalogMode == OpenNutritionSearchMode.staticIndex &&
        _query.length < 3) {
      emptyMessage = 'Digita almeno tre caratteri.';
    } else if (_query.length < 2) {
      emptyMessage = 'Digita almeno due caratteri.';
    } else if (_catalogMode == OpenNutritionSearchMode.staticIndex) {
      emptyMessage = 'Nessun match OpenNutrition sufficientemente affidabile.';
    } else if (_catalogMode == OpenNutritionSearchMode.remote) {
      emptyMessage = 'Nessun risultato dal gateway OpenNutrition.';
    } else {
      emptyMessage = 'Nessun risultato nel catalogo OpenNutrition.';
    }

    return Column(
      children: <Widget>[
        if (_catalogLoading) ...<Widget>[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
        ],
        _SearchSection(
          title: switch (_catalogMode) {
            OpenNutritionSearchMode.staticIndex =>
              'OpenNutrition · indice statico verificato',
            OpenNutritionSearchMode.remote => 'OpenNutrition online verificato',
            OpenNutritionSearchMode.local => 'Catalogo OpenNutrition locale',
            OpenNutritionSearchMode.unavailable => 'OpenNutrition',
          },
          subtitle: subtitle,
          expanded: _catalogExpanded,
          onToggle: () {
            setState(() => _catalogExpanded = !_catalogExpanded);
          },
          onRetry: _reloadOpenNutrition,
          error: _catalogError,
          emptyMessage: emptyMessage,
          items: _catalog.items,
          onItem: _select,
          pager: _Pager(
            page: _catalog.page,
            hasPrevious: _catalog.hasPrevious,
            hasNext: _catalog.hasNext,
            onPrevious: () {
              setState(() => _catalogPage -= 1);
              _reloadOpenNutrition();
            },
            onNext: () {
              setState(() => _catalogPage += 1);
              _reloadOpenNutrition();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOpenFoodFactsSection() {
    final String subtitle = _offLoading
        ? 'Ricerca Open Food Facts in corso · fino a 20 tentativi automatici…'
        : _query.length < 3
            ? 'Digita almeno tre caratteri'
            : '${_off.items.length} risultati nella pagina';

    return Column(
      children: <Widget>[
        if (_offLoading) ...<Widget>[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
        ],
        _SearchSection(
          title: 'Open Food Facts online',
          subtitle: subtitle,
          expanded: _offExpanded,
          onToggle: () {
            setState(() => _offExpanded = !_offExpanded);
          },
          onRetry: _reloadOpenFoodFacts,
          error: _offError,
          emptyMessage: _offLoading
              ? 'Open Food Facts sta elaborando la richiesta.'
              : _query.length < 3
                  ? 'Digita almeno tre caratteri per cercare nome o brand.'
                  : 'Nessun risultato su Open Food Facts.',
          items: _off.items,
          onItem: _select,
          pager: _Pager(
            page: _off.page,
            hasPrevious: _off.hasPrevious,
            hasNext: _off.hasNext,
            onPrevious: () {
              setState(() => _offPage -= 1);
              _reloadOpenFoodFacts();
            },
            onNext: () {
              setState(() => _offPage += 1);
              _reloadOpenFoodFacts();
            },
          ),
        ),
      ],
    );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection({
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onToggle,
    required this.onRetry,
    required this.error,
    required this.emptyMessage,
    required this.items,
    required this.onItem,
    required this.pager,
  });

  final String title;
  final String subtitle;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onRetry;
  final Object? error;
  final String emptyMessage;
  final List<UnifiedIngredientSearchItem> items;
  final ValueChanged<UnifiedIngredientSearchItem> onItem;
  final Widget pager;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _SectionHeader(
          title: title,
          subtitle: subtitle,
          expanded: expanded,
          onToggle: onToggle,
        ),
        if (expanded) ...<Widget>[
          const SizedBox(height: 8),
          if (error != null)
            _ErrorCard(
              error: error!,
              onRetry: onRetry,
            )
          else if (items.isEmpty)
            _EmptyCard(message: emptyMessage)
          else
            ...items.map(
              (UnifiedIngredientSearchItem item) => _IngredientCard(
                item: item,
                onTap: () => onItem(item),
              ),
            ),
          pager,
        ],
      ],
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
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        trailing: onToggle == null
            ? null
            : Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
              ),
      ),
    );
  }
}

class _IngredientCard extends StatelessWidget {
  const _IngredientCard({
    required this.item,
    required this.onTap,
  });

  final UnifiedIngredientSearchItem item;
  final VoidCallback onTap;

  IconData get _sourceIcon {
    switch (item.sourceTypeCode) {
      case IngredientSourceTypeCodes.openNutrition:
        return item.isStaticOpenNutrition
            ? Icons.cloud_done_outlined
            : item.isRemoteOpenNutrition
                ? Icons.verified_user_outlined
                : Icons.storage_outlined;
      case IngredientSourceTypeCodes.openFoodFacts:
        return Icons.qr_code_2_outlined;
      default:
        return Icons.person_outline;
    }
  }

  String get _sourceLabel {
    switch (item.sourceTypeCode) {
      case IngredientSourceTypeCodes.openNutrition:
        return item.isStaticOpenNutrition
            ? item.isMachineTranslatedOpenNutrition
                ? 'OpenNutrition · Google Translate'
                : 'OpenNutrition · indice statico'
            : item.isRemoteOpenNutrition
                ? 'OpenNutrition online verificato'
                : 'OpenNutrition';
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
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
    const Widget fallback = ColoredBox(
      color: Color(0x11000000),
      child: Icon(Icons.restaurant_outlined),
    );
    final String value = source.trim();
    if (value.isEmpty) return fallback;

    final Uri? uri = Uri.tryParse(value);
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
    if (!hasPrevious && !hasNext) {
      return const SizedBox.shrink();
    }
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('Ricerca non riuscita'),
        subtitle: Text(error.toString()),
        trailing: IconButton(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
        ),
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
  int _refreshRevision = 0;
  bool _isAdding = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        KeyedSubtree(
          key: ValueKey<int>(_refreshRevision),
          child: widget.child,
        ),
        Positioned(
          right: 16,
          bottom: 104,
          child: SafeArea(
            child: FloatingActionButton.extended(
              heroTag:
                  'ingredient-search-${widget.targetType}-${widget.targetId}',
              tooltip: 'Aggiungi alimento',
              onPressed: _isAdding ? null : _selectAndAdd,
              icon: _isAdding
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Alimento'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectAndAdd() async {
    if (_isAdding) return;
    setState(() => _isAdding = true);
    try {
      final IngredientEntity? ingredient = await context.push(
        '/food/ingredients/search?select=1',
      );
      if (ingredient == null || !mounted) return;

      final double? grams = await _askGrams(ingredient.name);
      if (grams == null || !mounted) return;

      final int? id = int.tryParse(widget.targetId);
      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Identificativo destinazione non valido.'),
          ),
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

      if (!mounted) return;
      setState(() => _refreshRevision += 1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ingredient.name} aggiunto: ${grams.toStringAsFixed(0)} g.',
          ),
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aggiunta alimento non riuscita: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  Future<double?> _askGrams(String name) async {
    final TextEditingController controller = TextEditingController(text: '100');
    try {
      return await showDialog<double>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text('Quantità di $name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
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
                final double? value = double.tryParse(
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
