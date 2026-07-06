import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/objectbox_providers.dart';
import '../../../core/diagnostics/app_diagnostics.dart';
import '../../../core/diagnostics/interaction_trace.dart';
import '../data/food_data_refresh_bus.dart';
import '../data/entities/ingredient_entity.dart';
import '../data/repositories/meal_repository.dart';
import 'food_v01_screens.dart';
import 'unified_ingredient_search_screen.dart';

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
    if (_busy) {
      InteractionTrace.event('meal_add_flow.ignored_busy');
      return;
    }
    setState(() => _busy = true);
    final String flowId =
        DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final InteractionTraceSpan flowTrace = InteractionTrace.start(
      'meal_add_flow',
      data: <String, Object?>{'flowId': flowId, 'flowVersion': 6},
    );

    try {
      final NavigatorState navigator = Navigator.of(context);
      final MaterialPageRoute<IngredientEntity> selectionRoute =
          MaterialPageRoute<IngredientEntity>(
        builder: (BuildContext context) =>
            const UnifiedIngredientSearchScreen(selectionMode: true),
        settings: RouteSettings(
          name: 'meal-ingredient-selection',
          arguments: <String, Object?>{'flowId': flowId},
        ),
      );
      final Stopwatch selectionWatch = Stopwatch()..start();
      InteractionTrace.event(
        'meal_add_flow.selection_route_pushed',
        data: <String, Object?>{
          'flowId': flowId,
          'navigatorMounted': navigator.mounted,
        },
      );

      final IngredientEntity? ingredient =
          await navigator.push<IngredientEntity>(selectionRoute);
      InteractionTrace.event(
        'meal_add_flow.selection_pop_requested',
        data: <String, Object?>{
          'flowId': flowId,
          'selected': ingredient != null,
          'widgetMounted': mounted,
          'elapsedMs': selectionWatch.elapsedMilliseconds,
        },
      );
      await selectionRoute.completed;
      selectionWatch.stop();
      InteractionTrace.event(
        'meal_add_flow.selection_route_disposed',
        data: <String, Object?>{
          'flowId': flowId,
          'selected': ingredient != null,
          'widgetMounted': mounted,
          'elapsedMs': selectionWatch.elapsedMilliseconds,
          'primaryFocusPresent': FocusManager.instance.primaryFocus != null,
        },
      );
      if (!mounted || ingredient == null) {
        flowTrace
            .complete(data: <String, Object?>{'result': 'selection_cancelled'});
        return;
      }

      final DialogRoute<double> quantityRoute = DialogRoute<double>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => _IngredientQuantityDialog(
          ingredientName: ingredient.name,
          flowId: flowId,
        ),
        settings: RouteSettings(
          name: 'meal-ingredient-quantity',
          arguments: <String, Object?>{'flowId': flowId},
        ),
      );
      final Stopwatch quantityWatch = Stopwatch()..start();
      InteractionTrace.event(
        'meal_add_flow.quantity_route_pushed',
        data: <String, Object?>{'flowId': flowId},
      );
      final double? grams = await navigator.push<double>(quantityRoute);
      InteractionTrace.event(
        'meal_add_flow.quantity_pop_requested',
        data: <String, Object?>{
          'flowId': flowId,
          'confirmed': grams != null,
          'widgetMounted': mounted,
          'elapsedMs': quantityWatch.elapsedMilliseconds,
        },
      );
      await quantityRoute.completed;
      quantityWatch.stop();
      InteractionTrace.event(
        'meal_add_flow.quantity_route_disposed',
        data: <String, Object?>{
          'flowId': flowId,
          'confirmed': grams != null,
          'widgetMounted': mounted,
          'elapsedMs': quantityWatch.elapsedMilliseconds,
          'primaryFocusPresent': FocusManager.instance.primaryFocus != null,
        },
      );
      if (!mounted || grams == null) {
        flowTrace
            .complete(data: <String, Object?>{'result': 'quantity_cancelled'});
        return;
      }

      final int? mealId = int.tryParse(widget.targetId);
      if (mealId == null) {
        throw FormatException('Identificativo pasto non valido');
      }

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

      InteractionTrace.event(
        'meal_add_flow.persisted',
        data: <String, Object?>{
          'flowId': flowId,
          'saveMs': saveWatch.elapsedMilliseconds,
          'dayMealCount': dayMeals.length,
        },
      );
      flowTrace.complete(data: <String, Object?>{'result': 'saved'});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alimento aggiunto al pasto.')),
      );
    } catch (error, stackTrace) {
      flowTrace.fail(error, stackTrace);
      await AppDiagnostics.instance.error(
        'ingredient.add_to_meal.failed',
        error: error,
        stackTrace: stackTrace,
        data: <String, Object?>{'flowId': flowId, 'flowVersion': 6},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impossibile aggiungere l'alimento: $error")),
      );
    } finally {
      InteractionTrace.event(
        'meal_add_flow.finally',
        data: <String, Object?>{
          'flowId': flowId,
          'widgetMounted': mounted,
          'primaryFocusPresent': FocusManager.instance.primaryFocus != null,
        },
      );
      if (mounted) setState(() => _busy = false);
    }
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
  const _IngredientQuantityDialog({
    required this.ingredientName,
    required this.flowId,
  });

  final String ingredientName;
  final String flowId;

  @override
  State<_IngredientQuantityDialog> createState() =>
      _IngredientQuantityDialogState();
}

class _IngredientQuantityDialogState extends State<_IngredientQuantityDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _quantityText = '100';
  bool _submitting = false;
  bool _firstBuildLogged = false;

  @override
  void initState() {
    super.initState();
    InteractionTrace.event(
      'meal_add_flow.quantity_dialog_initialized',
      data: <String, Object?>{'flowId': widget.flowId},
    );
  }

  @override
  void dispose() {
    InteractionTrace.event(
      'meal_add_flow.quantity_dialog_dispose',
      data: <String, Object?>{
        'flowId': widget.flowId,
        'submitting': _submitting,
        'primaryFocusPresent': FocusManager.instance.primaryFocus != null,
      },
    );
    super.dispose();
  }

  void _submit() {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    final double grams =
        double.parse(_quantityText.trim().replaceAll(',', '.'));
    FocusManager.instance.primaryFocus?.unfocus();
    _submitting = true;
    InteractionTrace.event(
      'meal_add_flow.quantity_dialog_submit',
      data: <String, Object?>{
        'flowId': widget.flowId,
        'mounted': mounted,
        'primaryFocusPresent': FocusManager.instance.primaryFocus != null,
      },
    );
    Navigator.of(context).pop<double>(grams);
  }

  @override
  Widget build(BuildContext context) {
    if (!_firstBuildLogged) {
      _firstBuildLogged = true;
      InteractionTrace.event(
        'meal_add_flow.quantity_dialog_first_build',
        data: <String, Object?>{'flowId': widget.flowId},
      );
    }
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
            labelText: 'Quantità',
            suffixText: 'g',
          ),
          onChanged: (String value) => _quantityText = value,
          validator: (String? value) {
            final double? grams =
                double.tryParse((value ?? '').trim().replaceAll(',', '.'));
            if (grams == null || grams <= 0) {
              return 'Inserisci una quantità valida.';
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _submitting
              ? null
              : () {
                  InteractionTrace.event(
                    'meal_add_flow.quantity_dialog_cancel',
                    data: <String, Object?>{'flowId': widget.flowId},
                  );
                  Navigator.of(context).pop<double>();
                },
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
