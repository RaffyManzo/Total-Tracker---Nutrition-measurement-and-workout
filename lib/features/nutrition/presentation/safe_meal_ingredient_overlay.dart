import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/objectbox_providers.dart';
import '../../../core/diagnostics/app_diagnostics.dart';
import '../data/entities/ingredient_entity.dart';

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
  int _revision = 0;

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
          },
        ),
      );

      final double? grams = await showDialog<double>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) =>
            _IngredientQuantityDialog(ingredientName: ingredient.name),
      );
      if (!mounted || grams == null) return;

      // The route and dialog overlays must finish their exit animations before
      // the meal subtree is rebuilt. This prevents disposed controllers and
      // duplicated Overlay GlobalKeys.
      await Future<void>.delayed(const Duration(milliseconds: 360));
      if (!mounted) return;

      final int mealId = int.parse(widget.targetId);
      final Stopwatch saveWatch = Stopwatch()..start();
      ref.read(mealRepositoryProvider).addIngredientItem(
            mealId: mealId,
            ingredient: ingredient,
            grams: grams,
          );
      saveWatch.stop();

      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      setState(() => _revision += 1);

      unawaited(
        AppDiagnostics.instance.info(
          'ingredient.add_to_meal.completed',
          data: <String, Object?>{
            'mealId': mealId,
            'ingredientId': ingredient.id,
            'grams': grams,
            'saveMs': saveWatch.elapsedMilliseconds,
          },
        ),
      );
    } catch (error, stackTrace) {
      await AppDiagnostics.instance.error(
        'ingredient.add_to_meal.failed',
        error: error,
        stackTrace: stackTrace,
        data: <String, Object?>{'mealId': widget.targetId},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aggiungere l alimento: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        KeyedSubtree(
          key: ValueKey<String>('meal-${widget.targetId}-$_revision'),
          child: widget.child,
        ),
        Positioned(
          right: 16,
          bottom: 86,
          child: SafeArea(
            child: FloatingActionButton.extended(
              heroTag: 'safe-add-food-${widget.targetId}',
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
  late final TextEditingController _controller =
      TextEditingController(text: '100');
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    final double grams =
        double.parse(_controller.text.trim().replaceAll(',', '.'));
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    Navigator.of(context).pop<double>(grams);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.ingredientName),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Quantita',
            suffixText: 'g',
          ),
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
