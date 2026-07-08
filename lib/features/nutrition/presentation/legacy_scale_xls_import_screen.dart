import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/objectbox_providers.dart';
import '../data/entities/nutrition_tracking_entities.dart';
import '../data/import/legacy_scale_xls_importer.dart';
import '../data/services/scale_device_catalog_service.dart';
import '../data/services/scale_measurement_batch_import_service.dart';

class LegacyScaleXlsImportScreen extends ConsumerStatefulWidget {
  const LegacyScaleXlsImportScreen({super.key});

  @override
  ConsumerState<LegacyScaleXlsImportScreen> createState() =>
      _LegacyScaleXlsImportScreenState();
}

class _LegacyScaleXlsImportScreenState
    extends ConsumerState<LegacyScaleXlsImportScreen> {
  final LegacyScaleXlsImporter _importer = const LegacyScaleXlsImporter();
  ScaleDeviceCatalogService? _catalog;
  List<ScaleDeviceOption> _devices = const <ScaleDeviceOption>[];
  String? _deviceId;
  LegacyScaleImportPreview? _preview;
  Set<String> _selectedRows = <String>{};
  DateTime? _fromDate;
  DateTime? _toDate;
  XlsDailySelectionMode _selectionMode = XlsDailySelectionMode.allMeasurements;
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  @override
  Widget build(BuildContext context) {
    final LegacyScaleImportPreview? preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Importa bilancia XLS')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sono supportati file Excel 97–2003 (.xls). Tutti i fogli '
                'non vuoti vengono analizzati. Nessun dato viene scritto '
                'prima della conferma nella pagina di riepilogo.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey<String?>(_deviceId),
                  initialValue: _devices.any(
                    (ScaleDeviceOption item) => item.id == _deviceId,
                  )
                      ? _deviceId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Dispositivo configurato',
                  ),
                  items: _devices
                      .map(
                        (ScaleDeviceOption item) => DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _busy
                      ? null
                      : (String? value) => setState(() => _deviceId = value),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Configura nuovo dispositivo',
                onPressed: _busy ? null : _addDevice,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _pickFile,
            icon: const Icon(Icons.table_view_outlined),
            label: const Text('Seleziona file XLS'),
          ),
          if (preview != null) ...<Widget>[
            const SizedBox(height: 16),
            _buildSummary(preview),
            const SizedBox(height: 8),
            _buildColumnMapping(preview),
            const SizedBox(height: 8),
            _buildQuickSelection(preview),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _selectedRows = preview.rows
                                .map((LegacyScaleImportRow row) => row.rowId)
                                .toSet();
                          }),
                  child: const Text('Seleziona tutte'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(
                            () => _selectedRows = <String>{},
                          ),
                  child: const Text('Deseleziona'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _busy || _selectedRows.isEmpty || _deviceId == null
                      ? null
                      : _importSelected,
                  icon: const Icon(Icons.download_done_rounded),
                  label: Text('Importa ${_selectedRows.length}'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final LegacyScaleImportRow row in preview.rows)
              Card(
                child: CheckboxListTile(
                  value: _selectedRows.contains(row.rowId),
                  onChanged: _busy
                      ? null
                      : (bool? selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedRows.add(row.rowId);
                            } else {
                              _selectedRows.remove(row.rowId);
                            }
                          });
                        },
                  title: Text(
                    '${row.dateKey} ${row.hasExplicitTime ? row.measurementTime : 'orario n/d'} '
                    '· ${row.weightKg.toStringAsFixed(1)} kg',
                  ),
                  subtitle: Text(
                    '${row.sourceSheetName}, riga ${row.sourceRowNumber}\n'
                    '${_rowSummary(row)}',
                  ),
                  isThreeLine: true,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
          ],
          if (_busy) ...<Widget>[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_status != null) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(_status!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummary(LegacyScaleImportPreview preview) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Riepilogo file',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Fogli: ${preview.sheetNames.join(', ')}'),
            Text('Misurazioni valide: ${preview.rows.length}'),
            Text('Selezionate: ${_selectedRows.length}'),
            Text(
              'Intervallo trovato: ${preview.firstDateKey ?? 'n/d'} '
              '→ ${preview.lastDateKey ?? 'n/d'}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnMapping(LegacyScaleImportPreview preview) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text('Mappatura colonne (${preview.matches.length})'),
        children: <Widget>[
          for (final LegacyScaleFieldMatch match in preview.matches)
            ListTile(
              dense: true,
              title: Text(
                '${match.sourceSheetName}: ${match.sourceHeader} '
                '→ ${match.targetField}',
              ),
              trailing: Text('${(match.score * 100).round()}%'),
            ),
          if (preview.unmatchedHeaders.isNotEmpty)
            ListTile(
              title: const Text('Colonne non modellate'),
              subtitle: Text(preview.unmatchedHeaders.join(', ')),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickSelection(LegacyScaleImportPreview preview) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Selezione rapida per data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'La selezione non elimina righe: puoi sempre modificare '
              'manualmente le singole caselle prima dell’importazione.',
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pickBoundary(true),
                    icon: const Icon(Icons.date_range_rounded),
                    label: Text(
                      _fromDate == null
                          ? 'Data iniziale'
                          : 'Da ${_dateKey(_fromDate!)}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pickBoundary(false),
                    icon: const Icon(Icons.event_rounded),
                    label: Text(
                      _toDate == null
                          ? 'Data finale'
                          : 'A ${_dateKey(_toDate!)}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<XlsDailySelectionMode>(
              initialValue: _selectionMode,
              decoration: const InputDecoration(
                labelText: 'Misurazioni da selezionare',
              ),
              items: const <DropdownMenuItem<XlsDailySelectionMode>>[
                DropdownMenuItem<XlsDailySelectionMode>(
                  value: XlsDailySelectionMode.allMeasurements,
                  child: Text('Tutte le misurazioni nell’intervallo'),
                ),
                DropdownMenuItem<XlsDailySelectionMode>(
                  value: XlsDailySelectionMode.latestPerDay,
                  child: Text('Una per giorno: la più recente'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (XlsDailySelectionMode? value) {
                      if (value != null) {
                        setState(() => _selectionMode = value);
                      }
                    },
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed:
                        _busy ? null : () => _applyQuickSelection(preview),
                    icon: const Icon(Icons.filter_alt_rounded),
                    label: const Text('Applica selezione'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Ripristina l’intervallo completo',
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _fromDate = _parseDate(preview.firstDateKey);
                            _toDate = _parseDate(preview.lastDateKey);
                          }),
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadDevices() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    final ScaleDeviceCatalogService catalog =
        ScaleDeviceCatalogService(preferences);
    await catalog.ensureMigrated();
    await catalog.mergeStoredValues(
      ref
          .read(measurementRepositoryProvider)
          .getScaleMeasurements()
          .map((ScaleMeasurementEntity item) => item.device),
    );
    final List<ScaleDeviceOption> devices = catalog.load();
    setState(() {
      _catalog = catalog;
      _devices = devices;
      _deviceId = catalog.defaultDevice()?.id;
    });
  }

  Future<void> _addDevice() async {
    final TextEditingController controller = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Configura nuovo dispositivo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome dispositivo'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || _catalog == null) {
      return;
    }
    final ScaleDeviceOption device = await _catalog!.add(name);
    if (!mounted) {
      return;
    }
    setState(() {
      _devices = _catalog!.load();
      _deviceId = device.id;
    });
  }

  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Seleziona esportazione bilancia XLS',
      type: FileType.custom,
      allowedExtensions: const <String>['xls'],
      allowMultiple: false,
      withData: false,
    );
    final String? path = result?.files.single.path;
    if (path == null) {
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Analisi del workbook in corso…';
    });
    try {
      final LegacyScaleImportPreview preview = await _importer.readAsync(path);
      if (!mounted) {
        return;
      }
      final DateTime? from = _parseDate(preview.firstDateKey);
      final DateTime? to = _parseDate(preview.lastDateKey);
      setState(() {
        _preview = preview;
        _fromDate = from;
        _toDate = to;
        _selectionMode = XlsDailySelectionMode.allMeasurements;
        _selectedRows = LegacyScaleSelection.select(rows: preview.rows);
        _status = preview.warnings.isEmpty
            ? 'File analizzato. Controlla ogni misurazione prima di importare.'
            : preview.warnings.join('\n');
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() => _status = 'File non importabile: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pickBoundary(bool start) async {
    final DateTime initial = start
        ? (_fromDate ?? _toDate ?? DateTime.now())
        : (_toDate ?? _fromDate ?? DateTime.now());
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (start) {
        _fromDate = picked;
        if (_toDate != null && picked.isAfter(_toDate!)) {
          _toDate = picked;
        }
      } else {
        _toDate = picked;
        if (_fromDate != null && picked.isBefore(_fromDate!)) {
          _fromDate = picked;
        }
      }
    });
  }

  void _applyQuickSelection(LegacyScaleImportPreview preview) {
    final String? from = _fromDate == null ? null : _dateKey(_fromDate!);
    final String? to = _toDate == null ? null : _dateKey(_toDate!);
    final Set<String> selected = LegacyScaleSelection.select(
      rows: preview.rows,
      fromDateKey: from,
      toDateKey: to,
      mode: _selectionMode,
    );
    final int hiddenSameDay =
        _selectionMode == XlsDailySelectionMode.latestPerDay
            ? preview.rows.where((row) {
                  if (from != null && row.dateKey.compareTo(from) < 0) {
                    return false;
                  }
                  if (to != null && row.dateKey.compareTo(to) > 0) {
                    return false;
                  }
                  return true;
                }).length -
                selected.length
            : 0;
    setState(() {
      _selectedRows = selected;
      _status = _selectionMode == XlsDailySelectionMode.latestPerDay
          ? 'Selezionate ${selected.length} misurazioni: una per giorno, '
              'scegliendo l’orario più recente. Righe della stessa data '
              'deselezionate: $hiddenSameDay.'
          : 'Selezionate ${selected.length} misurazioni nell’intervallo.';
    });
  }

  Future<void> _importSelected() async {
    final LegacyScaleImportPreview? preview = _preview;
    final ScaleDeviceOption? device = _devices
        .where((ScaleDeviceOption item) => item.id == _deviceId)
        .firstOrNull;
    if (preview == null || device == null) {
      return;
    }
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final ScaleBatchImportReport report = ScaleMeasurementBatchImportService(
        ref.read(objectBoxStoreProvider),
      ).importSelected(
        preview: preview,
        selectedRowIds: _selectedRows,
        device: device,
      );
      ref.invalidate(profileSettingsRevisionProvider);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Importazione completata.\n'
            'Righe lette: ${report.readRows}.\n'
            'Selezionate: ${report.selectedRows}.\n'
            'Importate: ${report.importedRows}.\n'
            'Duplicati esatti ignorati: ${report.exactDuplicates}.\n'
            'Conflitti stesso istante ignorati: ${report.timestampConflicts}.\n'
            'Righe non valide: ${report.invalidRows}.\n'
            'Intervallo invalidato: ${report.fromDateKey ?? 'n/d'} '
            '→ ${report.toDateKey ?? 'n/d'}.';
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() => _status = 'Importazione interrotta: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _rowSummary(LegacyScaleImportRow row) {
    final List<String> parts = <String>[];
    void add(String label, String key, String unit) {
      final double? value = row.number(key);
      if (value != null) {
        parts.add('$label ${value.toStringAsFixed(1)}$unit');
      }
    }

    add('Grasso', 'bodyFatPercent', '%');
    add('Muscolo', 'muscleMassKg', ' kg');
    add('Acqua', 'waterPercent', '%');
    add('Viscerale', 'visceralFat', '');
    add('Osso', 'boneMassKg', ' kg');
    return parts.isEmpty ? 'Solo peso riconosciuto' : parts.join(' · ');
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
