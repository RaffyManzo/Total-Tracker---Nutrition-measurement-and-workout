import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/objectbox_providers.dart';
import '../../nutrition/data/services/target_recalculation_service.dart';

class TargetSynchronizationScreen extends ConsumerStatefulWidget {
  const TargetSynchronizationScreen({super.key});

  @override
  ConsumerState<TargetSynchronizationScreen> createState() =>
      _TargetSynchronizationScreenState();
}

class _TargetSynchronizationScreenState
    extends ConsumerState<TargetSynchronizationScreen> {
  bool _busy = false;
  TargetRecalculationProgress? _progress;
  String? _status;

  TargetRecalculationService get _service => TargetRecalculationService(
        profiles: ref.read(userProfileRepositoryProvider),
        dailyRecords: ref.read(dailyRecordRepositoryProvider),
        analytics: ref.read(foodAnalyticsServiceProvider),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sincronizzazione')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Il ricalcolo aggiorna sia gli snapshot persistiti sia i valori '
                'mostrati dall’interfaccia. Nei ricalcoli storici ogni giornata '
                'usa esclusivamente dati disponibili fino alla propria data.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ActionCard(
            icon: Icons.history_rounded,
            title: 'Ricalcola tutti i target storici',
            description:
                'Applica il modello corrente in ordine cronologico a tutte le '
                'giornate. L’operazione sostituisce gli snapshot precedenti.',
            buttonLabel: 'Ricalcola storico',
            enabled: !_busy,
            onPressed: _confirmHistorical,
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.today_rounded,
            title: 'Forza il ricalcolo odierno',
            description:
                'Rilegge pasti, passi, allenamenti e misurazioni, salva il nuovo '
                'target e forza il refresh dei provider dell’interfaccia.',
            buttonLabel: 'Sincronizza oggi',
            enabled: !_busy,
            onPressed: _recalculateToday,
          ),
          if (_busy || _progress != null) ...<Widget>[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    LinearProgressIndicator(value: _progress?.ratio),
                    const SizedBox(height: 12),
                    Text(_progress?.message ?? 'Preparazione...'),
                  ],
                ),
              ),
            ),
          ],
          if (_status != null) ...<Widget>[
            const SizedBox(height: 16),
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

  Future<void> _confirmHistorical() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Ricalcolare lo storico?'),
        content: const Text(
          'Gli snapshot calorici storici verranno riscritti con la versione '
          'corrente del modello. I dati grezzi non vengono eliminati.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ricalcola'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => _service.recalculateAllHistoricalTargets(
          onProgress: _onProgress,
        ));
  }

  Future<void> _recalculateToday() async {
    final DateTime now = DateTime.now();
    final String dateKey = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    await _run(() => _service.recalculateDay(
          dateKey,
          onProgress: _onProgress,
        ));
  }

  void _onProgress(TargetRecalculationProgress progress) {
    if (!mounted) return;
    setState(() => _progress = progress);
  }

  Future<void> _run(
    Future<TargetRecalculationReport> Function() operation,
  ) async {
    setState(() {
      _busy = true;
      _progress = null;
      _status = null;
    });
    try {
      final TargetRecalculationReport report = await operation();
      ref.invalidate(profileSettingsRevisionProvider);
      if (!mounted) return;
      setState(() {
        _status = report.updatedDays == 0
            ? 'Nessuna giornata da aggiornare.'
            : 'Aggiornate ${report.updatedDays} giornate: '
                '${report.firstUpdatedDate} → ${report.lastUpdatedDate}.';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Ricalcolo non completato: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: enabled ? onPressed : null,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
