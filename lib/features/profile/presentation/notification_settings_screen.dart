import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/background/background_tasks.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/preferences/food_service_preferences.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _reconcile() {
    return ReminderBackgroundJobs.reconcileRegistration();
  }

  Future<void> _setMaster(
    BuildContext context,
    FoodServicePreferencesController preferences,
    bool value,
  ) async {
    if (value) {
      final bool granted = await LocalNotificationService.requestPermission();
      if (!granted) {
        await preferences.setNotificationsEnabled(false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permesso notifiche non concesso dal sistema.',
              ),
            ),
          );
        }
        return;
      }
      await preferences.setNotificationsEnabled(true);
    } else {
      await preferences.setNotificationsEnabled(false);
      await LocalNotificationService.cancelAll();
    }
    await _reconcile();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FoodServicePreferencesController preferences =
        ref.watch(foodServicePreferencesProvider);
    final bool master = preferences.notificationsEnabled;

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
                    subtitle: Text(
                      master
                          ? 'Le categorie abilitate possono inviare notifiche.'
                          : 'Reminder e notifiche operative sono disattivati.',
                    ),
                    value: master,
                    onChanged: (bool value) =>
                        _setMaster(context, preferences, value),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: <Widget>[
                      SwitchListTile(
                        title: const Text('Promemoria pasti'),
                        subtitle: const Text(
                          'Dopo le 15:00, se non è stato registrato alcun pasto.',
                        ),
                        value: preferences.mealReminderEnabled,
                        onChanged: master
                            ? (bool value) async {
                                await preferences.setMealReminderEnabled(value);
                                await _reconcile();
                              }
                            : null,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Promemoria peso'),
                        subtitle: const Text(
                          'Quando non viene registrato un peso da almeno 7 giorni.',
                        ),
                        value: preferences.weightReminderEnabled,
                        onChanged: master
                            ? (bool value) async {
                                await preferences
                                    .setWeightReminderEnabled(value);
                                await _reconcile();
                              }
                            : null,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Misurazioni corporee'),
                        subtitle: const Text(
                          'Quando sono trascorsi due mesi dall’ultima misura.',
                        ),
                        value: preferences.bodyReminderEnabled,
                        onChanged: master
                            ? (bool value) async {
                                await preferences.setBodyReminderEnabled(value);
                                await _reconcile();
                              }
                            : null,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Operazioni in background'),
                        subtitle: const Text(
                          'Avanzamento ed esito dell’importazione OpenNutrition.',
                        ),
                        value: preferences.backgroundOperationsEnabled,
                        onChanged: master
                            ? preferences.setBackgroundOperationsEnabled
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: master
                      ? LocalNotificationService.showTestNotification
                      : null,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Invia notifica di prova'),
                ),
              ],
            ),
    );
  }
}
