import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/objectbox_providers.dart';
import '../data/entities/nutrition_tracking_entities.dart';
import '../data/import/legacy_scale_xls_importer.dart';
import '../data/services/scale_device_catalog_service.dart';

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
  Set<int> _selectedRows = <int>{};
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
                'Sono supportati file Excel 97–2003 (.xls). Le intestazioni '
                'vengono confrontate anche parzialmente. Nessun dato viene '
                'scritto prima della pagina di riepilogo.',
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
            Card(
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
                    Text('Foglio: ${preview.sheetName}'),
                    Text('Misurazioni valide: ${preview.rows.length}'),
                    Text('Selezionate: ${_selectedRows.length}'),
                    Text(
                      'Intervallo: ${preview.rows.isEmpty ? 'n/d' : preview.rows.first.dateKey} '
                      '→ ${preview.rows.isEmpty ? 'n/d' : preview.rows.last.dateKey}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                title: Text('Mappatura colonne (${preview.matches.length})'),
                children: <Widget>[
                  for (final LegacyScaleFieldMatch match in preview.matches)
                    ListTile(
                      dense: true,
                      title:
                          Text('${match.sourceHeader} → ${match.targetField}'),
                      trailing: Text('${(match.score * 100).round()}%'),
                    ),
                  if (preview.unmatchedHeaders.isNotEmpty)
                    ListTile(
                      title: const Text('Colonne non modellate'),
                      subtitle: Text(preview.unmatchedHeaders.join(', ')),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _selectedRows = preview.rows
                                .map((LegacyScaleImportRow row) => row.index)
                                .toSet();
                          }),
                  child: const Text('Seleziona tutte'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _selectedRows = <int>{}),
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
                  value: _selectedRows.contains(row.index),
                  onChanged: _busy
                      ? null
                      : (bool? selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedRows.add(row.index);
                            } else {
                              _selectedRows.remove(row.index);
                            }
                          });
                        },
                  title: Text(
                    '${row.dateKey} ${row.measurementTime} · '
                    '${row.weightKg.toStringAsFixed(1)} kg',
                  ),
                  subtitle: Text(_rowSummary(row)),
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
                child: Text(_status!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _loadDevices() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    final ScaleDeviceCatalogService catalog =
        ScaleDeviceCatalogService(preferences);
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
    if (name == null || name.isEmpty || _catalog == null) return;
    final ScaleDeviceOption device = await _catalog!.add(name);
    if (!mounted) return;
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
    if (path == null) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final LegacyScaleImportPreview preview = _importer.read(path);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _selectedRows =
            preview.rows.map((LegacyScaleImportRow row) => row.index).toSet();
        _status = preview.warnings.isEmpty
            ? 'File analizzato. Controlla ogni misurazione prima di importare.'
            : preview.warnings.join('\n');
      });
    } on Object catch (error) {
      if (mounted) setState(() => _status = 'File non importabile: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importSelected() async {
    final LegacyScaleImportPreview? preview = _preview;
    final ScaleDeviceOption? device = _devices
        .where((ScaleDeviceOption item) => item.id == _deviceId)
        .firstOrNull;
    if (preview == null || device == null) return;

    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final repository = ref.read(measurementRepositoryProvider);
      final Set<String> existing = repository
          .getScaleMeasurements()
          .map(
            (ScaleMeasurementEntity item) =>
                '${item.dateKey}|${item.measurementTime}',
          )
          .toSet();
      int imported = 0;
      int duplicates = 0;
      final int now = DateTime.now().millisecondsSinceEpoch;
      for (final LegacyScaleImportRow row in preview.rows) {
        if (!_selectedRows.contains(row.index)) continue;
        if (existing.contains(row.duplicateKey)) {
          duplicates += 1;
          continue;
        }
        final ScaleMeasurementEntity entity = ScaleMeasurementEntity(
          uuid: const Uuid().v4(),
          dateKey: row.dateKey,
          title: 'Bilancia · ${row.dateKey}',
          weightKg: row.weightKg,
          weightSourceCode: 'xls_import',
          bodyFatPercent: row.number('bodyFatPercent'),
          muscleMassKg: row.number('muscleMassKg'),
          waterPercent: row.number('waterPercent'),
          boneMassKg: row.number('boneMassKg'),
          visceralFat: row.number('visceralFat'),
          subcutaneousFatPercent: row.number('subcutaneousFatPercent'),
          basalMetabolismKcal: row.number('basalMetabolismKcal'),
          bmi: row.number('bmi'),
          metabolicAge: row.number('metabolicAge'),
          physiqueRating: row.text('physiqueRating'),
          measurementTime: row.measurementTime,
          device: ScaleDeviceCatalogService.encode(device),
          reliabilityCode: 'normal',
          notes: _notesFor(row),
          createdAtEpochMs: now,
          updatedAtEpochMs: now,
        );
        repository.saveScale(entity);
        existing.add(row.duplicateKey);
        imported += 1;
      }
      ref.invalidate(profileSettingsRevisionProvider);
      if (!mounted) return;
      setState(() {
        _status = 'Importate $imported misurazioni. '
            'Duplicati data/ora ignorati: $duplicates. '
            'Ricalcola i target per applicare i nuovi dati.';
      });
    } on Object catch (error) {
      if (mounted) setState(() => _status = 'Importazione interrotta: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _rowSummary(LegacyScaleImportRow row) {
    final List<String> parts = <String>[];
    void add(String label, String key, String unit) {
      final double? value = row.number(key);
      if (value != null) parts.add('$label ${value.toStringAsFixed(1)}$unit');
    }

    add('Grasso', 'bodyFatPercent', '%');
    add('Muscolo', 'muscleMassKg', ' kg');
    add('Acqua', 'waterPercent', '%');
    add('Viscerale', 'visceralFat', '');
    add('Osso', 'boneMassKg', ' kg');
    return parts.isEmpty ? 'Solo peso riconosciuto' : parts.join(' · ');
  }

  String _notesFor(LegacyScaleImportRow row) {
    final List<String> lines = <String>[
      'Importato da XLS legacy.',
      if (row.unmappedValues.isNotEmpty)
        'Campi originali non modellati: ${jsonEncode(row.unmappedValues)}',
      ...row.warnings,
    ];
    return lines.join('\n');
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
