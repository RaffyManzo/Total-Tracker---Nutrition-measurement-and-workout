import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/diagnostics/app_diagnostics.dart';
import '../../../../shared/widgets/tt_app_card.dart';

class DiagnosticsSettingsCard extends StatefulWidget {
  const DiagnosticsSettingsCard({super.key});

  @override
  State<DiagnosticsSettingsCard> createState() =>
      _DiagnosticsSettingsCardState();
}

class _DiagnosticsSettingsCardState extends State<DiagnosticsSettingsCard> {
  late Future<AppDiagnosticsStatus> _statusFuture = _loadStatus();
  bool _busy = false;

  Future<AppDiagnosticsStatus> _loadStatus() =>
      AppDiagnostics.instance.status();

  void _reload() {
    if (mounted) setState(() => _statusFuture = _loadStatus());
  }

  Future<void> _run(
    Future<void> Function() operation, {
    required String successMessage,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      _reload();
    } catch (error, stackTrace) {
      await AppDiagnostics.instance.error(
        'settings.diagnostics_action_failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Operazione non riuscita: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectDirectory() async {
    final String? selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Seleziona la cartella dei log di Total Tracker',
    );
    if (selected == null || !mounted) return;
    await _run(
      () => AppDiagnostics.instance.setCustomDirectory(selected),
      successMessage: 'Cartella dei log aggiornata.',
    );
  }

  Future<void> _showLogs() async {
    final List<AppDiagnosticLogFile> files =
        await AppDiagnostics.instance.listLogFiles();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .78,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Log disponibili',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text('${files.length} file'),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: files.isEmpty
                      ? const Center(child: Text('Nessun log disponibile.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: files.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (BuildContext context, int index) {
                            final AppDiagnosticLogFile file = files[index];
                            return TtAppCard(
                              child: Row(
                                children: <Widget>[
                                  const Icon(Icons.description_outlined),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          file.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge,
                                        ),
                                        Text(
                                          '${file.modifiedAt.toLocal()} · ${file.sizeBytes} byte',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Apri',
                                    onPressed: () => _openLog(file),
                                    icon: const Icon(Icons.open_in_new_rounded),
                                  ),
                                  IconButton(
                                    tooltip: 'Copia',
                                    onPressed: () => _copyLog(file),
                                    icon: const Icon(Icons.copy_rounded),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openLog(AppDiagnosticLogFile file) async {
    final String text = await AppDiagnostics.instance.readLogFile(file.path);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(file.name),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(text.isEmpty ? 'Log vuoto.' : text),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyLog(AppDiagnosticLogFile file) async {
    final String text = await AppDiagnostics.instance.readLogFile(file.path);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log copiato negli appunti.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      child: FutureBuilder<AppDiagnosticsStatus>(
        future: _statusFuture,
        builder: (BuildContext context,
            AsyncSnapshot<AppDiagnosticsStatus> snapshot) {
          final AppDiagnosticsStatus? status = snapshot.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.bug_report_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text('Diagnostica e log',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (_busy ||
                      snapshot.connectionState == ConnectionState.waiting)
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Registra errori, navigazione e tempi delle singole fasi della '
                'dashboard. I file più vecchi di 24 ore vengono eliminati automaticamente.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              if (status != null) ...<Widget>[
                Text(
                  status.usingCustomDirectory
                      ? 'Cartella personalizzata'
                      : 'Cartella interna predefinita',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xxs),
                SelectionArea(
                  child: Text(status.activeDirectory,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: _busy ? null : _showLogs,
                    icon: const Icon(Icons.list_alt_rounded),
                    label: const Text('Visualizza log'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _selectDirectory,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Scegli cartella'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              AppDiagnostics.instance.resetToInternalDirectory,
                              successMessage:
                                  'Ripristinata la cartella interna.',
                            ),
                    icon: const Icon(Icons.settings_backup_restore_rounded),
                    label: const Text('Usa interna'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              AppDiagnostics.instance.clearLogs,
                              successMessage: 'Log cancellati.',
                            ),
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Cancella log'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
