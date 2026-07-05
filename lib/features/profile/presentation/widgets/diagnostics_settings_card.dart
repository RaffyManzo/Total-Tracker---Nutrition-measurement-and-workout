import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
    if (!mounted) return;
    setState(() => _statusFuture = _loadStatus());
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

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      child: FutureBuilder<AppDiagnosticsStatus>(
        future: _statusFuture,
        builder: (
          BuildContext context,
          AsyncSnapshot<AppDiagnosticsStatus> snapshot,
        ) {
          final AppDiagnosticsStatus? status = snapshot.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.bug_report_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Diagnostica e log',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
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
                'Registra errori Flutter, failed assertion, navigazione e tempi '
                'di caricamento della dashboard in formato JSON Lines.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              if (snapshot.hasError)
                Text(
                  'Impossibile leggere la configurazione: ${snapshot.error}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                )
              else if (status != null) ...<Widget>[
                Text(
                  status.usingCustomDirectory
                      ? 'Cartella personalizzata'
                      : 'Cartella interna predefinita',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xxs),
                SelectionArea(
                  child: Text(
                    status.activeDirectory,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SelectionArea(
                  child: Text(
                    'File corrente: ${status.currentLogFile}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  FilledButton.icon(
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
                              AppDiagnostics.instance.writeTestEntry,
                              successMessage: 'Log di prova scritto.',
                            ),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Scrivi prova'),
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
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Su Android alcune cartelle condivise possono non concedere '
                'scrittura diretta. In quel caso resta disponibile la cartella '
                'interna dell’app.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}
