import 'package:flutter/material.dart';

import '../../../core/notifications/local_notification_service.dart';
import '../../../core/platform/device_permission_service.dart';
import '../../../shared/widgets/tt_global_nav_fab.dart';

class DevicePermissionsScreen extends StatefulWidget {
  const DevicePermissionsScreen({super.key});

  @override
  State<DevicePermissionsScreen> createState() =>
      _DevicePermissionsScreenState();
}

class _DevicePermissionsScreenState extends State<DevicePermissionsScreen>
    with WidgetsBindingObserver {
  DevicePermissionSnapshot? _snapshot;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    try {
      await LocalNotificationService.initialize();
      final DevicePermissionSnapshot snapshot =
          await DevicePermissionService.readStatus();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  Future<void> _run(
    Future<void> Function() operation, {
    String? successMessage,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
      await _refresh();
      if (!mounted || successMessage == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Operazione non riuscita: $error'),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DevicePermissionSnapshot? snapshot = _snapshot;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permessi dispositivo'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Aggiorna stato',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      bottomNavigationBar: const TtFoodBottomNavBar(
        activeItem: TtFoodNavItem.settings,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          if (_busy || snapshot == null) const LinearProgressIndicator(),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('Impossibile leggere i permessi'),
                subtitle: Text('$_error'),
                trailing: IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _PermissionCard(
            icon: Icons.notifications_active_outlined,
            title: 'Notifiche',
            status: snapshot == null
                ? 'Verifica in corso…'
                : snapshot.notificationOperational
                    ? 'Consentite e abilitate da Android'
                    : !snapshot.notificationRuntimeGranted
                        ? 'Permesso Android non concesso'
                        : 'Disabilitate nelle impostazioni di sistema',
            granted: snapshot?.notificationOperational ?? false,
            description: snapshot == null
                ? 'Necessarie per promemoria e avanzamento delle operazioni in background.'
                : 'Canale promemoria: '
                    '${snapshot.reminderChannelEnabled ? "attivo" : "disattivato"}. '
                    'Canale operazioni in background: '
                    '${snapshot.backgroundChannelEnabled ? "attivo" : "disattivato"}.',
            actions: <Widget>[
              FilledButton.tonalIcon(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          await LocalNotificationService.initialize();
                          await DevicePermissionService.requestNotifications();
                        }),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Richiedi permesso'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          await DevicePermissionService
                              .openNotificationSettings();
                        }),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Impostazioni notifiche'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ||
                        snapshot == null ||
                        !snapshot.reminderNotificationsOperational
                    ? null
                    : () => _run(
                          LocalNotificationService.showTestNotification,
                          successMessage: 'Notifica di prova inviata.',
                        ),
                icon: const Icon(Icons.notification_add_outlined),
                label: const Text('Invia prova'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PermissionCard(
            icon: Icons.photo_camera_outlined,
            title: 'Fotocamera',
            status: snapshot == null
                ? 'Verifica in corso…'
                : snapshot.cameraGranted
                    ? 'Consentita'
                    : 'Non consentita',
            granted: snapshot?.cameraGranted ?? false,
            description:
                'Usata esclusivamente per leggere barcode e acquisire immagini richieste dall’utente.',
            actions: <Widget>[
              FilledButton.tonalIcon(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          await DevicePermissionService.requestCamera();
                        }),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Richiedi permesso'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          await DevicePermissionService.openAppSettings();
                        }),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Impostazioni app'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PermissionCard(
            icon: Icons.battery_saver_outlined,
            title: 'Esecuzione in background',
            status: snapshot == null
                ? 'Verifica in corso…'
                : snapshot.batteryOptimizationIgnored
                    ? 'App esclusa dall’ottimizzazione batteria'
                    : 'Ottimizzazione batteria attiva',
            granted: snapshot?.batteryOptimizationIgnored ?? false,
            description:
                'Android e alcuni produttori possono ritardare download, importazioni e promemoria. '
                'L’app non forza alcuna esclusione: la scelta resta nelle impostazioni del dispositivo.',
            actions: <Widget>[
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          await DevicePermissionService
                              .openBatteryOptimizationSettings();
                        }),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Ottimizzazione batteria'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.android_outlined),
              title: const Text('Informazioni Android'),
              subtitle: Text(
                snapshot == null
                    ? 'Caricamento…'
                    : 'API ${snapshot.androidSdkInt}. Lo stato viene riletto '
                        'automaticamente quando torni nell’app.',
              ),
              trailing: const Icon(Icons.info_outline),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.granted,
    required this.description,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String status;
  final bool granted;
  final String description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Icon(
                  granted ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: granted ? colors.primary : colors.error,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              status,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: granted ? colors.primary : colors.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}
