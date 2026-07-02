import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/preferences/food_service_preferences.dart';

class FoodServiceSettingsScreen extends ConsumerWidget {
  const FoodServiceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(foodServicePreferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Servizi alimentari online')),
      body: preferences.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Card(
                  child: SwitchListTile(
                    title: const Text('Abilita servizi Open Food Facts'),
                    subtitle: const Text(
                      'Controlla ricerca online, scanner barcode e importazioni da Open Food Facts. '
                      'Gli alimenti già importati restano disponibili.',
                    ),
                    value: preferences.openFoodFactsEnabled,
                    onChanged: preferences.setOpenFoodFactsEnabled,
                  ),
                ),
              ],
            ),
    );
  }
}
