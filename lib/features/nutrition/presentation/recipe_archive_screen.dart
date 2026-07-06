import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/objectbox_providers.dart';
import '../../../core/diagnostics/app_diagnostics.dart';
import '../../../shared/widgets/tt_app_card.dart';
import '../../../shared/widgets/tt_primary_button.dart';
import '../../../shared/widgets/tt_global_nav_fab.dart';
import '../data/entities/nutrition_tracking_entities.dart';

final FutureProvider<List<RecipeEntity>> recipeArchiveScreenProvider =
    FutureProvider<List<RecipeEntity>>((Ref ref) async {
  return AppDiagnostics.instance.measure<List<RecipeEntity>>(
    'recipes.archive_load',
    () async => ref.watch(recipeRepositoryProvider).getAllActive(),
  );
});

class RecipeArchiveScreen extends ConsumerStatefulWidget {
  const RecipeArchiveScreen({super.key});

  @override
  ConsumerState<RecipeArchiveScreen> createState() =>
      _RecipeArchiveScreenState();
}

class _RecipeArchiveScreenState extends ConsumerState<RecipeArchiveScreen> {
  final TextEditingController _search = TextEditingController();
  String _difficulty = '';
  String _course = '';
  String _cuisine = '';
  String _imageFilter = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<RecipeEntity>> recipes =
        ref.watch(recipeArchiveScreenProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ricette')),
      bottomNavigationBar: const TtFoodBottomNavBar(
        activeItem: TtFoodNavItem.none,
      ),
      body: recipes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Caricamento ricette non riuscito: $error'),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(recipeArchiveScreenProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Riprova'),
                ),
              ],
            ),
          ),
        ),
        data: (List<RecipeEntity> allRecipes) {
          final List<String> difficulties = _values(
            allRecipes.map((RecipeEntity item) => item.difficultyCode),
          );
          final List<String> courses = _values(
            allRecipes.map((RecipeEntity item) => item.courseCode),
          );
          final List<String> cuisines = _values(
            allRecipes.map((RecipeEntity item) => item.cuisineCode),
          );
          final List<RecipeEntity> visible = allRecipes.where(_matches).toList()
            ..sort((RecipeEntity a, RecipeEntity b) =>
                a.title.toLowerCase().compareTo(b.title.toLowerCase()));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(recipeArchiveScreenProvider);
              await ref.read(recipeArchiveScreenProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
              children: <Widget>[
                TtPrimaryButton(
                  label: 'Nuova ricetta',
                  icon: Icons.add_rounded,
                  onPressed: _createRecipe,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Cerca ricetta',
                    hintText: 'Nome, portata, cucina o difficoltà',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Cancella ricerca',
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear_rounded),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openRecipeFilters(
                          difficulties: difficulties,
                          courses: courses,
                          cuisines: cuisines,
                        ),
                        icon: const Icon(Icons.tune_rounded),
                        label: Text(
                          _activeFilterCount == 0
                              ? 'Filtri'
                              : 'Filtri ($_activeFilterCount)',
                        ),
                      ),
                    ),
                    if (_activeFilterCount > 0) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.filledTonal(
                        tooltip: 'Pulisci filtri',
                        onPressed: _clearRecipeFilters,
                        icon: const Icon(Icons.filter_alt_off_rounded),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${visible.length} di ${allRecipes.length} ricette',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                if (visible.isEmpty)
                  const TtAppCard(
                    child: Text('Nessuna ricetta corrisponde ai filtri.'),
                  )
                else
                  for (final RecipeEntity recipe in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _RecipeArchiveCard(recipe: recipe),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  int get _activeFilterCount => <String>[
        _difficulty,
        _course,
        _cuisine,
        _imageFilter,
      ].where((String value) => value.isNotEmpty).length;

  void _clearRecipeFilters() {
    final int previousCount = _activeFilterCount;
    setState(() {
      _difficulty = '';
      _course = '';
      _cuisine = '';
      _imageFilter = '';
    });
    unawaited(
      AppDiagnostics.instance.info(
        'recipes.filters_cleared',
        data: <String, Object?>{'previousActiveFilterCount': previousCount},
      ),
    );
  }

  Future<void> _openRecipeFilters({
    required List<String> difficulties,
    required List<String> courses,
    required List<String> cuisines,
  }) async {
    String temporaryDifficulty = _difficulty;
    String temporaryCourse = _course;
    String temporaryCuisine = _cuisine;
    String temporaryImage = _imageFilter;
    final Stopwatch watch = Stopwatch()..start();
    unawaited(
      AppDiagnostics.instance.info(
        'recipes.filter_sheet_opened',
        data: <String, Object?>{'activeFilterCount': _activeFilterCount},
      ),
    );

    final bool? save = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            void Function(void Function()) setSheetState,
          ) {
            Widget dropdown({
              required String label,
              required String value,
              required List<String> values,
              required ValueChanged<String> onChanged,
              Map<String, String> labels = const <String, String>{},
            }) {
              return DropdownButtonFormField<String>(
                key: ValueKey<String>('recipe-filter-$label-$value'),
                initialValue: value,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: label,
                  border: const OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Tutte'),
                  ),
                  for (final String item in values)
                    DropdownMenuItem<String>(
                      value: item,
                      child: Text(labels[item] ?? item),
                    ),
                ],
                onChanged: (String? selected) => onChanged(selected ?? ''),
              );
            }

            final int temporaryCount = <String>[
              temporaryDifficulty,
              temporaryCourse,
              temporaryCuisine,
              temporaryImage,
            ].where((String value) => value.isNotEmpty).length;

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Filtri ricette',
                      style: Theme.of(sheetContext).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      temporaryCount == 0
                          ? 'Nessun filtro selezionato.'
                          : '$temporaryCount filtri selezionati.',
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    dropdown(
                      label: 'Difficoltà',
                      value: temporaryDifficulty,
                      values: difficulties,
                      onChanged: (String value) => setSheetState(
                        () => temporaryDifficulty = value,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    dropdown(
                      label: 'Portata',
                      value: temporaryCourse,
                      values: courses,
                      onChanged: (String value) => setSheetState(
                        () => temporaryCourse = value,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    dropdown(
                      label: 'Cucina',
                      value: temporaryCuisine,
                      values: cuisines,
                      onChanged: (String value) => setSheetState(
                        () => temporaryCuisine = value,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    dropdown(
                      label: 'Immagine',
                      value: temporaryImage,
                      values: const <String>['present', 'missing'],
                      labels: const <String, String>{
                        'present': 'Con immagine',
                        'missing': 'Senza immagine',
                      },
                      onChanged: (String value) => setSheetState(
                        () => temporaryImage = value,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: () => setSheetState(() {
                        temporaryDifficulty = '';
                        temporaryCourse = '';
                        temporaryCuisine = '';
                        temporaryImage = '';
                      }),
                      icon: const Icon(Icons.filter_alt_off_rounded),
                      label: const Text('Pulisci filtri'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(sheetContext, false),
                            child: const Text('Annulla'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(sheetContext, true),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Salva filtri'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    watch.stop();
    if (save != true || !mounted) {
      unawaited(
        AppDiagnostics.instance.info(
          'recipes.filter_sheet_closed',
          data: <String, Object?>{
            'saved': false,
            'elapsedMs': watch.elapsedMilliseconds,
          },
        ),
      );
      return;
    }
    setState(() {
      _difficulty = temporaryDifficulty;
      _course = temporaryCourse;
      _cuisine = temporaryCuisine;
      _imageFilter = temporaryImage;
    });
    unawaited(
      AppDiagnostics.instance.info(
        'recipes.filters_applied',
        data: <String, Object?>{
          'activeFilterCount': _activeFilterCount,
          'elapsedMs': watch.elapsedMilliseconds,
        },
      ),
    );
  }

  Future<void> _createRecipe() async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    String title = '';
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Nuova ricetta'),
          content: Form(
            key: formKey,
            child: TextFormField(
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome ricetta'),
              onChanged: (String value) => title = value.trim(),
              validator: (String? value) =>
                  value == null || value.trim().isEmpty
                      ? 'Inserisci il nome della ricetta.'
                      : null,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Crea'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted || title.isEmpty) return;

    final RecipeEntity recipe = ref.read(recipeRepositoryProvider).save(
          RecipeEntity(
            uuid: '',
            title: title,
            createdAtEpochMs: 0,
            updatedAtEpochMs: 0,
          ),
        );
    ref.invalidate(recipeArchiveScreenProvider);
    if (!mounted) return;
    await context.push('/food/recipes/${recipe.id}');
    ref.invalidate(recipeArchiveScreenProvider);
  }

  bool _matches(RecipeEntity recipe) {
    final String query = _search.text.trim().toLowerCase();
    final String searchable = <String>[
      recipe.title,
      recipe.subtitle,
      recipe.summary,
      recipe.difficultyCode,
      recipe.courseCode,
      recipe.cuisineCode,
    ].join(' ').toLowerCase();
    if (query.isNotEmpty && !searchable.contains(query)) return false;
    if (_difficulty.isNotEmpty && recipe.difficultyCode != _difficulty) {
      return false;
    }
    if (_course.isNotEmpty && recipe.courseCode != _course) return false;
    if (_cuisine.isNotEmpty && recipe.cuisineCode != _cuisine) return false;
    final bool hasImage = recipe.imagePath.trim().isNotEmpty;
    if (_imageFilter == 'present' && !hasImage) return false;
    if (_imageFilter == 'missing' && hasImage) return false;
    return true;
  }

  List<String> _values(Iterable<String> source) {
    return source
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }
}

class _RecipeArchiveCard extends StatelessWidget {
  const _RecipeArchiveCard({required this.recipe});

  final RecipeEntity recipe;

  @override
  Widget build(BuildContext context) {
    final double? finalWeight = recipe.yieldGrams ?? recipe.totalWeightGrams;
    final String kcal = recipe.kcalPerServing == null
        ? 'kcal n/d'
        : '${recipe.kcalPerServing!.round()} kcal/porzione';
    final String weight = finalWeight == null
        ? 'peso finale n/d'
        : '${finalWeight.round()} g finali';

    return TtAppCard(
      onTap: () => context.push('/food/recipes/${recipe.id}'),
      child: Row(
        children: <Widget>[
          _RecipeImage(path: recipe.imagePath),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  recipe.title.trim().isEmpty ? 'Ricetta' : recipe.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '$kcal · ${recipe.servings} porzioni · $weight',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (recipe.courseCode.trim().isNotEmpty ||
                    recipe.cuisineCode.trim().isNotEmpty ||
                    recipe.difficultyCode.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xxs,
                    children: <Widget>[
                      if (recipe.difficultyCode.trim().isNotEmpty)
                        Chip(
                          label: Text(recipe.difficultyCode),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (recipe.courseCode.trim().isNotEmpty)
                        Chip(
                          label: Text(recipe.courseCode),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (recipe.cuisineCode.trim().isNotEmpty)
                        Chip(
                          label: Text(recipe.cuisineCode),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _RecipeImage extends StatelessWidget {
  const _RecipeImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final String source = path.trim();
    final Widget fallback = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.menu_book_rounded)),
    );

    Widget image = fallback;
    if (source.startsWith('http://') || source.startsWith('https://')) {
      image = Image.network(
        source,
        fit: BoxFit.cover,
        cacheWidth: 180,
        errorBuilder: (_, __, ___) => fallback,
      );
    } else if (source.isNotEmpty) {
      image = Image.file(
        File(source),
        fit: BoxFit.cover,
        cacheWidth: 180,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox.square(dimension: 76, child: image),
    );
  }
}
