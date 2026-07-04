import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/background/background_tasks.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/platform/device_permission_service.dart';
import '../../../core/preferences/food_service_preferences.dart';
import '../data/config/open_nutrition_rollout_config.dart';
import '../data/providers/open_nutrition_providers.dart';
import '../data/services/open_nutrition_gateway_service.dart';
import '../data/services/open_nutrition_static_index_service.dart';
import '../data/services/open_nutrition_translation_service.dart';

class OpenNutritionSettingsScreen extends ConsumerStatefulWidget {
  const OpenNutritionSettingsScreen({super.key});

  @override
  ConsumerState<OpenNutritionSettingsScreen> createState() =>
      _OpenNutritionSettingsScreenState();
}

class _OpenNutritionSettingsScreenState
    extends ConsumerState<OpenNutritionSettingsScreen> {
  bool _licenseAccepted = false;
  bool _resetting = false;
  bool _testingGateway = false;
  bool _startingJob = false;
  Timer? _poller;
  OpenNutritionBackgroundJobState? _job;
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  void initState() {
    super.initState();
    if (OpenNutritionRolloutConfig.legacyLocalCatalogEnabled) {
      _refreshJob();
      _poller = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _refreshJob(),
      );
    }
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _refreshJob() async {
    if (!OpenNutritionRolloutConfig.legacyLocalCatalogEnabled) return;
    final OpenNutritionBackgroundJobState value =
        await OpenNutritionBackgroundJobs.reconcileCachedState();
    if (!mounted) return;

    final bool wasRunning = _job?.isRunning ?? false;
    setState(() => _job = value);

    if (wasRunning && !value.isRunning) {
      _invalidateCatalogProviders();
    }
  }

  void _invalidateCatalogProviders() {
    ref.invalidate(openNutritionCatalogRepositoryProvider);
    ref.invalidate(openNutritionCatalogDatabaseProvider);
    ref.invalidate(openNutritionCatalogStateProvider);
    ref.invalidate(openNutritionCatalogCountProvider);
  }

  Future<bool> _ensureProgressNotifications() async {
    final FoodServicePreferencesController preferences =
        ref.read(foodServicePreferencesProvider);
    if (!preferences.notificationsEnabled) {
      await preferences.setNotificationsEnabled(true);
    }
    if (!preferences.backgroundOperationsEnabled) {
      await preferences.setBackgroundOperationsEnabled(true);
    }

    bool operational = true;
    try {
      await LocalNotificationService.initialize();
      DevicePermissionSnapshot status =
          await DevicePermissionService.readStatus();
      if (!status.notificationRuntimeGranted) {
        await DevicePermissionService.requestNotifications();
        status = await DevicePermissionService.readStatus();
      }
      operational = status.backgroundNotificationsOperational;
    } catch (_) {
      operational = false;
    }

    if (!operational && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'L’importazione può partire, ma Android non consente le '
            'notifiche. Verifica i permessi del dispositivo.',
          ),
          action: SnackBarAction(
            label: 'APRI',
            onPressed: () {
              DevicePermissionService.openNotificationSettings();
            },
          ),
          duration: const Duration(seconds: 7),
        ),
      );
    }
    return operational;
  }

  Future<void> _prepareCatalogDatabaseForWorker() async {
    try {
      ref.read(openNutritionCatalogDatabaseProvider).close();
    } catch (_) {
      // Il provider può essere già stato eliminato da autoDispose.
    }
    ref.invalidate(openNutritionCatalogRepositoryProvider);
    ref.invalidate(openNutritionCatalogDatabaseProvider);
    ref.invalidate(openNutritionCatalogStateProvider);
    ref.invalidate(openNutritionCatalogCountProvider);
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  Future<void> _startDownload() async {
    if (!_licenseAccepted || _startingJob) return;
    setState(() => _startingJob = true);
    try {
      await _ensureProgressNotifications();
      await _prepareCatalogDatabaseForWorker();
      await OpenNutritionBackgroundJobs.enqueueDownload(
        licenseAcceptedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      );
      await _refreshJob();
    } catch (error) {
      await _showStartError(error);
    } finally {
      if (mounted) setState(() => _startingJob = false);
    }
  }

  Future<void> _startLocalImport() async {
    if (!_licenseAccepted || _startingJob) return;

    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: false,
      withReadStream: true,
    );
    if (result == null || result.files.isEmpty) return;

    final PlatformFile selected = result.files.single;
    if (!selected.name.toLowerCase().endsWith('.zip')) {
      await _showStartError(
        StateError('Seleziona l’archivio ZIP ufficiale di OpenNutrition.'),
      );
      return;
    }

    setState(() => _startingJob = true);
    try {
      await _ensureProgressNotifications();
      await _prepareCatalogDatabaseForWorker();

      final String? selectedPath = selected.path;
      final File? selectedFile =
          selectedPath == null ? null : File(selectedPath);
      if (selectedFile != null && await selectedFile.exists()) {
        await OpenNutritionBackgroundJobs.enqueueLocalArchive(
          sourceFile: selectedFile,
          licenseAcceptedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        );
      } else {
        final Stream<List<int>>? stream = selected.readStream;
        if (stream == null) {
          throw StateError(
            'Android non ha fornito un percorso o uno stream leggibile per '
            'l’archivio selezionato.',
          );
        }
        await OpenNutritionBackgroundJobs.enqueueLocalArchiveStream(
          source: stream,
          declaredBytes: selected.size,
          licenseAcceptedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        );
      }
      await _refreshJob();
    } catch (error) {
      await _showStartError(error);
    } finally {
      if (mounted) setState(() => _startingJob = false);
    }
  }

  Future<void> _showStartError(Object error) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Importazione non avviata'),
          content: SelectableText(error.toString()),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Chiudi'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetPendingOperation({
    bool showMessage = true,
  }) async {
    if (_resetting) return;
    setState(() => _resetting = true);
    try {
      await OpenNutritionBackgroundJobs.cancelAndReset(
        deletePendingArchives: true,
      );
      _invalidateCatalogProviders();
      await Future<void>.delayed(Duration.zero);
      await _refreshJob();
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Coda, stato memorizzato e archivi temporanei ripuliti.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  Future<void> _removeCatalog() async {
    if (_resetting) return;
    setState(() => _resetting = true);
    try {
      await OpenNutritionBackgroundJobs.cancelAndReset(
        deletePendingArchives: true,
      );

      try {
        ref.read(openNutritionCatalogDatabaseProvider).close();
      } catch (_) {
        // Il repository successivo verrà ricreato comunque.
      }
      _invalidateCatalogProviders();
      await Future<void>.delayed(Duration.zero);

      await ref.read(openNutritionCatalogRepositoryProvider).removeCatalog();
      _invalidateCatalogProviders();
      await _refreshJob();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Catalogo e stato importazione rimossi.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  Future<void> _configureGateway() async {
    if (!OpenNutritionGatewayConfig.allowsRuntimeConfiguration) return;

    final List<String> gatewayValues = await Future.wait<String>(
      <Future<String>>[
        FoodServicePreferences.getString(
          FoodServicePreferenceKeys.openNutritionGatewayUrl,
        ),
        FoodServicePreferences.getString(
          FoodServicePreferenceKeys.openNutritionGatewayPublicKey,
        ),
        FoodServicePreferences.getString(
          FoodServicePreferenceKeys.openNutritionGatewayKeyId,
        ),
      ],
    );
    if (!mounted) return;

    final TextEditingController url = TextEditingController(
      text: gatewayValues[0],
    );
    final TextEditingController publicKey = TextEditingController(
      text: gatewayValues[1],
    );
    final TextEditingController keyId = TextEditingController(
      text: gatewayValues[2],
    );

    try {
      final bool? save = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          String? error;
          return StatefulBuilder(
            builder: (
              BuildContext context,
              StateSetter setDialogState,
            ) {
              return AlertDialog(
                title: const Text('Gateway OpenNutrition sicuro'),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          'Inserisci l’URL HTTPS del gateway e la sua chiave '
                          'pubblica Ed25519. I dati vengono accettati soltanto '
                          'se la firma della risposta è valida.',
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: url,
                          decoration: const InputDecoration(
                            labelText: 'Base URL HTTPS',
                            hintText: 'https://nutrition.example.com',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: publicKey,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Chiave pubblica Ed25519 in Base64',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: keyId,
                          decoration: const InputDecoration(
                            labelText: 'Key ID',
                            hintText: 'primary',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (error != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Annulla'),
                  ),
                  FilledButton(
                    onPressed: () {
                      try {
                        OpenNutritionGatewayConfig.validate(
                          rawUrl: url.text,
                          rawPublicKey: publicKey.text,
                          rawKeyId: keyId.text,
                        );
                        Navigator.pop(dialogContext, true);
                      } catch (validationError) {
                        setDialogState(
                          () => error = validationError.toString(),
                        );
                      }
                    },
                    child: const Text('Salva'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (save != true) return;
      await Future.wait(<Future<void>>[
        FoodServicePreferences.setString(
          FoodServicePreferenceKeys.openNutritionGatewayUrl,
          url.text.trim(),
        ),
        FoodServicePreferences.setString(
          FoodServicePreferenceKeys.openNutritionGatewayPublicKey,
          publicKey.text.trim(),
        ),
        FoodServicePreferences.setString(
          FoodServicePreferenceKeys.openNutritionGatewayKeyId,
          keyId.text.trim().isEmpty ? 'primary' : keyId.text.trim(),
        ),
      ]);
      ref.invalidate(openNutritionGatewayServiceProvider);
      ref.invalidate(openNutritionGatewayConfiguredProvider);
      if (mounted) setState(() {});
    } finally {
      url.dispose();
      publicKey.dispose();
      keyId.dispose();
    }
  }

  Future<void> _testGateway() async {
    if (_testingGateway) return;
    setState(() => _testingGateway = true);
    try {
      ref.invalidate(openNutritionGatewayServiceProvider);
      final String datasetVersion =
          await ref.read(openNutritionGatewayServiceProvider).healthCheck();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gateway verificato. Dataset: $datasetVersion.',
          ),
        ),
      );
      ref.invalidate(openNutritionGatewayConfiguredProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _testingGateway = false);
    }
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
    final bool legacyCatalogEnabled =
        OpenNutritionRolloutConfig.legacyLocalCatalogEnabled;
    final bool legacyGatewayEnabled =
        OpenNutritionRolloutConfig.legacyGatewayEnabled;
    final OpenNutritionBackgroundJobState? job = _job;
    final bool busy =
        legacyCatalogEnabled && (_startingJob || (job?.isRunning ?? false));
    final state = legacyCatalogEnabled && !busy
        ? ref.watch(openNutritionCatalogStateProvider)
        : null;
    final count = legacyCatalogEnabled && !busy
        ? ref.watch(openNutritionCatalogCountProvider)
        : null;
    final AsyncValue<bool>? gatewayConfigured = legacyGatewayEnabled
        ? ref.watch(openNutritionGatewayConfiguredProvider)
        : null;
    final AsyncValue<OpenNutritionStaticIndexStatus>? staticIndexStatus =
        OpenNutritionRolloutConfig.staticIndexConfigured
            ? ref.watch(openNutritionStaticIndexStatusProvider)
            : null;
    final AsyncValue<OpenNutritionTranslationStatus>? translationStatus =
        OpenNutritionRolloutConfig.staticIndexConfigured
            ? ref.watch(openNutritionTranslationStatusProvider)
            : null;
    final FoodServicePreferencesController preferences =
        ref.watch(foodServicePreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('OpenNutrition')),
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
                'Usa OpenNutrition come fonte complementare. Gli alimenti '
                'già importati restano disponibili anche se la ricerca è '
                'disabilitata.',
              ),
              value: preferences.openNutritionSearchEnabled,
              onChanged: preferences.loading
                  ? null
                  : preferences.setOpenNutritionSearchEnabled,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: staticIndexStatus == null
                ? const ListTile(
                    leading: Icon(Icons.cloud_off_outlined),
                    title: Text('Indice statico non configurato'),
                    subtitle: Text(
                      'Il client sicuro è presente, ma la build non contiene '
                      'ancora URL CDN e hash del manifest. Catalogo completo e '
                      'gateway legacy restano disabilitati.',
                    ),
                  )
                : staticIndexStatus.when(
                    data: (OpenNutritionStaticIndexStatus status) {
                      return ListTile(
                        leading: const Icon(Icons.cloud_done_outlined),
                        title: Text(
                          'Indice statico ${status.datasetVersion}',
                        ),
                        subtitle: Text(
                          '${status.recordCount} record · '
                          '${status.shardCount} shard · '
                          '${status.cachedShardCount} shard in cache. '
                          'Manifest e shard sono verificati tramite SHA-256.',
                        ),
                        trailing: IconButton(
                          tooltip: 'Aggiorna stato',
                          onPressed: () {
                            ref.invalidate(
                              openNutritionStaticIndexStatusProvider,
                            );
                          },
                          icon: const Icon(Icons.refresh),
                        ),
                      );
                    },
                    loading: () => const ListTile(
                      leading: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      title: Text('Verifica indice statico…'),
                      subtitle: Text(
                        'Controllo manifest, schema e cache locale.',
                      ),
                    ),
                    error: (Object error, StackTrace _) => ListTile(
                      leading: const Icon(Icons.cloud_off_outlined),
                      title: const Text('Indice statico non disponibile'),
                      subtitle: Text(error.toString()),
                      trailing: IconButton(
                        tooltip: 'Riprova',
                        onPressed: () {
                          ref.invalidate(
                            openNutritionStaticIndexStatusProvider,
                          );
                        },
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                  ),
          ),
          if (translationStatus != null) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              child: translationStatus.when(
                data: (OpenNutritionTranslationStatus status) {
                  final String subtitle;
                  if (!status.platformSupported) {
                    subtitle =
                        'Traduzione non disponibile su questa piattaforma.';
                  } else if (!status.localeSupported) {
                    subtitle =
                        'Lingua ${status.localeCode} non supportata da ML Kit.';
                  } else if (!status.translationRequired) {
                    subtitle =
                        'Lingua dispositivo inglese: traduzione non necessaria.';
                  } else if (status.ready) {
                    subtitle =
                        'Modelli inglese e ${status.localeCode} disponibili. '
                        'Query e nomi vengono tradotti sul dispositivo.';
                  } else {
                    subtitle =
                        'I modelli inglese e ${status.localeCode} verranno '
                        'scaricati automaticamente al primo utilizzo, solo '
                        'tramite Wi-Fi.';
                  }

                  return ListTile(
                    leading: Icon(
                      status.ready
                          ? Icons.translate
                          : Icons.downloading_outlined,
                    ),
                    title: const Text('Traduzione automatica on-device'),
                    subtitle: Text(
                      '$subtitle Le traduzioni automatiche possono contenere '
                      'errori e non hanno garanzie di accuratezza.',
                    ),
                    trailing: IconButton(
                      tooltip: 'Informazioni su Google Translate',
                      onPressed: () {
                        launchUrl(
                          Uri.parse('https://translate.google.com/'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      icon: const Icon(Icons.open_in_new),
                    ),
                  );
                },
                loading: () => const ListTile(
                  leading: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  title: Text('Verifica modelli di traduzione…'),
                  subtitle: Text(
                    'La traduzione dei testi avviene sul dispositivo.',
                  ),
                ),
                error: (Object error, StackTrace _) => ListTile(
                  leading: const Icon(Icons.translate_outlined),
                  title: const Text('Stato traduzione non disponibile'),
                  subtitle: Text(error.toString()),
                  trailing: IconButton(
                    tooltip: 'Riprova',
                    onPressed: () {
                      ref.invalidate(
                        openNutritionTranslationStatusProvider,
                      );
                    },
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ),
            ),
          ],
          if (legacyGatewayEnabled) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    title: const Text('Gateway legacy di sviluppo'),
                    subtitle: const Text(
                      'Connettore temporaneo escluso dalla configurazione '
                      'predefinita di produzione.',
                    ),
                    value: preferences.openNutritionRemoteEnabled,
                    onChanged: preferences.loading
                        ? null
                        : (bool value) async {
                            await preferences
                                .setOpenNutritionRemoteEnabled(value);
                            ref.invalidate(
                              openNutritionGatewayConfiguredProvider,
                            );
                          },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      gatewayConfigured?.asData?.value == true
                          ? Icons.verified_user
                          : Icons.gpp_maybe_outlined,
                    ),
                    title: Text(
                      gatewayConfigured?.when(
                            data: (bool configured) => configured
                                ? 'Gateway configurato'
                                : 'Gateway non configurato',
                            loading: () => 'Verifica configurazione…',
                            error: (_, __) =>
                                'Configurazione gateway non valida',
                          ) ??
                          'Gateway disabilitato',
                    ),
                    subtitle: const Text(
                      'HTTPS obbligatorio, risposta limitata e firmata '
                      'Ed25519.',
                    ),
                  ),
                  if (OpenNutritionGatewayConfig.allowsRuntimeConfiguration)
                    ListTile(
                      leading: const Icon(Icons.tune_outlined),
                      title: const Text('Configura gateway'),
                      onTap: _configureGateway,
                    ),
                  ListTile(
                    enabled: gatewayConfigured?.asData?.value == true &&
                        !_testingGateway,
                    leading: _testingGateway
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.security_outlined),
                    title: const Text('Testa firma e connessione'),
                    onTap: _testGateway,
                  ),
                ],
              ),
            ),
          ],
          if (legacyCatalogEnabled) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: state == null
                    ? const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Database catalogo riservato al worker',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 8),
                          LinearProgressIndicator(),
                          SizedBox(height: 8),
                          Text(
                            'Durante download e importazione la UI non riapre '
                            'ObjectBox, evitando conflitti tra isolate.',
                          ),
                        ],
                      )
                    : state.when(
                        data: (value) => Text(
                          'Dataset locale: '
                          '${value.installedVersion.isEmpty ? "non installato" : value.installedVersion}\n'
                          'Stato: ${value.importStatusCode}\n'
                          'Record attivi: '
                          '${count?.asData?.value ?? value.importedRows}',
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (Object error, StackTrace stack) =>
                            SelectableText(error.toString()),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _licenseAccepted,
              onChanged: busy || _resetting
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
              onPressed: busy || _resetting || !_licenseAccepted
                  ? null
                  : _startDownload,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Scarica e importa in background'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy || _resetting || !_licenseAccepted
                  ? null
                  : _startLocalImport,
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
                        value: job.fraction?.clamp(0.0, 1.0).toDouble(),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(job.message),
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
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _resetting ? null : _resetPendingOperation,
              icon: _resetting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cleaning_services_outlined),
              label: const Text('Azzera coda e stato importazione'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _resetting ? null : _removeCatalog,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Rimuovi catalogo e resetta importazione'),
            ),
          ],
        ],
      ),
    );
  }
}
