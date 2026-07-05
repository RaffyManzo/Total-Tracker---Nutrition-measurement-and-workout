import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/objectbox_providers.dart';
import '../../../core/diagnostics/app_diagnostics.dart';
import '../data/food_data_refresh_bus.dart';
import '../data/entities/ingredient_entity.dart';
import '../data/repositories/meal_repository.dart';
import 'food_v01_screens.dart';

class SafeMealIngredientOverlay extends ConsumerStatefulWidget {
  const SafeMealIngredientOverlay({
    required this.targetId,
    required this.child,
    super.key,
  });

  final String targetId;
  final Widget child;

  @override
  ConsumerState<SafeMealIngredientOverlay> createState() =>
      _SafeMealIngredientOverlayState();
}

class _SafeMealIngredientOverlayState
    extends ConsumerState<SafeMealIngredientOverlay> {
  bool _busy = false;

  Future<void> _addIngredient() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final IngredientEntity? ingredient = await context.push<IngredientEntity>(
        '/food/ingredients/search?select=1',
      );
      if (!mounted || ingredient == null) return;

      unawaited(
        AppDiagnostics.instance.info(
          'ingredient.selection_returned',
          data: <String, Object?>{
            'ingredientId': ingredient.id,
            'ingredientName': ingredient.name,
            'mealId': widget.targetId,
            'flowVersion': 3,
          },
        ),
      );

      await _waitForSelectionRouteToSettle();
      if (!mounted) return;

      final double? grams = await showDialog<double>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) =>
            _IngredientQuantityDialog(ingredientName: ingredient.name),
      );
      if (!mounted || grams == null) return;

      // The dialog owns no manually managed text controller. Waiting for one frame only
      // separates overlay disposal from ObjectBox writes without rebuilding the
      // meal route or replacing its subtree.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      final int mealId = int.parse(widget.targetId);
      final MealRepository repository = ref.read(mealRepositoryProvider);
      final Stopwatch saveWatch = Stopwatch()..start();
      final MealWithItems updatedMeal = repository.addIngredientItem(
        mealId: mealId,
        ingredient: ingredient,
        grams: grams,
      );
      final List<MealWithItems> dayMeals =
          repository.getMealsWithItemsForDate(updatedMeal.meal.dateKey);
      final double currentCalories = dayMeals.fold<double>(
        0,
        (double sum, MealWithItems meal) => sum + meal.totals.kcal,
      );
      saveWatch.stop();

      FoodDataRefreshBus.publishMeal(
        dateKey: updatedMeal.meal.dateKey,
        currentCalories: currentCalories,
        reason: 'ingredient_added_to_meal',
      );

      ref
        ..invalidate(foodMealsV01Provider)
        ..invalidate(foodDaysV01Provider)
        ..invalidate(foodHubV01Provider);

      unawaited(
        AppDiagnostics.instance.info(
          'ingredient.add_to_meal.completed',
          data: <String, Object?>{
            'mealId': mealId,
            'ingredientId': ingredient.id,
            'grams': grams,
            'saveMs': saveWatch.elapsedMilliseconds,
            'flowVersion': 3,
          },
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alimento aggiunto al pasto.')),
      );
    } catch (error, stackTrace) {
      await AppDiagnostics.instance.error(
        'ingredient.add_to_meal.failed',
        error: error,
        stackTrace: stackTrace,
        data: <String, Object?>{
          'mealId': widget.targetId,
          'flowVersion': 3,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aggiungere l alimento: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _waitForSelectionRouteToSettle() async {
    // Navigator.push completes before every reverse-transition overlay has
    // necessarily finished disposing. Waiting here prevents a new dialog from
    // being inserted while the search TextField route is still leaving.
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        widget.child,
        Positioned(
          right: 16,
          bottom: 86,
          child: SafeArea(
            child: HeroMode(
              enabled: false,
              child: FloatingActionButton.extended(
                heroTag: null,
                onPressed: _busy ? null : _addIngredient,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: const Text('Alimento'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IngredientQuantityDialog extends StatefulWidget {
  const _IngredientQuantityDialog({required this.ingredientName});

  final String ingredientName;

  @override
  State<_IngredientQuantityDialog> createState() =>
      _IngredientQuantityDialogState();
}

class _IngredientQuantityDialogState extends State<_IngredientQuantityDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _quantityText = '100';
  bool _submitting = false;

  void _submit() {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    final double grams =
        double.parse(_quantityText.trim().replaceAll(',', '.'));
    FocusManager.instance.primaryFocus?.unfocus();
    _submitting = true;
    Navigator.of(context).pop<double>(grams);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.ingredientName),
      content: Form(
        key: _formKey,
        child: TextFormField(
          initialValue: _quantityText,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Quantita',
            suffixText: 'g',
          ),
          onChanged: (String value) => _quantityText = value,
          validator: (String? value) {
            final double? grams =
                double.tryParse((value ?? '').trim().replaceAll(',', '.'));
            if (grams == null || grams <= 0) {
              return 'Inserisci una quantita valida.';
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('Continua'),
        ),
      ],
    );
  }
}
