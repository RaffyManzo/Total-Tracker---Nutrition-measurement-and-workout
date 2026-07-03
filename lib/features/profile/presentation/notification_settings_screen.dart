import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/background/background_tasks.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/platform/device_permission_service.dart';
import '../../../core/preferences/food_service_preferences.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _changingMaster = false;

  Future<void> _reconcile() {
    return ReminderBackgroundJobs.reconcileRegistration();
  }

  Future<void> _sendTestNotification() async {
    try {
      final DevicePermissionSnapshot status =
          await DevicePermissionService.readStatus();
      if (!status.reminderNotificationsOperational) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Android non consente ancora le notifiche. Apri la sezione '
              'Permessi dispositivo e abilita il permesso effettivo.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }
      await LocalNotificationService.showTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifica di prova inviata.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notifica di prova non riuscita: $error'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _setMaster(
    FoodServicePreferencesController preferences,
    bool value,
  ) async {
    if (_changingMaster) return;
    setState(() => _changingMaster = true);

    try {
      await preferences.setAllNotificationsEnabled(value);

      if (!value) {
        try {
          await LocalNotificationService.cancelAll()
              .timeout(const Duration(seconds: 8));
        } catch (_) {
          // Le preferenze restano disattivate anche se il plugin non risponde.
        }
        await _reconcile();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tutte le notifiche sono state disattivate.'),
          ),
        );
        return;
      }

      bool granted = false;
      try {
        await LocalNotificationService.initialize();
        await DevicePermissionService.requestNotifications()
            .timeout(const Duration(seconds: 12));
        final DevicePermissionSnapshot status =
            await DevicePermissionService.readStatus();
        granted = status.allNotificationChannelsOperational;
      } catch (_) {
        granted = false;
      }
      await _reconcile();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? 'Notifiche generali e tutte le categorie attivate.'
                : 'Le categorie sono attive nell’app. Android non ha '
                    'concesso il permesso: abilitalo dalle impostazioni '
                    'di sistema.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _changingMaster = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          ? 'Tutte le categorie sono attive.'
                          : 'Tutte le categorie sono disattivate.',
                    ),
                    value: master,
                    onChanged: _changingMaster
                        ? null
                        : (bool value) => _setMaster(
                              preferences,
                              value,
                            ),
                    secondary: _changingMaster
                        ? const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            master
                                ? Icons.notifications_active
                                : Icons.notifications_off_outlined,
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: _changingMaster
                      ? null
                      : () => _setMaster(preferences, !master),
                  icon: Icon(
                    master
                        ? Icons.notifications_off_outlined
                        : Icons.notifications_active_outlined,
                  ),
                  label: Text(
                    master
                        ? 'Disattiva tutte le notifiche'
                        : 'Attiva tutte le notifiche',
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: const Text('Permessi effettivi del dispositivo'),
                    subtitle: const Text(
                      'Controlla lo stato Android, i canali, la fotocamera e '
                      'l’ottimizzazione batteria.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/settings/device-permissions'),
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
                  onPressed:
                      master && !_changingMaster ? _sendTestNotification : null,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Invia notifica di prova'),
                ),
              ],
            ),
    );
  }
}
