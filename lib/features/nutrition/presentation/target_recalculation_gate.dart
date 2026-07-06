import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/objectbox_providers.dart';
import '../../../shared/widgets/tt_app_card.dart';
import '../data/entities/nutrition_tracking_entities.dart';
import '../data/food_data_refresh_bus.dart';
import '../data/services/target_recalculation_service.dart';
import '../domain/target_model_constants.dart';
import 'food_v01_screens.dart';

class TargetRecalculationGate extends ConsumerStatefulWidget {
  const TargetRecalculationGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<TargetRecalculationGate> createState() =>
      _TargetRecalculationGateState();
}

class _TargetRecalculationGateState
    extends ConsumerState<TargetRecalculationGate> {
  bool _scheduled = false;
  bool _completed = false;
  bool _running = false;
  double? _progress;
  String _message = 'Verifica dei target in corso...';
  Object? _error;

  @override
  Widget build(BuildContext context) {
    final DatabaseInitializationStatus status =
        ref.watch(databaseInitializationStatusProvider);
    if (status.isReady && !_scheduled && !_completed) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
    if (!status.isReady || _completed) {
      return widget.child;
    }

    return PopScope(
      canPop: false,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          widget.child,
          ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: TtAppCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            _error == null
                                ? Icons.sync_rounded
                                : Icons.error_outline_rounded,
                            size: 48,
                            color: _error == null
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _error == null
                                ? 'Ricalcolo iniziale dei target'
                                : 'Ricalcolo non completato',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _error == null
                                ? 'Non chiudere l’app e non cambiare pagina. '
                                    'I target vengono aggiornati in modo atomico.'
                                : 'Nessuna modifica parziale è stata confermata. '
                                    'Riprova per continuare.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (_error == null) ...<Widget>[
                            LinearProgressIndicator(value: _progress),
                            const SizedBox(height: AppSpacing.md),
                            Text(_message, textAlign: TextAlign.center),
                          ] else ...<Widget>[
                            Text(
                              'Dettaglio: $_error',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            FilledButton.icon(
                              onPressed: _running ? null : _run,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Riprova'),
                            ),
                          ],
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

  Future<void> _run() async {
    if (_running || !mounted) return;
    setState(() {
      _running = true;
      _error = null;
      _progress = null;
      _message = 'Verifica della versione del calcolo...';
    });
    try {
      final String todayKey = _todayKey();
      final DailyRecordEntity? today =
          ref.read(dailyRecordRepositoryProvider).findByDate(todayKey);
      final bool required = today == null ||
          !today.targetSourceHash.startsWith(
            '${TargetModelConstants.modelVersion}|',
          );
      if (!required) {
        if (mounted) setState(() => _completed = true);
        return;
      }
      final TargetRecalculationService service = TargetRecalculationService(
        profiles: ref.read(userProfileRepositoryProvider),
        dailyRecords: ref.read(dailyRecordRepositoryProvider),
        analytics: ref.read(foodAnalyticsServiceProvider),
      );
      await service.recalculateCurrentAndFutureTargets(
        onProgress: (TargetRecalculationProgress progress) {
          if (!mounted) return;
          setState(() {
            _progress = progress.ratio;
            _message = progress.message;
          });
        },
      );
      ref.invalidate(profileSettingsRevisionProvider);
      ref.invalidate(foodHubV01Provider);
      ref.invalidate(foodDaysV01Provider);
      ref.invalidate(foodMealsV01Provider);
      FoodDataRefreshBus.publishManualRefresh(todayKey);
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _message = 'Ricalcolo completato.';
      });
      if (mounted) setState(() => _completed = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  String _todayKey() {
    final DateTime now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
