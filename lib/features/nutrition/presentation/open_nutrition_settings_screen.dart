import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/background/background_tasks.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/preferences/food_service_preferences.dart';
import '../data/providers/open_nutrition_providers.dart';

class OpenNutritionSettingsScreen extends ConsumerStatefulWidget {
  const OpenNutritionSettingsScreen({super.key});

  @override
  ConsumerState<OpenNutritionSettingsScreen> createState() =>
      _OpenNutritionSettingsScreenState();
}

class _OpenNutritionSettingsScreenState
    extends ConsumerState<OpenNutritionSettingsScreen> {
  bool _licenseAccepted = false;
  Timer? _poller;
  OpenNutritionBackgroundJobState? _job;
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  void initState() {
    super.initState();
    _refreshJob();
    _poller = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshJob(),
    );
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _refreshJob() async {
    final OpenNutritionBackgroundJobState value =
        await OpenNutritionBackgroundJobs.readState();
    if (!mounted) return;

    final bool wasRunning = _job?.isRunning ?? false;
    setState(() => _job = value);

    if (wasRunning && !value.isRunning) {
      ref.invalidate(openNutritionCatalogRepositoryProvider);
      ref.invalidate(openNutritionCatalogDatabaseProvider);
      ref.invalidate(openNutritionCatalogStateProvider);
      ref.invalidate(openNutritionCatalogCountProvider);
    }
  }

  Future<bool> _ensureProgressNotifications() async {
    final FoodServicePreferencesController preferences =
        ref.read(foodServicePreferencesProvider);
    if (!preferences.notificationsEnabled) {
      final bool granted = await LocalNotificationService.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Abilita il permesso notifiche per avviare '
                'l’importazione in background.',
              ),
            ),
          );
        }
        return false;
      }
      await preferences.setNotificationsEnabled(true);
    }
    if (!preferences.backgroundOperationsEnabled) {
      await preferences.setBackgroundOperationsEnabled(true);
    }
    return true;
  }

  Future<void> _startDownload() async {
    if (!_licenseAccepted) return;
    if (!await _ensureProgressNotifications()) return;
    ref.read(openNutritionCatalogDatabaseProvider).close();
    await OpenNutritionBackgroundJobs.enqueueDownload(
      licenseAcceptedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _refreshJob();
  }

  Future<void> _startLocalImport() async {
    if (!_licenseAccepted) return;

    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
    );
    final String? selectedPath = result?.files.single.path;
    if (selectedPath == null) return;

    if (!await _ensureProgressNotifications()) return;
    ref.read(openNutritionCatalogDatabaseProvider).close();
    await OpenNutritionBackgroundJobs.enqueueLocalArchive(
      sourceFile: File(selectedPath),
      licenseAcceptedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _refreshJob();
  }

  String _formatEpoch(int epoch) {
    if (epoch <= 0) return '—';
    final DateTime value = DateTime.fromMillisecondsSinceEpoch(epoch);
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(openNutritionCatalogStateProvider);
    final count = ref.watch(openNutritionCatalogCountProvider);
    final FoodServicePreferencesController preferences =
        ref.watch(foodServicePreferencesProvider);
    final OpenNutritionBackgroundJobState? job = _job;
    final bool busy = job?.isRunning ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Catalogo OpenNutrition')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          FutureBuilder<PackageInfo>(
            future: _packageInfo,
            builder: (
              BuildContext context,
              AsyncSnapshot<PackageInfo> snapshot,
            ) {
              final PackageInfo? info = snapshot.data;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Versione Total Tracker'),
                  subtitle: Text(
                    info == null
                        ? 'Caricamento…'
                        : '${info.version}+${info.buildNumber}',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              title: const Text('Abilita ricerca OpenNutrition'),
              subtitle: const Text(
                'Richiede che il catalogo locale sia installato.',
              ),
              value: preferences.openNutritionSearchEnabled,
              onChanged: preferences.loading
                  ? null
                  : preferences.setOpenNutritionSearchEnabled,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: state.when(
                data: (value) => Text(
                  'Dataset: ${value.installedVersion.isEmpty ? "non installato" : value.installedVersion}\n'
                  'Stato: ${value.importStatusCode}\n'
                  'Record attivi: ${count.asData?.value ?? value.importedRows}',
                ),
                loading: () => const LinearProgressIndicator(),
                error: (Object error, StackTrace stack) =>
                    Text(error.toString()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _licenseAccepted,
            onChanged: busy
                ? null
                : (bool? value) {
                    setState(
                      () => _licenseAccepted = value ?? false,
                    );
                  },
            title: const Text(
              'Accetto licenze e attribuzioni del dataset',
            ),
            subtitle: const Text('ODbL 1.0 / modified DbCL 1.0.'),
          ),
          FilledButton.icon(
            onPressed: busy || !_licenseAccepted ? null : _startDownload,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Scarica e importa in background'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy || !_licenseAccepted ? null : _startLocalImport,
            icon: const Icon(Icons.folder_zip_outlined),
            label: const Text('Importa ZIP locale in background'),
          ),
          if (job != null && job.status != 'idle') ...<Widget>[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${job.percent}% · '
                      '${OpenNutritionBackgroundJobs.stageLabel(job.stage)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: job.fraction == null
                          ? null
                          : job.fraction!.clamp(0.0, 1.0).toDouble(),
                    ),
                    const SizedBox(height: 8),
                    Text(job.message),
                    const SizedBox(height: 8),
                    Text(
                      'Stato: ${job.status}\n'
                      'Versione app del job: '
                      '${job.appVersion.isEmpty ? "—" : job.appVersion}\n'
                      'Accodato: ${_formatEpoch(job.queuedAtEpochMs)}\n'
                      'Avviato: ${_formatEpoch(job.startedAtEpochMs)}\n'
                      'Ultimo aggiornamento: '
                      '${_formatEpoch(job.heartbeatAtEpochMs)}\n'
                      'Letti ${job.parsedRows} · '
                      'Importati ${job.importedRows} · '
                      'Scartati ${job.skippedRows} · '
                      'Falliti ${job.failedRows}',
                    ),
                    if (busy)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            await OpenNutritionBackgroundJobs.cancel();
                            await _refreshJob();
                          },
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Annulla'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    await ref
                        .read(openNutritionCatalogRepositoryProvider)
                        .removeCatalog();
                    ref.invalidate(openNutritionCatalogStateProvider);
                    ref.invalidate(openNutritionCatalogCountProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Catalogo rimosso.'),
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Rimuovi catalogo'),
          ),
        ],
      ),
    );
  }
}
