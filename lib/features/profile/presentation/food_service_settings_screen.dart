import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/preferences/food_service_preferences.dart';
import '../../../l10n/l10n.dart';

class FoodServiceSettingsScreen extends ConsumerWidget {
  const FoodServiceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(foodServicePreferencesProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.onlineFoodSources)),
      body: preferences.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: SwitchListTile(
                    secondary: const Icon(Icons.qr_code_scanner_rounded),
                    title: Text(l10n.enableOpenFoodFacts),
                    subtitle: Text(l10n.openFoodFactsDescription),
                    value: preferences.openFoodFactsEnabled,
                    onChanged: preferences.setOpenFoodFactsEnabled,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.storage_rounded),
                        title: Text(l10n.enableOpenNutrition),
                        subtitle: Text(l10n.openNutritionDescription),
                        value: preferences.openNutritionSearchEnabled,
                        onChanged: preferences.setOpenNutritionSearchEnabled,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.tune_rounded),
                        title: Text(l10n.openNutritionAdvanced),
                        subtitle: Text(l10n.openNutritionAdvancedDescription),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/settings/opennutrition'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(l10n.onlineSourcesIndependent)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
