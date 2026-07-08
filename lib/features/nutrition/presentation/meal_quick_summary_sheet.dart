import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../data/food_data_refresh_bus.dart';
import '../data/repositories/meal_repository.dart';

Future<void> openMealQuickSummary(
  BuildContext context, {
  required MealWithItems meal,
}) async {
  final bool openFull = await showMealQuickSummarySheet(context, meal: meal);
  if (!context.mounted || !openFull) return;
  await context.push('/food/meals/${meal.meal.id}');
  if (context.mounted) {
    FoodDataRefreshBus.publishManualRefresh(meal.meal.dateKey);
  }
}

Future<bool> showMealQuickSummarySheet(
  BuildContext context, {
  required MealWithItems meal,
}) async {
  final totals = meal.totals;
  final bool? openFull = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) {
      final String slot = meal.meal.mealTypeCode;
      final String status = meal.meal.mealModeCode == 'free'
          ? (meal.isNutritionPartial
              ? 'Pasto libero · parziale'
              : 'Pasto libero')
          : (meal.items.isEmpty ? 'Pasto vuoto' : 'Pasto standard');
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(_slotEmoji(slot), style: const TextStyle(fontSize: 28)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        meal.meal.title,
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                      Text('$status · ${meal.items.length} voci'),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Chiudi riepilogo',
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (meal.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(child: Text('Nessun alimento registrato.')),
              )
            else
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: meal.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final item = meal.items[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.itemNameSnapshot),
                        subtitle: Text(
                          item.quantityModeCode == 'portions'
                              ? '${item.portions ?? 0} porzioni'
                              : '${item.grams ?? 0} g',
                        ),
                        trailing: Text('${item.kcal.round()} kcal'),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                _Metric(label: 'Calorie', value: '${totals.kcal.round()} kcal'),
                _Metric(
                  label: 'Proteine',
                  value: '${totals.proteinGrams.toStringAsFixed(1)} g',
                ),
                _Metric(
                  label: 'Carboidrati',
                  value: '${totals.carbsGrams.toStringAsFixed(1)} g',
                ),
                _Metric(
                  label: 'Grassi',
                  value: '${totals.fatGrams.toStringAsFixed(1)} g',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Apri pasto completo'),
              ),
            ),
          ],
        ),
      );
    },
  );
  return openFull == true;
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

String _slotEmoji(String slot) {
  return const <String, String>{
        'colazione': '🥣',
        'spuntino': '🍎',
        'pranzo': '🍝',
        'cena': '🍽️',
      }[slot] ??
      '🍴';
}
