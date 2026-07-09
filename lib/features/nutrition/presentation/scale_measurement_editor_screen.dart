import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/objectbox_providers.dart';
import '../data/entities/nutrition_tracking_entities.dart';
import '../data/services/scale_device_catalog_service.dart';
import 'measurement_screens.dart'
    show
        measurementHistoryPageProvider,
        measurementHubProvider,
        scaleMeasurementPageProvider,
        tapeMeasurementPageProvider;

class ScaleMeasurementEditorScreen extends ConsumerStatefulWidget {
  const ScaleMeasurementEditorScreen({this.initial, super.key});

  final ScaleMeasurementEntity? initial;

  @override
  ConsumerState<ScaleMeasurementEditorScreen> createState() =>
      _ScaleMeasurementEditorScreenState();
}

class _ScaleMeasurementEditorScreenState
    extends ConsumerState<ScaleMeasurementEditorScreen> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  List<ScaleDeviceOption> _devices = const <ScaleDeviceOption>[];
  ScaleDeviceOption? _device;
  DateTime _dateTime = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  String? _status;

  static const List<(String, String, String)> _numericFields =
      <(String, String, String)>[
    ('weight', 'Peso', 'kg'),
    ('bodyFat', 'Grasso corporeo', '%'),
    ('muscle', 'Massa muscolare', 'kg'),
    ('water', 'Acqua corporea', '%'),
    ('bone', 'Massa ossea', 'kg'),
    ('visceral', 'Grasso viscerale', ''),
    ('subcutaneous', 'Grasso sottocutaneo', '%'),
    ('bmr', 'Metabolismo basale', 'kcal'),
    ('bmi', 'BMI', ''),
    ('metabolicAge', 'Età metabolica', 'anni'),
  ];

  @override
  void initState() {
    super.initState();
    final ScaleMeasurementEntity? initial = widget.initial;
    final Map<String, double?> initialNumbers = <String, double?>{
      'weight': initial?.weightKg,
      'bodyFat': initial?.bodyFatPercent,
      'muscle': initial?.muscleMassKg,
      'water': initial?.waterPercent,
      'bone': initial?.boneMassKg,
      'visceral': initial?.visceralFat,
      'subcutaneous': initial?.subcutaneousFatPercent,
      'bmr': initial?.basalMetabolismKcal,
      'bmi': initial?.bmi,
      'metabolicAge': initial?.metabolicAge,
    };
    for (final field in _numericFields) {
      _controllers[field.$1] = TextEditingController(
        text: initialNumbers[field.$1]?.toString() ?? '',
      );
    }
    _controllers['physique'] =
        TextEditingController(text: initial?.physiqueRating ?? '');
    _controllers['notes'] = TextEditingController(text: initial?.notes ?? '');
    _dateTime = _dateTimeFromMeasurement(initial) ?? DateTime.now();
    _loadDevices();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDevices() async {
    final preferences = await SharedPreferences.getInstance();
    final catalog = ScaleDeviceCatalogService(preferences);
    await catalog.mergeStoredValues(
      ref
          .read(measurementRepositoryProvider)
          .getScaleMeasurements()
          .map((ScaleMeasurementEntity item) => item.device),
    );
    if (!mounted) return;
    setState(() {
      _devices = catalog.load();
      _device = widget.initial == null
          ? catalog.defaultDevice()
          : catalog.findByStoredValue(widget.initial!.device) ??
              catalog.defaultDevice();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null
            ? 'Nuova misurazione bilancia'
            : 'Modifica misurazione bilancia'),
        actions: <Widget>[
          if (widget.initial != null)
            IconButton(
              tooltip: 'Elimina misurazione',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text(DateFormat('dd/MM/yyyy HH:mm').format(_dateTime)),
                  trailing: TextButton(
                    onPressed: _pickDateTime,
                    child: const Text('Modifica'),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey<String?>(_device?.id),
                  initialValue: _device?.id,
                  decoration: const InputDecoration(
                    labelText: 'Dispositivo',
                    helperText:
                        'Seleziona un dispositivo configurato: il nome non viene più scritto a mano.',
                  ),
                  items: _devices
                      .map(
                        (device) => DropdownMenuItem<String>(
                          value: device.id,
                          child: Text(device.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? id) {
                    setState(() {
                      _device = _devices
                          .where((device) => device.id == id)
                          .firstOrNull;
                    });
                  },
                ),
                if (_devices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Configura prima un dispositivo dall’Hub misure.',
                    ),
                  ),
                const SizedBox(height: 16),
                for (final field in _numericFields) ...<Widget>[
                  TextField(
                    controller: _controllers[field.$1],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: field.$2,
                      suffixText: field.$3.isEmpty ? null : field.$3,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _controllers['physique'],
                  decoration: const InputDecoration(
                    labelText: 'Valutazione fisico',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controllers['notes'],
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Salvataggio…' : 'Salva misurazione'),
                ),
                if (_status != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(_status!),
                ],
              ],
            ),
    );
  }

  DateTime? _dateTimeFromMeasurement(ScaleMeasurementEntity? measurement) {
    if (measurement == null) return null;
    final DateTime? date = DateTime.tryParse(measurement.dateKey);
    if (date == null) return null;
    final List<String> parts = measurement.measurementTime.split(':');
    final int hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final int minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final int second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute, second);
  }

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null) return;
    setState(() {
      _dateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  double? _number(String key) {
    final value = _controllers[key]?.text.trim().replaceAll(',', '.') ?? '';
    return value.isEmpty ? null : double.tryParse(value);
  }

  Future<void> _save() async {
    final double? weight = _number('weight');
    if (weight == null || weight <= 0) {
      setState(() => _status = 'Inserisci un peso valido.');
      return;
    }
    final device = _device;
    if (device == null) {
      setState(() => _status = 'Seleziona un dispositivo configurato.');
      return;
    }
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      final int now = DateTime.now().millisecondsSinceEpoch;
      final ScaleMeasurementEntity? initial = widget.initial;
      final ScaleMeasurementEntity entity = ScaleMeasurementEntity(
        id: initial?.id ?? 0,
        uuid: initial?.uuid ?? const Uuid().v4(),
        dateKey: DateFormat('yyyy-MM-dd').format(_dateTime),
        title: 'Bilancia · ${DateFormat('yyyy-MM-dd').format(_dateTime)}',
        weightKg: weight,
        weightSourceCode: initial?.weightSourceCode ?? 'manual',
        bodyFatPercent: _number('bodyFat'),
        muscleMassKg: _number('muscle'),
        waterPercent: _number('water'),
        boneMassKg: _number('bone'),
        visceralFat: _number('visceral'),
        subcutaneousFatPercent: _number('subcutaneous'),
        basalMetabolismKcal: _number('bmr'),
        bmi: _number('bmi'),
        metabolicAge: _number('metabolicAge'),
        physiqueRating: _controllers['physique']!.text.trim(),
        measurementTime: DateFormat('HH:mm:ss').format(_dateTime),
        device: ScaleDeviceCatalogService.encode(device),
        reliabilityCode: initial?.reliabilityCode ?? 'normal',
        weightAnomalyConfirmationKey:
            initial?.weightAnomalyConfirmationKey ?? '',
        notes: _controllers['notes']!.text.trim(),
        createdAtEpochMs: initial?.createdAtEpochMs ?? now,
        updatedAtEpochMs: now,
      );
      ref.read(measurementRepositoryProvider).saveScale(entity);
      ref.invalidate(profileSettingsRevisionProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (mounted) setState(() => _status = 'Salvataggio non riuscito: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ScaleMeasurementEntity? initial = widget.initial;
    if (initial == null) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Elimina misurazione'),
          content: const Text(
            'La pesata verra rimossa dalla lista attiva e dai trasferimenti. '
            'Le misurazioni metro non saranno modificate.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _saving = true;
      _status = null;
    });
    bool popped = false;
    try {
      ref.read(measurementRepositoryProvider).softDeleteScale(initial);
      ref.invalidate(measurementHubProvider);
      ref.invalidate(scaleMeasurementPageProvider);
      ref.invalidate(tapeMeasurementPageProvider);
      ref.invalidate(measurementHistoryPageProvider);
      ref.invalidate(profileSettingsRevisionProvider);
      if (!mounted) return;
      popped = true;
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _status = 'Eliminazione non riuscita: $error');
      }
    } finally {
      if (mounted && !popped) {
        setState(() => _saving = false);
      }
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
