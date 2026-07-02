import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/widgets/tt_global_nav_fab.dart';
import '../data/entities/open_nutrition_catalog_state_entity.dart';
import '../data/providers/open_nutrition_providers.dart';
import '../data/services/open_nutrition_import_service.dart';

class OpenNutritionSettingsScreen extends ConsumerStatefulWidget {
  const OpenNutritionSettingsScreen({super.key});

  @override
  ConsumerState<OpenNutritionSettingsScreen> createState() =>
      _OpenNutritionSettingsScreenState();
}

class _OpenNutritionSettingsScreenState
    extends ConsumerState<OpenNutritionSettingsScreen> {
  OpenNutritionImportProgress? _progress;
  OpenNutritionImportCancellation? _cancellation;
  String _error = '';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final stateValue = ref.watch(openNutritionCatalogStateProvider);
    final countValue = ref.watch(openNutritionCatalogCountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Catalogo OpenNutrition')),
      bottomNavigationBar: const TtFoodBottomNavBar(
        activeItem: TtFoodNavItem.settings,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: <Widget>[
          _IntroCard(),
          const SizedBox(height: 12),
          stateValue.when(
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (error, _) => _ErrorCard(error.toString()),
            data: (state) => _StatusCard(
              state: state,
              count: countValue.when(
                data: (value) => value,
                loading: () => null,
                error: (_, __) => null,
              ),
            ),
          ),
          if (_progress != null || _busy) ...<Widget>[
            const SizedBox(height: 12),
            _ProgressCard(
              progress: _progress,
              onCancel:
                  _cancellation == null ? null : () => _cancellation?.cancel(),
            ),
          ],
          if (_error.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _ErrorCard(_error),
          ],
          const SizedBox(height: 12),
          _ActionsCard(
            busy: _busy,
            onDownload: _download,
            onLocal: _importLocal,
            onRemove: _remove,
          ),
          const SizedBox(height: 12),
          const _LegalCard(),
          const SizedBox(height: 12),
          const _PrivacyCard(),
        ],
      ),
    );
  }

  Future<int?> _acceptLicense() async {
    var accepted = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Licenza e attribuzione'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Il database OpenNutrition è distribuito con ODbL e '
                    'contenuti con una versione modificata della DbCL. '
                    'L’app mostrerà l’attribuzione nei risultati e conserverà '
                    'versione e provenienza nelle copie personali.',
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: accepted,
                    onChanged: (value) =>
                        setDialogState(() => accepted = value ?? false),
                    title: const Text(
                      'Ho letto e accetto l’importazione locale del dataset.',
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed:
                    accepted ? () => Navigator.pop(dialogContext, true) : null,
                child: const Text('Continua'),
              ),
            ],
          ),
        );
      },
    );
    return result == true ? DateTime.now().millisecondsSinceEpoch : null;
  }

  Future<void> _download() async {
    final acceptedAt = await _acceptLicense();
    if (acceptedAt == null) return;
    final cancellation = OpenNutritionImportCancellation();
    await _run(
      cancellation,
      ref.read(openNutritionImportServiceProvider).downloadAndImport(
            licenseAcceptedAtEpochMs: acceptedAt,
            cancellation: cancellation,
          ),
    );
  }

  Future<void> _importLocal() async {
    final acceptedAt = await _acceptLicense();
    if (acceptedAt == null) return;
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
      allowMultiple: false,
    );
    final selectedPath = selected?.files.single.path;
    if (selectedPath == null) return;
    final cancellation = OpenNutritionImportCancellation();
    await _run(
      cancellation,
      ref.read(openNutritionImportServiceProvider).importLocalArchive(
            archiveFile: File(selectedPath),
            licenseAcceptedAtEpochMs: acceptedAt,
            cancellation: cancellation,
          ),
    );
  }

  Future<void> _run(
    OpenNutritionImportCancellation cancellation,
    Stream<OpenNutritionImportProgress> stream,
  ) async {
    setState(() {
      _busy = true;
      _error = '';
      _progress = null;
      _cancellation = cancellation;
    });
    try {
      await for (final progress in stream) {
        if (!mounted) return;
        setState(() => _progress = progress);
      }
      ref.invalidate(openNutritionCatalogStateProvider);
      ref.invalidate(openNutritionCatalogCountProvider);
    } on OpenNutritionImportCancelled {
      if (mounted) setState(() => _error = 'Importazione annullata.');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _cancellation = null;
        });
      }
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rimuovere OpenNutrition?'),
        content: const Text(
          'Il catalogo esterno verrà eliminato. Gli ingredienti già importati '
          'nel cassetto personale resteranno disponibili.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(openNutritionCatalogRepositoryProvider).removeCatalog();
    ref.invalidate(openNutritionCatalogStateProvider);
    ref.invalidate(openNutritionCatalogCountProvider);
  }
}

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Catalogo alimentare offline opzionale',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                'Il download non è incluso nell’installazione. Il catalogo '
                'viene verificato, convertito e salvato in uno store ObjectBox '
                'separato. I tuoi ingredienti hanno sempre priorità.',
              ),
            ],
          ),
        ),
      );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state, required this.count});
  final OpenNutritionCatalogStateEntity state;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final installed =
        state.importStatusCode == OpenNutritionImportStatusCodes.installed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              installed ? 'Catalogo installato' : 'Catalogo non installato',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            _line('Stato', state.importStatusCode),
            _line(
              'Versione',
              state.installedVersion.isEmpty ? '—' : state.installedVersion,
            ),
            _line('Elementi attivi', count?.toString() ?? '—'),
            _line('Checksum', state.actualSha256.isEmpty ? '—' : 'verificato'),
            _line('Righe saltate', state.skippedRows.toString()),
            _line('Righe fallite', state.failedRows.toString()),
            if (state.lastError.isNotEmpty)
              _line('Ultimo errore', state.lastError),
          ],
        ),
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.busy,
    required this.onDownload,
    required this.onLocal,
    required this.onRemove,
  });
  final bool busy;
  final VoidCallback onDownload;
  final VoidCallback onLocal;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              FilledButton.icon(
                onPressed: busy ? null : onDownload,
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Scarica e importa'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: busy ? null : onLocal,
                icon: const Icon(Icons.folder_zip_outlined),
                label: const Text('Importa ZIP locale'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: busy ? null : onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Rimuovi catalogo locale'),
              ),
            ],
          ),
        ),
      );
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress, required this.onCancel});
  final OpenNutritionImportProgress? progress;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final value = progress?.fraction;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(progress?.message ?? 'Preparazione importazione…'),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: value?.clamp(0, 1).toDouble()),
            const SizedBox(height: 12),
            _line('Fase', progress?.stageCode ?? 'preparazione'),
            _line('Righe lette', '${progress?.parsedRows ?? 0}'),
            _line('Importate', '${progress?.importedRows ?? 0}'),
            _line('Ignorate', '${progress?.skippedRows ?? 0}'),
            _line('Fallite', '${progress?.failedRows ?? 0}'),
            if (onCancel != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onCancel,
                  child: const Text('Annulla'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegalCard extends StatelessWidget {
  const _LegalCard();
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Attribuzione e licenze',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Dati forniti da OpenNutrition. Database con licenza ODbL; '
                'contenuti con versione modificata della DbCL. Alcune voci '
                'derivano da © Open Food Facts contributors.',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () => _launchLegalUrl(
                        context, 'https://www.opennutrition.app'),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Apri OpenNutrition'),
                  ),
                  TextButton.icon(
                    onPressed: () => _launchLegalUrl(
                        context, 'https://world.openfoodfacts.org'),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Apri Open Food Facts'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        const ClipboardData(
                            text: 'https://www.opennutrition.app'),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link OpenNutrition copiato.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copia link'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Text(
                'Privacy e pubblicazione',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                'Il catalogo viene scaricato dal server OpenNutrition e '
                'conservato sul dispositivo. Questa schermata non invia dati '
                'nutrizionali personali. La dichiarazione Data Safety deve '
                'comunque riflettere tutte le altre funzioni e gli SDK presenti '
                'nell’app. L’app fornisce stime informative e non diagnosi o '
                'consigli medici.',
              ),
            ],
          ),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
      );
}

Widget _line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 125, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );

Future<void> _launchLegalUrl(BuildContext context, String value) async {
  final opened = await launchUrl(
    Uri.parse(value),
    mode: LaunchMode.externalApplication,
  );
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impossibile aprire il collegamento.')),
    );
  }
}
