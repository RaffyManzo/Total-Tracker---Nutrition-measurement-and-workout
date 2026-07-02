import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/background/background_tasks.dart';
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

  @override
  void initState() {
    super.initState();
    _refreshJob();
    _poller = Timer.periodic(const Duration(seconds: 1), (_) => _refreshJob());
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _refreshJob() async {
    final value = await OpenNutritionBackgroundJobs.readState();
    if (!mounted) return;
    final wasRunning = _job?.isRunning ?? false;
    setState(() => _job = value);
    if (wasRunning && !value.isRunning) {
      ref.invalidate(openNutritionCatalogRepositoryProvider);
      ref.invalidate(openNutritionCatalogDatabaseProvider);
      ref.invalidate(openNutritionCatalogStateProvider);
      ref.invalidate(openNutritionCatalogCountProvider);
    }
  }

  Future<void> _startDownload() async {
    if (!_licenseAccepted) return;
    ref.read(openNutritionCatalogDatabaseProvider).close();
    await OpenNutritionBackgroundJobs.enqueueDownload(
      licenseAcceptedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _refreshJob();
  }

  Future<void> _startLocalImport() async {
    if (!_licenseAccepted) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
    );
    final selectedPath = result?.files.single.path;
    if (selectedPath == null) return;
    ref.read(openNutritionCatalogDatabaseProvider).close();
    await OpenNutritionBackgroundJobs.enqueueLocalArchive(
      sourceFile: File(selectedPath),
      licenseAcceptedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _refreshJob();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(openNutritionCatalogStateProvider);
    final count = ref.watch(openNutritionCatalogCountProvider);
    final preferences = ref.watch(foodServicePreferencesProvider);
    final job = _job;
    final busy = job?.isRunning ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Catalogo OpenNutrition')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: SwitchListTile(
              title: const Text('Abilita ricerca OpenNutrition'),
              subtitle: const Text(
                'Di default attiva. Richiede che il catalogo locale sia installato.',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Stato catalogo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  state.when(
                    data: (value) => Text(
                      'Versione: ${value.installedVersion.isEmpty ? "non installata" : value.installedVersion}\n'
                      'Stato: ${value.importStatusCode}\n'
                      'Record: ${count.asData?.value ?? value.importedRows}',
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (Object error, StackTrace stack) => Text('$error'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _licenseAccepted,
            onChanged: busy
                ? null
                : (bool? value) =>
                    setState(() => _licenseAccepted = value ?? false),
            title: const Text('Accetto licenze e attribuzioni del dataset'),
            subtitle: const Text('ODbL 1.0 / modified DbCL 1.0.'),
          ),
          const SizedBox(height: 8),
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
                      job.message,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (job.fraction != null)
                      LinearProgressIndicator(value: job.fraction),
                    const SizedBox(height: 8),
                    Text(
                      'Stato: ${job.status} · Fase: ${job.stage}\n'
                      'Letti ${job.parsedRows} · Importati ${job.importedRows} · '
                      'Scartati ${job.skippedRows} · Falliti ${job.failedRows}',
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
                        const SnackBar(content: Text('Catalogo rimosso.')),
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
