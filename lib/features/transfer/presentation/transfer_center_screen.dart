import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/objectbox_providers.dart';
import '../../../shared/widgets/tt_app_card.dart';
import '../../../shared/widgets/tt_section_header.dart';
import '../../profile/data/entities/user_profile_entity.dart';
import '../data/recipe_media_sidecar_importer.dart';
import '../domain/transfer_models.dart';

class TransferCenterScreen extends ConsumerStatefulWidget {
  const TransferCenterScreen({super.key});

  @override
  ConsumerState<TransferCenterScreen> createState() =>
      _TransferCenterScreenState();
}

class _TransferCenterScreenState extends ConsumerState<TransferCenterScreen> {
  bool _includeProfile = true;
  bool _includeFood = true;
  bool _includeWorkout = true;
  bool _busy = false;
  String? _status;
  double? _busyProgress;
  String _busyMessage = 'Operazione in corso...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureExportFolder());
  }

  Future<void> _ensureExportFolder() async {
    final repository = ref.read(userProfileRepositoryProvider);
    final UserProfileEntity profile = repository.getActiveProfile() ??
        repository.createDefaultProfileIfMissing();
    if (profile.exportFolderPath.trim().isNotEmpty) {
      return;
    }
    final String path = await ref
        .read(totalTrackerTransferServiceProvider)
        .resolveDefaultExportDirectory();
    if (!mounted) return;
    profile.exportFolderPath = path;
    repository.save(profile);
    ref.invalidate(profileSettingsRevisionProvider);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(profileSettingsRevisionProvider);
    final repository = ref.watch(userProfileRepositoryProvider);
    final UserProfileEntity profile = repository.getActiveProfile() ??
        repository.createDefaultProfileIfMissing();
    final String folder = profile.exportFolderPath.trim().isEmpty
        ? 'Download/Total Tracker (predefinita)'
        : profile.exportFolderPath;

    return Scaffold(
      appBar: AppBar(title: const Text('Importazione ed esportazione')),
      body: Stack(
        children: <Widget>[
          ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            children: <Widget>[
              Text(
                'Archivio Total Tracker',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Il formato .totaltracker è un archivio portabile: prima '
                'dell importazione viene analizzato senza modificare ObjectBox.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              const TtSectionHeader(title: 'Cartella di esportazione'),
              const SizedBox(height: AppSpacing.md),
              TtAppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.folder_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Export Folder',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SelectableText(
                      folder,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _busy ? null : () => _pickFolder(profile),
                            icon:
                                const Icon(Icons.drive_folder_upload_outlined),
                            label: const Text('Cambia cartella'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TextButton(
                            onPressed:
                                _busy ? null : () => _resetFolder(profile),
                            child: const Text('Ripristina Download'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              const TtSectionHeader(title: 'Contenuto dell export'),
              const SizedBox(height: AppSpacing.md),
              _AreaTile(
                title: 'Profilo e impostazioni',
                subtitle:
                    'Dati personali, target e configurazioni. Il percorso locale non viene esportato.',
                icon: Icons.person_outline_rounded,
                value: _includeProfile,
                onChanged: (bool value) =>
                    setState(() => _includeProfile = value),
              ),
              const SizedBox(height: AppSpacing.sm),
              _AreaTile(
                title: 'Alimentazione e misurazioni',
                subtitle:
                    'Ingredienti, ricette, giornate, pasti, bilancia e metro.',
                icon: Icons.restaurant_menu_rounded,
                value: _includeFood,
                onChanged: (bool value) => setState(() => _includeFood = value),
              ),
              const SizedBox(height: AppSpacing.sm),
              _AreaTile(
                title: 'Allenamento',
                subtitle:
                    'Muscoli, esercizi, routine, schede e sessioni complete.',
                icon: Icons.fitness_center_rounded,
                value: _includeWorkout,
                onChanged: (bool value) =>
                    setState(() => _includeWorkout = value),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _export(profile),
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Esporta archivio'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _pickAndAnalyzeImport,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Importa file'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickAndImportRecipeMedia,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Importa immagini ricette'),
                ),
              ),
              if (_status != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                TtAppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.info_outline_rounded),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(_status!)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sectionGap),
              TtAppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Flusso di importazione',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      '1. Selezione del file tramite file picker.\n'
                      '2. Verifica formato, versione e checksum.\n'
                      '3. Analisi di categorie e conflitti senza scrittura.\n'
                      '4. Selezione pagina per pagina.\n'
                      '5. Riepilogo e transazione ObjectBox finale.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color:
                    Theme.of(context).colorScheme.scrim.withValues(alpha: 0.42),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: TtAppCard(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            LinearProgressIndicator(value: _busyProgress),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _busyMessage,
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickFolder(UserProfileEntity profile) async {
    final String? selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Seleziona Export Folder',
      initialDirectory: profile.exportFolderPath.trim().isEmpty
          ? null
          : profile.exportFolderPath,
    );
    if (selected == null || !mounted) return;
    final bool writable = await ref
        .read(totalTrackerTransferServiceProvider)
        .isWritableDirectory(selected);
    if (!mounted) return;
    if (!writable) {
      _showError('La cartella selezionata non è scrivibile.');
      return;
    }
    profile.exportFolderPath = selected;
    ref.read(userProfileRepositoryProvider).save(profile);
    ref.invalidate(profileSettingsRevisionProvider);
    setState(() => _status = 'Export Folder aggiornata.');
  }

  Future<void> _resetFolder(UserProfileEntity profile) async {
    setState(() => _busy = true);
    try {
      final String path = await ref
          .read(totalTrackerTransferServiceProvider)
          .resolveDefaultExportDirectory();
      profile.exportFolderPath = path;
      ref.read(userProfileRepositoryProvider).save(profile);
      ref.invalidate(profileSettingsRevisionProvider);
      if (!mounted) return;
      setState(() => _status = 'Cartella predefinita ripristinata.');
    } on Object catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(UserProfileEntity profile) async {
    final TransferExportOptions options = TransferExportOptions(
      includeProfile: _includeProfile,
      includeFood: _includeFood,
      includeWorkout: _includeWorkout,
    );
    if (options.isEmpty) {
      _showError('Seleziona almeno una categoria.');
      return;
    }
    setState(() => _busy = true);
    try {
      String folder = profile.exportFolderPath.trim();
      if (folder.isEmpty) {
        folder = await ref
            .read(totalTrackerTransferServiceProvider)
            .resolveDefaultExportDirectory();
        profile.exportFolderPath = folder;
        ref.read(userProfileRepositoryProvider).save(profile);
      }
      final TransferExportResult result = await ref
          .read(totalTrackerTransferServiceProvider)
          .exportArchive(options: options, directoryPath: folder);
      if (!mounted) return;
      setState(() {
        _status = 'Archivio creato: ${result.path}\n'
            '${result.counts.values.fold<int>(0, (int a, int b) => a + b)} '
            'entità · ${_formatBytes(result.bytes)}';
      });
    } on Object catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndAnalyzeImport() async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Seleziona archivio Total Tracker',
      type: FileType.custom,
      allowedExtensions: const <String>['totaltracker', 'zip'],
      allowMultiple: false,
      withData: false,
    );
    final String? path = picked?.files.single.path;
    if (path == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final TransferImportAnalysis analysis = await ref
          .read(totalTrackerTransferServiceProvider)
          .analyzeImport(path);
      if (!mounted) return;
      final bool? imported = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (BuildContext context) =>
              TransferImportWizardScreen(analysis: analysis),
        ),
      );
      if (!mounted) return;
      if (imported == true) {
        ref.invalidate(profileSettingsRevisionProvider);
        setState(() => _status = 'Importazione completata.');
      }
    } on Object catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndImportRecipeMedia() async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Seleziona pacchetto immagini ricette',
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
      allowMultiple: false,
      withData: false,
    );
    final String? path = picked?.files.single.path;
    if (path == null || !mounted) return;

    setState(() {
      _busy = true;
      _busyProgress = 0;
      _busyMessage = 'Apro il pacchetto immagini...';
    });
    await WidgetsBinding.instance.endOfFrame;

    try {
      final RecipeMediaImportReport report =
          await RecipeMediaSidecarImporter(ref.read(objectBoxStoreProvider))
              .importFile(
        path,
        onProgress: (double progress, String message) {
          if (!mounted) return;
          setState(() {
            _busyProgress = progress;
            _busyMessage = message;
          });
        },
      );
      if (!mounted) return;
      ref.invalidate(recipeRepositoryProvider);
      setState(() => _status = report.summary);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(report.summary)),
      );
    } on Object catch (error) {
      if (mounted) {
        _showError('Importazione immagini non riuscita: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyProgress = null;
          _busyMessage = 'Operazione in corso...';
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class TransferImportWizardScreen extends ConsumerStatefulWidget {
  const TransferImportWizardScreen({
    super.key,
    required this.analysis,
  });

  final TransferImportAnalysis analysis;

  @override
  ConsumerState<TransferImportWizardScreen> createState() =>
      _TransferImportWizardScreenState();
}

class _TransferImportWizardScreenState
    extends ConsumerState<TransferImportWizardScreen> {
  int _page = 0;
  bool _busy = false;

  bool get _isRecap => _page >= widget.analysis.sections.length;

  @override
  Widget build(BuildContext context) {
    final int totalPages = widget.analysis.sections.length + 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRecap
            ? 'Riepilogo importazione'
            : widget.analysis.sections[_page].title),
      ),
      body: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              LinearProgressIndicator(value: (_page + 1) / totalPages),
              Expanded(
                child: _isRecap
                    ? _buildRecap(context)
                    : _buildSection(
                        context,
                        widget.analysis.sections[_page],
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  if (_page == 0) {
                                    Navigator.of(context).pop(false);
                                  } else {
                                    setState(() => _page -= 1);
                                  }
                                },
                          child: Text(_page == 0 ? 'Annulla' : 'Indietro'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : _isRecap
                                  ? _apply
                                  : () => setState(() => _page += 1),
                          icon: Icon(
                            _isRecap
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                          label: Text(_isRecap ? 'Importa' : 'Continua'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    TransferImportSection section,
  ) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Text(section.description),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${section.items.length} elementi · '
                '${section.conflictCount} conflitti',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: () {
                final bool select =
                    section.selectedCount != section.items.length;
                setState(() {
                  for (final TransferImportItem item in section.items) {
                    item.selected = select;
                  }
                });
              },
              child: Text(
                section.selectedCount == section.items.length
                    ? 'Deseleziona tutti'
                    : 'Seleziona tutti',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final TransferImportItem item in section.items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ImportItemCard(
              item: item,
              isProfile: section.isProfileSection,
              onChanged: () => setState(() {}),
            ),
          ),
      ],
    );
  }

  Widget _buildRecap(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Text(
          'Conferma finale',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'La scrittura avverrà in una singola transazione ObjectBox. '
          'Le voci non selezionate o impostate su Mantieni verranno ignorate.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final TransferImportSection section in widget.analysis.sections)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: TtAppCard(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      section.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text('${section.selectedCount}/${section.items.length}'),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        TtAppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('File', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(widget.analysis.sourcePath),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Selezionati: ${widget.analysis.selectedItems} · '
                'Conflitti rilevati: ${widget.analysis.conflicts}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _apply() async {
    if (widget.analysis.selectedItems == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun elemento selezionato.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final TransferImportResult result = ref
          .read(totalTrackerTransferServiceProvider)
          .applyImport(widget.analysis);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Importazione completata'),
          content: Text(
            'Creati: ${result.created}\n'
            'Aggiornati: ${result.updated}\n'
            'Ignorati: ${result.skipped}',
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Chiudi'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Importazione non riuscita: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _AreaTile extends StatelessWidget {
  const _AreaTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      onTap: () => onChanged(!value),
      borderColor: value ? Theme.of(context).colorScheme.primary : null,
      child: Row(
        children: <Widget>[
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Checkbox(value: value, onChanged: (bool? v) => onChanged(v ?? false)),
        ],
      ),
    );
  }
}

class _ImportItemCard extends StatelessWidget {
  const _ImportItemCard({
    required this.item,
    required this.isProfile,
    required this.onChanged,
  });

  final TransferImportItem item;
  final bool isProfile;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      borderColor:
          item.hasConflict ? Theme.of(context).colorScheme.tertiary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Checkbox(
                value: item.selected,
                onChanged: (bool? value) {
                  item.selected = value ?? false;
                  onChanged();
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (item.subtitle.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        item.subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (item.hasConflict) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.conflictDescription,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
              ),
            ),
            if (!isProfile) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<TransferConflictResolution>(
                initialValue: item.resolution,
                decoration: const InputDecoration(labelText: 'Conflitto'),
                items: <DropdownMenuItem<TransferConflictResolution>>[
                  const DropdownMenuItem<TransferConflictResolution>(
                    value: TransferConflictResolution.overwrite,
                    child: Text('Sovrascrivi esistente'),
                  ),
                  const DropdownMenuItem<TransferConflictResolution>(
                    value: TransferConflictResolution.keepExisting,
                    child: Text('Mantieni esistente'),
                  ),
                  if (_canImportAsCopy(item.categoryCode))
                    const DropdownMenuItem<TransferConflictResolution>(
                      value: TransferConflictResolution.importCopy,
                      child: Text('Importa come copia'),
                    ),
                ],
                onChanged: (TransferConflictResolution? value) {
                  if (value == null) return;
                  item.resolution = value;
                  onChanged();
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final double kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}

bool _canImportAsCopy(String categoryCode) {
  return const <String>{
    'ingredients',
    'recipes',
    'exercises',
    'routines',
    'workoutPlans',
    'workoutSessions',
  }.contains(categoryCode);
}
