import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/background/background_tasks.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/preferences/food_service_preferences.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _afterChange() => ReminderBackgroundJobs.reconcileRegistration();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(foodServicePreferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifiche')),
      body: preferences.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Card(
                  child: SwitchListTile(
                    title: const Text('Notifiche generali'),
                    subtitle: const Text(
                      'Interruttore principale per reminder e operazioni in background.',
                    ),
                    value: preferences.notificationsEnabled,
                    onChanged: (bool value) async {
                      if (value) {
                        final granted =
                            await LocalNotificationService.requestPermission();
                        if (!granted && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Permesso notifiche non concesso dal sistema.',
                              ),
                            ),
                          );
                          return;
                        }
                      }
                      await preferences.setNotificationsEnabled(value);
                      await _afterChange();
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: <Widget>[
                      SwitchListTile(
                        title: const Text('Promemoria pasti'),
                        subtitle: const Text(
                          'Dopo le 15:00, se non è stato registrato alcun pasto nella giornata.',
                        ),
                        value: preferences.mealReminderEnabled,
                        onChanged: (bool value) async {
                          await preferences.setMealReminderEnabled(value);
                          await _afterChange();
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Promemoria peso'),
                        subtitle: const Text(
                          'Quando non viene registrato un peso da almeno 7 giorni.',
                        ),
                        value: preferences.weightReminderEnabled,
                        onChanged: (bool value) async {
                          await preferences.setWeightReminderEnabled(value);
                          await _afterChange();
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Misurazioni corporee'),
                        subtitle: const Text(
                          'Quando sono trascorsi due mesi di calendario dall’ultima misura con metro.',
                        ),
                        value: preferences.bodyReminderEnabled,
                        onChanged: (bool value) async {
                          await preferences.setBodyReminderEnabled(value);
                          await _afterChange();
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Operazioni in background'),
                        subtitle: const Text(
                          'Esito di download e importazione OpenNutrition.',
                        ),
                        value: preferences.backgroundOperationsEnabled,
                        onChanged:
                            preferences.setBackgroundOperationsEnabled,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'I controlli vengono riconciliati in background. Android e iOS possono '
                      'ritardare l’esecuzione per risparmio energetico; la deduplicazione evita '
                      'notifiche ripetute per lo stesso periodo.',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
