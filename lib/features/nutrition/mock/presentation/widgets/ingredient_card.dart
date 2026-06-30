import 'package:flutter/material.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../shared/widgets/tt_app_card.dart';
import '../../domain/mock_ingredient.dart';

class IngredientCard extends StatelessWidget {
  const IngredientCard({
    required this.ingredient,
    required this.onTap,
    super.key,
  });

  final MockIngredient ingredient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Brightness brightness = theme.brightness;

    return TtAppCard(
      onTap: onTap,
      semanticLabel: 'Apri ${ingredient.name}',
      child: Row(
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: brightness == Brightness.light
                  ? AppColors.lightPrimarySoft
                  : AppColors.darkPrimarySoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              ingredient.name.substring(0, 1).toUpperCase(),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  ingredient.name,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${ingredient.brand} Â· ${ingredient.quantity}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${ingredient.kcal100.toStringAsFixed(0)} kcal / 100 ${ingredient.unit}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'P ${ingredient.protein100.toStringAsFixed(1)} Â· '
                  'C ${ingredient.carbs100.toStringAsFixed(1)} Â· '
                  'G ${ingredient.fat100.toStringAsFixed(1)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
