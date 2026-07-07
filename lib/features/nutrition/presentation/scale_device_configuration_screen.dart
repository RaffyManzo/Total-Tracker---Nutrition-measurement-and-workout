import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/objectbox_providers.dart';
import '../data/entities/nutrition_tracking_entities.dart';
import '../data/services/scale_device_catalog_service.dart';
import '../domain/composition_reliability.dart';

class ScaleDeviceConfigurationScreen extends ConsumerStatefulWidget {
  const ScaleDeviceConfigurationScreen({super.key});

  @override
  ConsumerState<ScaleDeviceConfigurationScreen> createState() =>
      _ScaleDeviceConfigurationScreenState();
}

class _ScaleDeviceConfigurationScreenState
    extends ConsumerState<ScaleDeviceConfigurationScreen> {
  ScaleDeviceCatalogService? _catalog;
  List<ScaleDeviceOption> _devices = const <ScaleDeviceOption>[];
  bool _loading = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivi bilancia'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Configura nuovo dispositivo',
            onPressed: _loading ? null : _add,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Configura nuovo dispositivo'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: <Widget>[
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Ogni dispositivo riceve un identificatore stabile. Il nome '
                      'può essere rinominato senza simulare un cambio bilancia. '
                      'Le misurazioni continuano a conservare anche un nome leggibile.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_devices.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Nessun dispositivo configurato.'),
                    ),
                  ),
                for (final ScaleDeviceOption device in _devices)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        device.isDefault
                            ? Icons.monitor_weight_rounded
                            : Icons.monitor_weight_outlined,
                      ),
                      title: Text(device.name),
                      subtitle: Text(
                        device.isDefault
                            ? 'Predefinito · ID ${device.id}'
                            : 'ID ${device.id}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (String action) => _handle(action, device),
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                          if (!device.isDefault)
                            const PopupMenuItem<String>(
                              value: 'default',
                              child: Text('Imposta come predefinito'),
                            ),
                          const PopupMenuItem<String>(
                            value: 'rename',
                            child: Text('Rinomina'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'migrate',
                            child: Text('Uniforma misurazioni esistenti'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Rimuovi'),
                          ),
                        ],
                      ),
                    ),
                  ),
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

  Future<void> _load() async {
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
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _devices = catalog.load();
      _loading = false;
    });
  }

  Future<String?> _askName({String initial = ''}) async {
    final TextEditingController controller =
        TextEditingController(text: initial);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Nome dispositivo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome',
            hintText: 'Es. INSMART Health',
          ),
          onSubmitted: (String value) =>
              Navigator.of(context).pop(value.trim()),
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
    return result;
  }

  Future<void> _add() async {
    final String? name = await _askName();
    if (name == null || name.isEmpty || _catalog == null) return;
    final ScaleDeviceOption device = await _catalog!.add(name);
    if (!mounted) return;
    final bool assignUnspecified = await _confirmAssignUnspecified();
    await _migrate(device, includeUnspecified: assignUnspecified);
    _refresh('Dispositivo configurato: ${device.name}.');
  }

  Future<bool> _confirmAssignUnspecified() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Uniformare lo storico?'),
        content: const Text(
          'Assegnare questo dispositivo anche alle misurazioni che non hanno '
          'ancora un nome dispositivo? È utile quando tutte le pesate provengono '
          'dalla stessa bilancia.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Solo nomi equivalenti'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Includi non specificate'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handle(String action, ScaleDeviceOption device) async {
    switch (action) {
      case 'default':
        await _catalog!.makeDefault(device.id);
        _refresh('${device.name} impostato come predefinito.');
        return;
      case 'rename':
        final String? name = await _askName(initial: device.name);
        if (name == null || name.isEmpty) return;
        await _catalog!.rename(device.id, name);
        final ScaleDeviceOption renamed = _catalog!
            .load()
            .firstWhere((ScaleDeviceOption item) => item.id == device.id);
        final int updated = await _migrate(
          renamed,
          includeUnspecified: false,
        );
        _refresh('Dispositivo rinominato. Aggiornate $updated misurazioni.');
        return;
      case 'migrate':
        final bool includeUnspecified = await _confirmAssignUnspecified();
        final int updated = await _migrate(
          device,
          includeUnspecified: includeUnspecified,
        );
        _refresh('Uniformate $updated misurazioni.');
        return;
      case 'delete':
        await _catalog!.remove(device.id);
        _refresh(
            'Dispositivo rimosso dal catalogo. Le misurazioni non sono eliminate.');
        return;
    }
  }

  Future<int> _migrate(
    ScaleDeviceOption device, {
    required bool includeUnspecified,
  }) async {
    final repository = ref.read(measurementRepositoryProvider);
    final String targetCanonical =
        CompositionReliabilityCalculator.canonicalDeviceCode(device.name);
    final String encoded = ScaleDeviceCatalogService.encode(device);
    int updated = 0;
    for (final ScaleMeasurementEntity measurement
        in repository.getScaleMeasurements()) {
      final String currentCanonical =
          CompositionReliabilityCalculator.canonicalDeviceCode(
              measurement.device);
      final String currentTokenId =
          ScaleDeviceCatalogService.tokenId(measurement.device);
      final bool shouldUpdate = currentTokenId == device.id ||
          currentCanonical == targetCanonical ||
          (includeUnspecified && currentCanonical == 'unspecified');
      if (!shouldUpdate || measurement.device == encoded) continue;
      measurement.device = encoded;
      repository.saveScale(measurement);
      updated += 1;
    }
    ref.invalidate(profileSettingsRevisionProvider);
    return updated;
  }

  void _refresh(String status) {
    if (!mounted) return;
    setState(() {
      _devices = _catalog!.load();
      _status = status;
    });
  }
}
