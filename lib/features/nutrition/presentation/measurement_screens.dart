import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../l10n/l10n.dart';
import '../../../core/database/objectbox_providers.dart';
import '../../../shared/widgets/tt_app_card.dart';
import '../../../shared/widgets/tt_global_nav_fab.dart';
import '../../../shared/widgets/tt_mini_charts.dart';
import '../../../shared/widgets/tt_primary_button.dart';
import '../../../shared/widgets/tt_section_header.dart';
import '../data/entities/nutrition_tracking_entities.dart';
import '../domain/weight_measurement_anomaly.dart';

final FutureProvider<MeasurementHubData> measurementHubProvider =
    FutureProvider<MeasurementHubData>((Ref ref) async {
  final repository = ref.watch(measurementRepositoryProvider);
  return MeasurementHubData(
    scaleMeasurements: repository.getScaleMeasurements(),
    tapeMeasurements: repository.getTapeMeasurements(),
    entriesByTapeId: <int, List<TapeMeasurementEntryEntity>>{
      for (final TapeMeasurementEntity item in repository.getTapeMeasurements())
        item.id: repository.getTapeEntries(item.id),
    },
  );
});

class MeasurementHubData {
  const MeasurementHubData({
    required this.scaleMeasurements,
    required this.tapeMeasurements,
    required this.entriesByTapeId,
  });

  final List<ScaleMeasurementEntity> scaleMeasurements;
  final List<TapeMeasurementEntity> tapeMeasurements;
  final Map<int, List<TapeMeasurementEntryEntity>> entriesByTapeId;

  ScaleMeasurementEntity? get latestScale {
    return scaleMeasurements.isEmpty ? null : scaleMeasurements.first;
  }

  TapeMeasurementEntity? get latestTape {
    return tapeMeasurements.isEmpty ? null : tapeMeasurements.first;
  }

  WeightAnomalyEvaluation weightAnomalyFor(ScaleMeasurementEntity item) {
    return evaluateWeightAnomaly(
      currentIdentity: _scaleIdentity(item),
      currentDateKey: item.dateKey,
      currentWeightKg: item.weightKg,
      measurements: <WeightMeasurementSample>[
        for (final ScaleMeasurementEntity measurement in scaleMeasurements)
          WeightMeasurementSample(
            identity: _scaleIdentity(measurement),
            dateKey: measurement.dateKey,
            weightKg: measurement.weightKg,
          ),
      ],
    );
  }

  List<TtChartPoint> get weightTrend {
    return <TtChartPoint>[
      for (final ScaleMeasurementEntity item
          in scaleMeasurements.take(12).toList().reversed)
        if (item.weightKg != null)
          TtChartPoint(label: item.dateKey.substring(5), value: item.weightKg!),
    ];
  }

  List<TtChartPoint> get bodyFatTrend {
    return <TtChartPoint>[
      for (final ScaleMeasurementEntity item
          in scaleMeasurements.take(12).toList().reversed)
        if (item.bodyFatPercent != null)
          TtChartPoint(
            label: item.dateKey.substring(5),
            value: item.bodyFatPercent!,
          ),
    ];
  }

  List<TtChartSeries> get tapeOverviewSeries {
    return tapeSeries(
      codes: const <String>[
        'waist_cm',
        'abdomen_cm',
        'chest_cm',
        'hips_cm',
        'shoulders_cm',
      ],
    );
  }

  List<TtChartSeries> tapeSeries({List<String>? codes}) {
    final List<String> selectedCodes = codes ?? tapeMeasurementCodes;
    return <TtChartSeries>[
      for (final String code in selectedCodes)
        if (_tapeTrendForCode(code).length >= 2)
          TtChartSeries(
            label: _tapeLabel(code),
            points: _tapeTrendForCode(code),
          ),
    ];
  }

  List<TtChartPoint> _tapeTrendForCode(String code) {
    final List<TtChartPoint> points = <TtChartPoint>[];
    for (final TapeMeasurementEntity measurement
        in tapeMeasurements.take(12).toList().reversed) {
      final List<TapeMeasurementEntryEntity> entries =
          entriesByTapeId[measurement.id] ??
              const <TapeMeasurementEntryEntity>[];
      TapeMeasurementEntryEntity? entry;
      for (final TapeMeasurementEntryEntity item in entries) {
        if (item.measurementCode == code && item.valueCm != null) {
          entry = item;
          break;
        }
      }
      if (entry != null) {
        points.add(
          TtChartPoint(
            label: measurement.dateKey.substring(5),
            value: entry.valueCm!,
          ),
        );
      }
    }
    return points;
  }

  List<TapeMeasurementEntryEntity> latestTapeEntries() {
    final TapeMeasurementEntity? tape = latestTape;
    if (tape == null) {
      return const <TapeMeasurementEntryEntity>[];
    }
    return entriesByTapeId[tape.id] ?? const <TapeMeasurementEntryEntity>[];
  }
}

class MeasurementsHubScreen extends ConsumerStatefulWidget {
  const MeasurementsHubScreen({super.key});

  @override
  ConsumerState<MeasurementsHubScreen> createState() =>
      _MeasurementsHubScreenState();
}

class _MeasurementsHubScreenState extends ConsumerState<MeasurementsHubScreen> {
  DateTime? _filterFrom;
  DateTime? _filterTo;
  String _filterType = 'all';

  @override
  Widget build(BuildContext context) {
    final AsyncValue<MeasurementHubData> data =
        ref.watch(measurementHubProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Misurazioni'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Nuova bilancia',
            onPressed: () => _showScaleDialog(context, ref),
            icon: const Icon(Icons.monitor_weight_outlined),
          ),
          IconButton(
            tooltip: 'Nuova metro',
            onPressed: () => _showTapeDialog(context, ref),
            icon: const Icon(Icons.straighten_rounded),
          ),
        ],
      ),
      bottomNavigationBar:
          const TtFoodBottomNavBar(activeItem: TtFoodNavItem.none),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(measurementHubProvider),
        ),
        data: (MeasurementHubData data) {
          final List<ScaleMeasurementEntity> filteredScale =
              _filteredScale(data.scaleMeasurements);
          final List<TapeMeasurementEntity> filteredTape =
              _filteredTape(data.tapeMeasurements);
          return ListView(
            padding: _screenPadding,
            children: <Widget>[
              Text(
                'Hub Misurazioni corporee',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Peso e misure sono registrazioni autonome; i giorni leggono il peso dalla bilancia.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              _MetricGrid(
                metrics: <_Metric>[
                  _Metric('Bilancia', data.scaleMeasurements.length.toString()),
                  _Metric('Metro', data.tapeMeasurements.length.toString()),
                  _Metric(
                    'Ultimo peso',
                    _fmtNullable(data.latestScale?.weightKg, 'kg'),
                  ),
                  _Metric(
                    'Grasso',
                    _fmtNullable(data.latestScale?.bodyFatPercent, '%'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TtPrimaryButton(
                      label: 'Nuova bilancia',
                      icon: Icons.monitor_weight_outlined,
                      onPressed: () => _showScaleDialog(context, ref),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TtPrimaryButton(
                      label: 'Nuova metro',
                      icon: Icons.straighten_rounded,
                      onPressed: () => _showTapeDialog(context, ref),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              _InteractiveBodyMeasurementsCard(
                data: data,
                onRegionTap: (String code) =>
                    _showBodyRegionSheet(context, ref, data, code),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              _ChartCard(
                title: 'Peso',
                subtitle: 'Trend bilancia',
                child: TtMiniLineChart(
                    points: data.weightTrend, valueSuffix: 'kg'),
              ),
              const SizedBox(height: AppSpacing.md),
              _ChartCard(
                title: 'Grasso corporeo',
                subtitle: 'Percentuale quando disponibile',
                child: TtMiniLineChart(
                    points: data.bodyFatTrend, valueSuffix: '%'),
              ),
              const SizedBox(height: AppSpacing.md),
              _ChartCard(
                title: 'Misure metro',
                subtitle: 'Trend congiunto delle misure principali',
                child: TtMiniMultiLineChart(
                  series: data.tapeOverviewSeries,
                  valueSuffix: 'cm',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TtAppCard(
                onTap: () => _showMeasurementChartsSheet(context, data),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.insights_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Tutti i grafici',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Apri statistiche complete per bilancia e metro',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              const TtSectionHeader(title: 'Ultime misurazioni'),
              const SizedBox(height: AppSpacing.md),
              _MeasurementFilterCard(
                from: _filterFrom,
                to: _filterTo,
                type: _filterType,
                onPickFrom: () => _pickFilterDate(isFrom: true),
                onPickTo: () => _pickFilterDate(isFrom: false),
                onClear: _clearFilters,
                onTypeChanged: (String value) {
                  setState(() => _filterType = value);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              if (filteredScale.isEmpty && filteredTape.isEmpty)
                const TtAppCard(
                  child: Text('Nessuna misurazione per i filtri selezionati.'),
                )
              else ...<Widget>[
                for (final ScaleMeasurementEntity item in filteredScale.take(6))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _buildScaleTile(
                      context: context,
                      ref: ref,
                      data: data,
                      item: item,
                    ),
                  ),
                for (final TapeMeasurementEntity item in filteredTape.take(6))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _TapeTile(
                      item: item,
                      entries: data.entriesByTapeId[item.id] ??
                          const <TapeMeasurementEntryEntity>[],
                      onTap: () => _showTapeDialog(
                        context,
                        ref,
                        existing: item,
                        existingEntries: data.entriesByTapeId[item.id] ??
                            const <TapeMeasurementEntryEntity>[],
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  List<ScaleMeasurementEntity> _filteredScale(
    List<ScaleMeasurementEntity> measurements,
  ) {
    if (_filterType == 'tape') {
      return const <ScaleMeasurementEntity>[];
    }
    return measurements
        .where((ScaleMeasurementEntity item) => _dateMatches(item.dateKey))
        .toList();
  }

  List<TapeMeasurementEntity> _filteredTape(
    List<TapeMeasurementEntity> measurements,
  ) {
    if (_filterType == 'scale') {
      return const <TapeMeasurementEntity>[];
    }
    return measurements
        .where((TapeMeasurementEntity item) => _dateMatches(item.dateKey))
        .toList();
  }

  bool _dateMatches(String dateKey) {
    if (_filterFrom == null && _filterTo == null) {
      return true;
    }
    final DateTime date = DateTime.parse(dateKey);
    if (_filterFrom != null && _filterTo == null) {
      return _dateKey(date) == _dateKey(_filterFrom!);
    }
    if (_filterFrom != null && date.isBefore(_filterFrom!)) {
      return false;
    }
    if (_filterTo != null && date.isAfter(_filterTo!)) {
      return false;
    }
    return true;
  }

  Future<void> _pickFilterDate({required bool isFrom}) async {
    final DateTime initial = isFrom
        ? (_filterFrom ?? DateTime.now())
        : (_filterTo ?? _filterFrom ?? DateTime.now());
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isFrom) {
        _filterFrom = picked;
        if (_filterTo != null && _filterTo!.isBefore(picked)) {
          _filterTo = null;
        }
      } else {
        _filterTo = picked;
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _filterFrom = null;
      _filterTo = null;
      _filterType = 'all';
    });
  }
}

class _MeasurementFilterCard extends StatelessWidget {
  const _MeasurementFilterCard({
    required this.from,
    required this.to,
    required this.type,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClear,
    required this.onTypeChanged,
  });

  final DateTime? from;
  final DateTime? to;
  final String type;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onClear;
  final ValueChanged<String> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Filtri', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Tipo misurazione'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'all', child: Text('Tutte')),
              DropdownMenuItem<String>(value: 'scale', child: Text('Bilancia')),
              DropdownMenuItem<String>(value: 'tape', child: Text('Metro')),
            ],
            onChanged: (String? value) {
              if (value != null) {
                onTypeChanged(value);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickFrom,
                  icon: const Icon(Icons.event_rounded),
                  label: Text(from == null ? 'Da' : _dateKey(from!)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickTo,
                  icon: const Icon(Icons.event_available_rounded),
                  label: Text(to == null ? 'A' : _dateKey(to!)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            from != null && to == null
                ? 'Con solo la data iniziale viene cercata la data esatta.'
                : 'Con due date il filtro usa un intervallo inclusivo.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Pulisci'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showMeasurementChartsSheet(
  BuildContext context,
  MeasurementHubData data,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) {
      final List<TtChartSeries> allTapeSeries = data.tapeSeries();
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Statistiche misurazioni',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              _ChartCard(
                title: 'Peso',
                subtitle: 'Tutte le misurazioni bilancia disponibili',
                child: TtMiniLineChart(
                  points: data.weightTrend,
                  valueSuffix: 'kg',
                  height: 180,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ChartCard(
                title: 'Grasso corporeo',
                subtitle: 'Percentuale quando disponibile',
                child: TtMiniLineChart(
                  points: data.bodyFatTrend,
                  valueSuffix: '%',
                  height: 180,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ChartCard(
                title: 'Metro congiunto',
                subtitle: 'Tutte le circonferenze con almeno due dati',
                child: TtMiniMultiLineChart(
                  series: allTapeSeries,
                  valueSuffix: 'cm',
                  height: 220,
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              Text(
                'Dettaglio metro',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              if (allTapeSeries.isEmpty)
                const TtAppCard(
                  child:
                      Text('Non ci sono ancora abbastanza misurazioni metro.'),
                )
              else
                for (final TtChartSeries series in allTapeSeries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _ChartCard(
                      title: series.label,
                      subtitle: 'Trend dedicato',
                      child: TtMiniLineChart(
                        points: series.points,
                        valueSuffix: 'cm',
                      ),
                    ),
                  ),
            ],
          ),
        ),
      );
    },
  );
}

class ScaleMeasurementsScreen extends ConsumerWidget {
  const ScaleMeasurementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MeasurementHubData> data =
        ref.watch(measurementHubProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilancia'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Nuova bilancia',
            onPressed: () => _showScaleDialog(context, ref),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      bottomNavigationBar:
          const TtFoodBottomNavBar(activeItem: TtFoodNavItem.none),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(measurementHubProvider),
        ),
        data: (MeasurementHubData data) {
          if (data.scaleMeasurements.isEmpty) {
            return _EmptyList(
              message: 'Nessuna misurazione bilancia.',
              action: () => _showScaleDialog(context, ref),
            );
          }
          return ListView.separated(
            padding: _screenPadding,
            itemCount: data.scaleMeasurements.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              final ScaleMeasurementEntity item = data.scaleMeasurements[index];
              return _buildScaleTile(
                context: context,
                ref: ref,
                data: data,
                item: item,
              );
            },
          );
        },
      ),
    );
  }
}

class TapeMeasurementsScreen extends ConsumerWidget {
  const TapeMeasurementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MeasurementHubData> data =
        ref.watch(measurementHubProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metro'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Nuova metro',
            onPressed: () => _showTapeDialog(context, ref),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      bottomNavigationBar:
          const TtFoodBottomNavBar(activeItem: TtFoodNavItem.none),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(measurementHubProvider),
        ),
        data: (MeasurementHubData data) {
          return ListView(
            padding: _screenPadding,
            children: <Widget>[
              _InteractiveBodyMeasurementsCard(
                data: data,
                onRegionTap: (String code) =>
                    _showBodyRegionSheet(context, ref, data, code),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              const TtSectionHeader(title: 'Registrazioni metro'),
              const SizedBox(height: AppSpacing.md),
              if (data.tapeMeasurements.isEmpty)
                TtAppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Nessuna misurazione metro.'),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: () => _showTapeDialog(context, ref),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Registra la prima misura'),
                      ),
                    ],
                  ),
                )
              else
                for (final TapeMeasurementEntity item
                    in data.tapeMeasurements) ...<Widget>[
                  _TapeTile(
                    item: item,
                    entries: data.entriesByTapeId[item.id] ??
                        const <TapeMeasurementEntryEntity>[],
                    onTap: () => _showTapeDialog(
                      context,
                      ref,
                      existing: item,
                      existingEntries: data.entriesByTapeId[item.id] ??
                          const <TapeMeasurementEntryEntity>[],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
            ],
          );
        },
      ),
    );
  }
}

Widget _buildScaleTile({
  required BuildContext context,
  required WidgetRef ref,
  required MeasurementHubData data,
  required ScaleMeasurementEntity item,
}) {
  final WeightAnomalyEvaluation evaluation = data.weightAnomalyFor(item);
  final String? pendingConfirmationKey = evaluation.isAnomalous &&
          evaluation.confirmationKey != item.weightAnomalyConfirmationKey
      ? evaluation.confirmationKey
      : null;
  return _ScaleTile(
    item: item,
    anomalyConfirmationKey: pendingConfirmationKey,
    onTap: () => _showScaleDialog(context, ref, existing: item),
    onConfirmAnomaly: pendingConfirmationKey == null
        ? null
        : () => _confirmWeightAnomaly(
              ref,
              item,
              pendingConfirmationKey,
            ),
  );
}

void _confirmWeightAnomaly(
  WidgetRef ref,
  ScaleMeasurementEntity item,
  String confirmationKey,
) {
  item.weightAnomalyConfirmationKey = confirmationKey;
  ref.read(measurementRepositoryProvider).saveScale(item);
  ref.invalidate(measurementHubProvider);
}

class _ScaleTile extends StatelessWidget {
  const _ScaleTile({
    required this.item,
    required this.anomalyConfirmationKey,
    required this.onTap,
    required this.onConfirmAnomaly,
  });

  final ScaleMeasurementEntity item;
  final String? anomalyConfirmationKey;
  final VoidCallback onTap;
  final VoidCallback? onConfirmAnomaly;

  @override
  Widget build(BuildContext context) {
    final bool hasPendingAnomaly = anomalyConfirmationKey != null;
    final bool hasLowReliability = item.reliabilityCode == 'low';
    final Color indicatorColor = hasPendingAnomaly
        ? Colors.red.shade600
        : hasLowReliability
            ? Colors.orange.shade700
            : Colors.green.shade600;
    final String indicatorLabel = hasPendingAnomaly
        ? 'Variazione anomala non confermata'
        : hasLowReliability
            ? 'Affidabilità bassa'
            : 'Affidabilità normale';

    return TtAppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Tooltip(
                message: indicatorLabel,
                child: Semantics(
                  label: indicatorLabel,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _MetricGrid(
            metrics: <_Metric>[
              _Metric('Data', item.dateKey),
              _Metric('Peso', _fmtNullable(item.weightKg, 'kg')),
              _Metric('Grasso', _fmtNullable(item.bodyFatPercent, '%')),
              _Metric('Muscolo', _fmtNullable(item.muscleMassKg, 'kg')),
            ],
          ),
          if (item.notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(item.notes),
          ],
          if (hasPendingAnomaly) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Variazione anomala del peso, sei sicuro sia corretta?',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: onConfirmAnomaly,
                    style: TextButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    child: const Text('Sì'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tocca per modificare',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _TapeTile extends StatelessWidget {
  const _TapeTile({
    required this.item,
    required this.entries,
    required this.onTap,
  });

  final TapeMeasurementEntity item;
  final List<TapeMeasurementEntryEntity> entries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final List<TapeMeasurementEntryEntity> filled = entries
        .where((TapeMeasurementEntryEntity entry) => entry.valueCm != null)
        .toList();
    return TtAppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(item.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${item.dateKey} - ${filled.length} punti compilati',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final TapeMeasurementEntryEntity entry in filled.take(8))
                Chip(
                  label: Text(
                    '${_tapeLabel(entry.measurementCode)} ${_fmt(entry.valueCm!)} cm',
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tocca per modificare',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value);

  final String label;
  final String value;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth > 620 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 2.15,
          children: metrics.map((_Metric metric) {
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      metric.label,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metric.value,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _MeasurementSheetSection extends StatelessWidget {
  const _MeasurementSheetSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TtAppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: colors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _screenPadding,
      children: <Widget>[
        TtAppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Errore', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(error.toString()),
              const SizedBox(height: AppSpacing.md),
              TtPrimaryButton(
                label: 'Riprova',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({
    required this.message,
    required this.action,
  });

  final String message;
  final VoidCallback action;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _screenPadding,
      children: <Widget>[
        TtAppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(message),
              const SizedBox(height: AppSpacing.md),
              TtPrimaryButton(
                label: 'Inserisci misurazione',
                icon: Icons.add_rounded,
                onPressed: action,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _showScaleDialog(
  BuildContext context,
  WidgetRef ref, {
  ScaleMeasurementEntity? existing,
}) async {
  final String today = _dateKey(DateTime.now());
  final TextEditingController date =
      TextEditingController(text: existing?.dateKey ?? today);
  final TextEditingController weight =
      TextEditingController(text: existing?.weightKg?.toString() ?? '');
  final TextEditingController bodyFat =
      TextEditingController(text: existing?.bodyFatPercent?.toString() ?? '');
  final TextEditingController muscle =
      TextEditingController(text: existing?.muscleMassKg?.toString() ?? '');
  final TextEditingController water =
      TextEditingController(text: existing?.waterPercent?.toString() ?? '');
  final TextEditingController bone =
      TextEditingController(text: existing?.boneMassKg?.toString() ?? '');
  final TextEditingController visceral =
      TextEditingController(text: existing?.visceralFat?.toString() ?? '');
  final TextEditingController subcutaneous = TextEditingController(
      text: existing?.subcutaneousFatPercent?.toString() ?? '');
  final TextEditingController bmr = TextEditingController(
      text: existing?.basalMetabolismKcal?.toString() ?? '');
  final TextEditingController bmi =
      TextEditingController(text: existing?.bmi?.toString() ?? '');
  final TextEditingController metabolicAge =
      TextEditingController(text: existing?.metabolicAge?.toString() ?? '');
  final TextEditingController physique =
      TextEditingController(text: existing?.physiqueRating ?? '');
  final TextEditingController time =
      TextEditingController(text: existing?.measurementTime ?? '');
  final TextEditingController device =
      TextEditingController(text: existing?.device ?? '');
  String reliabilityCode =
      _normalizeScaleReliability(existing?.reliabilityCode);
  final TextEditingController notes =
      TextEditingController(text: existing?.notes ?? '');
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final String? action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) {
      return FractionallySizedBox(
        heightFactor: 0.92,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.sm,
                  AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        existing == null
                            ? 'Nuova bilancia'
                            : 'Modifica bilancia',
                        style: Theme.of(sheetContext).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Chiudi',
                      onPressed: () => Navigator.of(sheetContext).pop('cancel'),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Form(
                  key: formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    children: <Widget>[
                      _MeasurementSheetSection(
                        icon: Icons.monitor_weight_outlined,
                        title: 'Dati principali',
                        children: <Widget>[
                          _field(
                            date,
                            'Data',
                            isRequired: true,
                            readOnly: true,
                            suffixIcon:
                                const Icon(Icons.calendar_today_outlined),
                            onTap: () async {
                              final DateTime initialDate =
                                  DateTime.tryParse(date.text.trim()) ??
                                      DateTime.now();
                              final DateTime? picked = await showDatePicker(
                                context: sheetContext,
                                initialDate: initialDate,
                                firstDate: DateTime(1900),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                date.text = _dateKey(picked);
                              }
                            },
                          ),
                          _field(
                            weight,
                            'Peso kg',
                            isRequired: true,
                            keyboardType: TextInputType.number,
                          ),
                          _field(
                            time,
                            'Ora misurazione',
                            readOnly: true,
                            suffixIcon: const Icon(Icons.access_time_rounded),
                            onTap: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: sheetContext,
                                initialTime: _parseTimeOfDay(time.text) ??
                                    TimeOfDay.now(),
                              );
                              if (picked != null) {
                                time.text = _timeKey(picked);
                              }
                            },
                          ),
                        ],
                      ),
                      _MeasurementSheetSection(
                        icon: Icons.pie_chart_outline_rounded,
                        title: 'Composizione corporea',
                        children: <Widget>[
                          _field(bodyFat, 'Grasso %',
                              keyboardType: TextInputType.number),
                          _field(muscle, 'Massa muscolare kg',
                              keyboardType: TextInputType.number),
                          _field(water, 'Acqua %',
                              keyboardType: TextInputType.number),
                          _field(bone, 'Massa ossea kg',
                              keyboardType: TextInputType.number),
                          _field(visceral, 'Grasso viscerale',
                              keyboardType: TextInputType.number),
                          _field(subcutaneous, 'Grasso sottocutaneo %',
                              keyboardType: TextInputType.number),
                        ],
                      ),
                      _MeasurementSheetSection(
                        icon: Icons.device_thermostat_rounded,
                        title: 'Metabolismo e sorgente',
                        children: <Widget>[
                          _field(bmr, 'Metabolismo basale kcal',
                              keyboardType: TextInputType.number),
                          _field(bmi, 'BMI',
                              keyboardType: TextInputType.number),
                          _field(metabolicAge, 'Eta metabolica',
                              keyboardType: TextInputType.number),
                          _field(physique, 'Physique rating'),
                          _field(device, 'Dispositivo'),
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.md),
                            child: DropdownButtonFormField<String>(
                              initialValue: reliabilityCode,
                              decoration: const InputDecoration(
                                labelText: 'Affidabilità',
                              ),
                              items: const <DropdownMenuItem<String>>[
                                DropdownMenuItem<String>(
                                  value: 'normal',
                                  child: Text('Normale'),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'low',
                                  child: Text('Bassa'),
                                ),
                              ],
                              onChanged: (String? value) {
                                if (value != null) {
                                  reliabilityCode = value;
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      _MeasurementSheetSection(
                        icon: Icons.notes_rounded,
                        title: 'Note',
                        children: <Widget>[
                          _field(notes, 'Note', maxLines: 3),
                        ],
                      ),
                    ],
                  ),
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
                  child: Column(
                    children: <Widget>[
                      if (existing != null) ...<Widget>[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(sheetContext).colorScheme.error,
                              side: BorderSide(
                                color: Theme.of(sheetContext).colorScheme.error,
                              ),
                            ),
                            onPressed: () async {
                              final bool? confirmed = await showDialog<bool>(
                                context: sheetContext,
                                builder: (BuildContext dialogContext) {
                                  return AlertDialog(
                                    title: const Text('Elimina misurazione'),
                                    content: const Text(
                                      'La misurazione verrà rimossa. '
                                      'Questa operazione non modifica le altre '
                                      'misurazioni salvate.',
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext)
                                                .pop(false),
                                        child: const Text('Annulla'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              Theme.of(dialogContext)
                                                  .colorScheme
                                                  .error,
                                          foregroundColor:
                                              Theme.of(dialogContext)
                                                  .colorScheme
                                                  .onError,
                                        ),
                                        onPressed: () =>
                                            Navigator.of(dialogContext)
                                                .pop(true),
                                        child: const Text('Elimina'),
                                      ),
                                    ],
                                  );
                                },
                              );
                              if (confirmed == true && sheetContext.mounted) {
                                Navigator.of(sheetContext).pop('delete');
                              }
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Elimina misurazione'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(sheetContext).pop('cancel'),
                              child: const Text('Annulla'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                if (formKey.currentState?.validate() ?? false) {
                                  Navigator.of(sheetContext).pop('save');
                                }
                              },
                              child: const Text('Salva'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (action == 'delete' && existing != null) {
    ref.read(measurementRepositoryProvider).softDeleteScale(existing);
    ref.invalidate(measurementHubProvider);
    return;
  }
  if (action != 'save') {
    return;
  }
  final String dateKey = date.text.trim();
  ref.read(foodPlanningServiceProvider).ensureDay(dateKey);
  final repository = ref.read(measurementRepositoryProvider);
  final ScaleMeasurementEntity? storedMeasurement =
      existing ?? repository.findScaleByDate(dateKey);
  final String previousDateKey = storedMeasurement?.dateKey ?? '';
  final double? previousWeightKg = storedMeasurement?.weightKg;
  final ScaleMeasurementEntity measurement = storedMeasurement ??
      ScaleMeasurementEntity(
        uuid: '',
        dateKey: dateKey,
        title: 'Bilancia - $dateKey',
        createdAtEpochMs: 0,
        updatedAtEpochMs: 0,
      );
  measurement.dateKey = dateKey;
  measurement.title = 'Bilancia - $dateKey';
  measurement.weightKg = _toDouble(weight.text);
  if (storedMeasurement != null &&
      (previousDateKey != measurement.dateKey ||
          previousWeightKg != measurement.weightKg)) {
    measurement.weightAnomalyConfirmationKey = '';
  }
  measurement.bodyFatPercent = _toDouble(bodyFat.text);
  measurement.muscleMassKg = _toDouble(muscle.text);
  measurement.waterPercent = _toDouble(water.text);
  measurement.boneMassKg = _toDouble(bone.text);
  measurement.visceralFat = _toDouble(visceral.text);
  measurement.subcutaneousFatPercent = _toDouble(subcutaneous.text);
  measurement.basalMetabolismKcal = _toDouble(bmr.text);
  measurement.bmi = _toDouble(bmi.text);
  measurement.metabolicAge = _toDouble(metabolicAge.text);
  measurement.physiqueRating = physique.text.trim();
  measurement.measurementTime = time.text.trim();
  measurement.device = device.text.trim();
  measurement.reliabilityCode = reliabilityCode;
  measurement.notes = notes.text.trim();
  repository.saveScale(measurement);
  ref.invalidate(measurementHubProvider);
}

Future<void> _showTapeDialog(
  BuildContext context,
  WidgetRef ref, {
  TapeMeasurementEntity? existing,
  List<TapeMeasurementEntryEntity> existingEntries =
      const <TapeMeasurementEntryEntity>[],
}) async {
  final String today = _dateKey(DateTime.now());
  final TextEditingController date =
      TextEditingController(text: existing?.dateKey ?? today);
  final TextEditingController notes =
      TextEditingController(text: existing?.notes ?? '');
  final Map<String, TapeMeasurementEntryEntity> entryByCode =
      <String, TapeMeasurementEntryEntity>{
    for (final TapeMeasurementEntryEntity entry in existingEntries)
      entry.measurementCode: entry,
  };
  final Map<String, TextEditingController> controllers =
      <String, TextEditingController>{
    for (final String code in tapeMeasurementCodes)
      code: TextEditingController(
        text: entryByCode[code]?.valueCm?.toString() ?? '',
      ),
  };
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final bool? saved = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) {
      return FractionallySizedBox(
        heightFactor: 0.92,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.sm,
                  AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        existing == null ? 'Nuova metro' : 'Modifica metro',
                        style: Theme.of(sheetContext).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Chiudi',
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Form(
                  key: formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    children: <Widget>[
                      _MeasurementSheetSection(
                        icon: Icons.event_rounded,
                        title: 'Misurazione',
                        children: <Widget>[
                          _field(date, 'Data', isRequired: true),
                        ],
                      ),
                      _MeasurementSheetSection(
                        icon: Icons.accessibility_new_rounded,
                        title: 'Tronco',
                        children: <Widget>[
                          for (final String code in const <String>[
                            'neck_cm',
                            'shoulders_cm',
                            'chest_cm',
                            'waist_cm',
                            'abdomen_cm',
                            'hips_cm',
                          ])
                            _field(
                              controllers[code]!,
                              _tapeLabel(code),
                              keyboardType: TextInputType.number,
                            ),
                        ],
                      ),
                      _MeasurementSheetSection(
                        icon: Icons.fitness_center_rounded,
                        title: 'Braccia',
                        children: <Widget>[
                          for (final String code in const <String>[
                            'left_arm_cm',
                            'right_arm_cm',
                            'left_forearm_cm',
                            'right_forearm_cm',
                          ])
                            _field(
                              controllers[code]!,
                              _tapeLabel(code),
                              keyboardType: TextInputType.number,
                            ),
                        ],
                      ),
                      _MeasurementSheetSection(
                        icon: Icons.directions_walk_rounded,
                        title: 'Gambe',
                        children: <Widget>[
                          for (final String code in const <String>[
                            'left_thigh_cm',
                            'right_thigh_cm',
                            'left_calf_cm',
                            'right_calf_cm',
                          ])
                            _field(
                              controllers[code]!,
                              _tapeLabel(code),
                              keyboardType: TextInputType.number,
                            ),
                        ],
                      ),
                      _MeasurementSheetSection(
                        icon: Icons.notes_rounded,
                        title: 'Note',
                        children: <Widget>[
                          _field(notes, 'Note', maxLines: 3),
                        ],
                      ),
                    ],
                  ),
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
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          child: const Text('Annulla'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            if (formKey.currentState?.validate() ?? false) {
                              Navigator.of(sheetContext).pop(true);
                            }
                          },
                          child: const Text('Salva'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (saved != true) {
    return;
  }
  final String dateKey = date.text.trim();
  ref.read(foodPlanningServiceProvider).ensureDay(dateKey);
  ref.read(measurementRepositoryProvider).saveTapeWithEntries(
    (existing ??
        TapeMeasurementEntity(
          uuid: '',
          dateKey: dateKey,
          title: 'Metro - $dateKey',
          createdAtEpochMs: 0,
          updatedAtEpochMs: 0,
        ))
      ..dateKey = dateKey
      ..title = 'Metro - $dateKey'
      ..notes = notes.text.trim(),
    <TapeMeasurementEntryEntity>[
      for (int index = 0; index < tapeMeasurementCodes.length; index += 1)
        TapeMeasurementEntryEntity(
          uuid: '',
          measurementCode: tapeMeasurementCodes[index],
          valueCm: _toDouble(controllers[tapeMeasurementCodes[index]]!.text),
          position: index,
          createdAtEpochMs: 0,
          updatedAtEpochMs: 0,
        ),
    ],
  );
  ref.invalidate(measurementHubProvider);
}

Widget _field(
  TextEditingController controller,
  String label, {
  bool isRequired = false,
  TextInputType? keyboardType,
  int maxLines = 1,
  bool readOnly = false,
  VoidCallback? onTap,
  Widget? suffixIcon,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      validator: isRequired
          ? (String? value) => value == null || value.trim().isEmpty
              ? 'Campo obbligatorio'
              : null
          : null,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        suffixIcon: suffixIcon,
      ),
    ),
  );
}

class _InteractiveBodyMeasurementsCard extends StatefulWidget {
  const _InteractiveBodyMeasurementsCard({
    required this.data,
    required this.onRegionTap,
  });

  final MeasurementHubData data;
  final ValueChanged<String> onRegionTap;

  @override
  State<_InteractiveBodyMeasurementsCard> createState() =>
      _InteractiveBodyMeasurementsCardState();
}

class _InteractiveBodyMeasurementsCardState
    extends State<_InteractiveBodyMeasurementsCard> {
  String? _hoveredCode;

  @override
  Widget build(BuildContext context) {
    final Map<String, double> latestValues = <String, double>{
      for (final TapeMeasurementEntryEntity entry
          in widget.data.latestTapeEntries())
        if (entry.valueCm != null) entry.measurementCode: entry.valueCm!,
    };
    final Set<String> availableCodes = latestValues.keys.toSet();

    final Widget bodyMap = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 330),
      child: AspectRatio(
        aspectRatio: 0.64,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size size = constraints.biggest;
            return Semantics(
              image: true,
              label: context.l10n.bodyMapSemantics,
              child: MouseRegion(
                onHover: (PointerHoverEvent event) {
                  final String? code = _bodyRegionAt(event.localPosition, size);
                  if (code != _hoveredCode) {
                    setState(() => _hoveredCode = code);
                  }
                },
                onExit: (_) {
                  if (_hoveredCode != null) {
                    setState(() => _hoveredCode = null);
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (TapUpDetails details) {
                    final String? code =
                        _bodyRegionAt(details.localPosition, size);
                    if (code != null) {
                      widget.onRegionTap(code);
                    }
                  },
                  child: CustomPaint(
                    painter: _BodyMeasurementsPainter(
                      availableCodes: availableCodes,
                      latestValues: latestValues,
                      highlightedCode: _hoveredCode,
                      colorScheme: Theme.of(context).colorScheme,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    final Widget regionList = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final String code in tapeMeasurementCodes)
          ActionChip(
            avatar: Icon(
              latestValues.containsKey(code)
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: latestValues.containsKey(code)
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
            label: Text(
              latestValues.containsKey(code)
                  ? '${_localizedBodyLabel(context, code)} · '
                      '${latestValues[code]!.toStringAsFixed(1)} cm'
                  : _localizedBodyLabel(context, code),
            ),
            onPressed: () => widget.onRegionTap(code),
          ),
      ],
    );

    return TtAppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.accessibility_new_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.interactiveBody,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      context.l10n.interactiveBodySubtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth >= 720) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: Center(child: bodyMap)),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(child: regionList),
                  ],
                );
              }
              return Column(
                children: [
                  Center(child: bodyMap),
                  const SizedBox(height: AppSpacing.lg),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: regionList,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _BodyLegendChip(
                label: context.l10n.measurementAvailable,
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              _BodyLegendChip(
                label: context.l10n.noData,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BodyLegendChip extends StatelessWidget {
  const _BodyLegendChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _BodyMeasurementsPainter extends CustomPainter {
  const _BodyMeasurementsPainter({
    required this.availableCodes,
    required this.latestValues,
    required this.highlightedCode,
    required this.colorScheme,
  });

  final Set<String> availableCodes;
  final Map<String, double> latestValues;
  final String? highlightedCode;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;

    final RRect stage = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.035, h * 0.018, w * 0.93, h * 0.965),
      Radius.circular(w * 0.09),
    );
    final Paint stagePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.primaryContainer.withValues(alpha: 0.30),
          colorScheme.surfaceContainerHighest.withValues(alpha: 0.64),
          colorScheme.tertiaryContainer.withValues(alpha: 0.20),
        ],
      ).createShader(stage.outerRect);
    canvas.drawRRect(stage, stagePaint);

    final Paint guidePaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.38)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(cx, h * 0.07),
      Offset(cx, h * 0.955),
      guidePaint,
    );

    final Paint bodyFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.primaryContainer.withValues(alpha: 0.92),
          colorScheme.secondaryContainer.withValues(alpha: 0.86),
        ],
      ).createShader(Rect.fromLTWH(w * 0.18, h * 0.07, w * 0.64, h * 0.88));
    final Paint outline = Paint()
      ..color = colorScheme.outline.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeJoin = StrokeJoin.round;

    final Path silhouette = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(cx, h * 0.105),
          width: w * 0.19,
          height: h * 0.12,
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, h * 0.185),
            width: w * 0.09,
            height: h * 0.07,
          ),
          Radius.circular(w * 0.025),
        ),
      );

    final Path torso = Path()
      ..moveTo(w * 0.34, h * 0.205)
      ..cubicTo(w * 0.29, h * 0.25, w * 0.31, h * 0.34, w * 0.35, h * 0.42)
      ..cubicTo(w * 0.38, h * 0.49, w * 0.37, h * 0.57, w * 0.35, h * 0.62)
      ..quadraticBezierTo(cx, h * 0.675, w * 0.65, h * 0.62)
      ..cubicTo(w * 0.63, h * 0.57, w * 0.62, h * 0.49, w * 0.65, h * 0.42)
      ..cubicTo(w * 0.69, h * 0.34, w * 0.71, h * 0.25, w * 0.66, h * 0.205)
      ..quadraticBezierTo(cx, h * 0.17, w * 0.34, h * 0.205)
      ..close();
    silhouette.addPath(torso, Offset.zero);

    silhouette.addPath(_leftArmPath(w, h), Offset.zero);
    silhouette.addPath(_rightArmPath(w, h), Offset.zero);
    silhouette.addPath(_leftLegPath(w, h), Offset.zero);
    silhouette.addPath(_rightLegPath(w, h), Offset.zero);

    canvas.drawShadow(
      silhouette,
      colorScheme.shadow.withValues(alpha: 0.24),
      12,
      false,
    );
    canvas.drawPath(silhouette, bodyFill);
    canvas.drawPath(silhouette, outline);

    final Paint shortsPaint = Paint()
      ..color = colorScheme.secondary.withValues(alpha: 0.84);
    final Path shorts = Path()
      ..moveTo(w * 0.35, h * 0.585)
      ..lineTo(w * 0.65, h * 0.585)
      ..lineTo(w * 0.61, h * 0.69)
      ..lineTo(cx, h * 0.665)
      ..lineTo(w * 0.39, h * 0.69)
      ..close();
    canvas.drawPath(shorts, shortsPaint);
    canvas.drawPath(shorts, outline);

    final Paint anatomy = Paint()
      ..color = colorScheme.outline.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.43, h * 0.31),
        width: w * 0.15,
        height: h * 0.07,
      ),
      0.15,
      2.6,
      false,
      anatomy,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.57, h * 0.31),
        width: w * 0.15,
        height: h * 0.07,
      ),
      0.4,
      2.6,
      false,
      anatomy,
    );
    for (final double y in <double>[0.405, 0.455, 0.505]) {
      canvas.drawLine(
        Offset(w * 0.43, h * y),
        Offset(w * 0.57, h * y),
        anatomy,
      );
    }

    _drawBand(canvas, 'neck_cm', w * 0.445, w * 0.555, h * 0.185);
    _drawBand(canvas, 'shoulders_cm', w * 0.31, w * 0.69, h * 0.235);
    _drawBand(canvas, 'chest_cm', w * 0.33, w * 0.67, h * 0.325);
    _drawBand(canvas, 'waist_cm', w * 0.385, w * 0.615, h * 0.455);
    _drawBand(canvas, 'abdomen_cm', w * 0.37, w * 0.63, h * 0.515);
    _drawBand(canvas, 'hips_cm', w * 0.345, w * 0.655, h * 0.585);

    _drawBand(canvas, 'left_arm_cm', w * 0.235, w * 0.325, h * 0.335);
    _drawBand(canvas, 'right_arm_cm', w * 0.675, w * 0.765, h * 0.335);
    _drawBand(canvas, 'left_forearm_cm', w * 0.205, w * 0.285, h * 0.505);
    _drawBand(canvas, 'right_forearm_cm', w * 0.715, w * 0.795, h * 0.505);

    _drawBand(canvas, 'left_thigh_cm', w * 0.37, w * 0.485, h * 0.735);
    _drawBand(canvas, 'right_thigh_cm', w * 0.515, w * 0.63, h * 0.735);
    _drawBand(canvas, 'left_calf_cm', w * 0.39, w * 0.475, h * 0.865);
    _drawBand(canvas, 'right_calf_cm', w * 0.525, w * 0.61, h * 0.865);

    if (highlightedCode != null && latestValues[highlightedCode] != null) {
      _drawValueCallout(
          canvas, size, highlightedCode!, latestValues[highlightedCode]!);
    }
  }

  Path _leftArmPath(double w, double h) {
    return Path()
      ..moveTo(w * 0.34, h * 0.22)
      ..cubicTo(w * 0.29, h * 0.25, w * 0.26, h * 0.34, w * 0.245, h * 0.43)
      ..cubicTo(w * 0.225, h * 0.51, w * 0.20, h * 0.59, w * 0.215, h * 0.64)
      ..cubicTo(w * 0.225, h * 0.675, w * 0.265, h * 0.67, w * 0.275, h * 0.63)
      ..cubicTo(w * 0.29, h * 0.54, w * 0.30, h * 0.46, w * 0.325, h * 0.38)
      ..cubicTo(w * 0.35, h * 0.30, w * 0.38, h * 0.245, w * 0.40, h * 0.22)
      ..close();
  }

  Path _rightArmPath(double w, double h) {
    return Path()
      ..moveTo(w * 0.66, h * 0.22)
      ..cubicTo(w * 0.71, h * 0.25, w * 0.74, h * 0.34, w * 0.755, h * 0.43)
      ..cubicTo(w * 0.775, h * 0.51, w * 0.80, h * 0.59, w * 0.785, h * 0.64)
      ..cubicTo(w * 0.775, h * 0.675, w * 0.735, h * 0.67, w * 0.725, h * 0.63)
      ..cubicTo(w * 0.71, h * 0.54, w * 0.70, h * 0.46, w * 0.675, h * 0.38)
      ..cubicTo(w * 0.65, h * 0.30, w * 0.62, h * 0.245, w * 0.60, h * 0.22)
      ..close();
  }

  Path _leftLegPath(double w, double h) {
    return Path()
      ..moveTo(w * 0.365, h * 0.61)
      ..cubicTo(w * 0.355, h * 0.71, w * 0.37, h * 0.80, w * 0.385, h * 0.89)
      ..lineTo(w * 0.375, h * 0.945)
      ..quadraticBezierTo(w * 0.41, h * 0.97, w * 0.465, h * 0.945)
      ..cubicTo(w * 0.46, h * 0.84, w * 0.475, h * 0.75, w * 0.49, h * 0.655)
      ..lineTo(w * 0.50, h * 0.625)
      ..close();
  }

  Path _rightLegPath(double w, double h) {
    return Path()
      ..moveTo(w * 0.635, h * 0.61)
      ..cubicTo(w * 0.645, h * 0.71, w * 0.63, h * 0.80, w * 0.615, h * 0.89)
      ..lineTo(w * 0.625, h * 0.945)
      ..quadraticBezierTo(w * 0.59, h * 0.97, w * 0.535, h * 0.945)
      ..cubicTo(w * 0.54, h * 0.84, w * 0.525, h * 0.75, w * 0.51, h * 0.655)
      ..lineTo(w * 0.50, h * 0.625)
      ..close();
  }

  void _drawBand(
    Canvas canvas,
    String code,
    double left,
    double right,
    double y,
  ) {
    final bool available = availableCodes.contains(code);
    final bool highlighted = highlightedCode == code;
    final Color color = highlighted
        ? colorScheme.tertiary
        : available
            ? colorScheme.primary
            : colorScheme.outline.withValues(alpha: 0.42);
    final Paint glow = Paint()
      ..color = color.withValues(
          alpha: highlighted
              ? 0.25
              : available
                  ? 0.13
                  : 0.04)
      ..strokeWidth = highlighted
          ? 12
          : available
              ? 8
              : 5
      ..strokeCap = StrokeCap.round;
    final Paint line = Paint()
      ..color = color
      ..strokeWidth = highlighted
          ? 4.2
          : available
              ? 3.0
              : 1.35
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(left, y), Offset(right, y), glow);
    canvas.drawLine(Offset(left, y), Offset(right, y), line);
    canvas.drawCircle(
        Offset(left, y), highlighted ? 4.8 : 3.2, Paint()..color = color);
    canvas.drawCircle(
        Offset(right, y), highlighted ? 4.8 : 3.2, Paint()..color = color);
  }

  void _drawValueCallout(
    Canvas canvas,
    Size size,
    String code,
    double value,
  ) {
    _BodyRegionDefinition? region;
    for (final _BodyRegionDefinition item in _bodyRegions) {
      if (item.code == code) {
        region = item;
        break;
      }
    }
    if (region == null) {
      return;
    }
    final Rect rect = region.rectFor(size);
    final bool placeLeft = rect.center.dx < size.width / 2;
    final Offset anchor = placeLeft ? rect.centerLeft : rect.centerRight;
    final double targetX = placeLeft ? size.width * 0.075 : size.width * 0.925;
    final Offset target = Offset(targetX, anchor.dy);
    final Paint callout = Paint()
      ..color = colorScheme.tertiary
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(anchor, target, callout);

    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: '${value.toStringAsFixed(1)} cm',
        style: TextStyle(
          color: colorScheme.onTertiaryContainer,
          backgroundColor: colorScheme.tertiaryContainer,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final double x = placeLeft ? target.dx : target.dx - painter.width;
    painter.paint(canvas, Offset(x, target.dy - painter.height - 3));
  }

  @override
  bool shouldRepaint(covariant _BodyMeasurementsPainter oldDelegate) {
    return oldDelegate.highlightedCode != highlightedCode ||
        !setEquals(oldDelegate.availableCodes, availableCodes) ||
        !mapEquals(oldDelegate.latestValues, latestValues) ||
        oldDelegate.colorScheme != colorScheme;
  }
}

class _BodyRegionDefinition {
  const _BodyRegionDefinition(
    this.code,
    this.left,
    this.top,
    this.right,
    this.bottom,
  );

  final String code;
  final double left;
  final double top;
  final double right;
  final double bottom;

  Rect rectFor(Size size) => Rect.fromLTRB(
        size.width * left,
        size.height * top,
        size.width * right,
        size.height * bottom,
      );
}

const List<_BodyRegionDefinition> _bodyRegions = <_BodyRegionDefinition>[
  _BodyRegionDefinition('neck_cm', 0.42, 0.14, 0.58, 0.21),
  _BodyRegionDefinition('shoulders_cm', 0.27, 0.19, 0.73, 0.27),
  _BodyRegionDefinition('chest_cm', 0.31, 0.27, 0.69, 0.37),
  _BodyRegionDefinition('waist_cm', 0.35, 0.39, 0.65, 0.48),
  _BodyRegionDefinition('abdomen_cm', 0.34, 0.47, 0.66, 0.55),
  _BodyRegionDefinition('hips_cm', 0.31, 0.54, 0.69, 0.64),
  _BodyRegionDefinition('left_arm_cm', 0.20, 0.25, 0.35, 0.42),
  _BodyRegionDefinition('right_arm_cm', 0.65, 0.25, 0.80, 0.42),
  _BodyRegionDefinition('left_forearm_cm', 0.17, 0.42, 0.31, 0.62),
  _BodyRegionDefinition('right_forearm_cm', 0.69, 0.42, 0.83, 0.62),
  _BodyRegionDefinition('left_thigh_cm', 0.34, 0.65, 0.50, 0.80),
  _BodyRegionDefinition('right_thigh_cm', 0.50, 0.65, 0.66, 0.80),
  _BodyRegionDefinition('left_calf_cm', 0.35, 0.80, 0.49, 0.96),
  _BodyRegionDefinition('right_calf_cm', 0.51, 0.80, 0.65, 0.96),
];

String? _bodyRegionAt(Offset position, Size size) {
  for (final _BodyRegionDefinition region in _bodyRegions.reversed) {
    if (region.rectFor(size).inflate(7).contains(position)) {
      return region.code;
    }
  }
  return null;
}

String _localizedBodyLabel(BuildContext context, String code) {
  final l10n = context.l10n;
  return switch (code) {
    'neck_cm' => l10n.neck,
    'shoulders_cm' => l10n.shoulders,
    'chest_cm' => l10n.chest,
    'waist_cm' => l10n.waist,
    'abdomen_cm' => l10n.abdomen,
    'hips_cm' => l10n.hips,
    'left_arm_cm' => l10n.leftArm,
    'right_arm_cm' => l10n.rightArm,
    'left_forearm_cm' => l10n.leftForearm,
    'right_forearm_cm' => l10n.rightForearm,
    'left_thigh_cm' => l10n.leftThigh,
    'right_thigh_cm' => l10n.rightThigh,
    'left_calf_cm' => l10n.leftCalf,
    'right_calf_cm' => l10n.rightCalf,
    _ => code,
  };
}

class _BodyMeasurementPoint {
  const _BodyMeasurementPoint({
    required this.dateKey,
    required this.valueCm,
    required this.reliabilityCode,
  });

  final String dateKey;
  final double valueCm;
  final String reliabilityCode;
}

List<_BodyMeasurementPoint> _historyForBodyCode(
  MeasurementHubData data,
  String code,
) {
  final List<_BodyMeasurementPoint> history = <_BodyMeasurementPoint>[];
  for (final TapeMeasurementEntity measurement in data.tapeMeasurements) {
    final List<TapeMeasurementEntryEntity> entries =
        data.entriesByTapeId[measurement.id] ??
            const <TapeMeasurementEntryEntity>[];
    for (final TapeMeasurementEntryEntity entry in entries) {
      if (entry.measurementCode == code && entry.valueCm != null) {
        history.add(
          _BodyMeasurementPoint(
            dateKey: measurement.dateKey,
            valueCm: entry.valueCm!,
            reliabilityCode: measurement.reliabilityCode,
          ),
        );
        break;
      }
    }
  }
  history.sort(
    (_BodyMeasurementPoint a, _BodyMeasurementPoint b) =>
        b.dateKey.compareTo(a.dateKey),
  );
  return history;
}

Future<void> _showBodyRegionSheet(
  BuildContext context,
  WidgetRef ref,
  MeasurementHubData data,
  String code,
) async {
  final List<_BodyMeasurementPoint> history = _historyForBodyCode(data, code);
  final _BodyMeasurementPoint? latest = history.isEmpty ? null : history.first;
  final _BodyMeasurementPoint? previous =
      history.length < 2 ? null : history[1];
  final double? delta = latest == null || previous == null
      ? null
      : latest.valueCm - previous.valueCm;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) {
      return FractionallySizedBox(
        heightFactor: 0.5,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _tapeLabel(code),
                          style: Theme.of(sheetContext).textTheme.headlineSmall,
                        ),
                        Text(
                          latest == null
                              ? 'Nessuna misura registrata'
                              : 'Ultima misura ${latest.dateKey}',
                          style: Theme.of(sheetContext).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chiudi',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                children: <Widget>[
                  if (latest != null)
                    _MetricGrid(
                      metrics: <_Metric>[
                        _Metric(
                          'Ultima',
                          '${latest.valueCm.toStringAsFixed(1)} cm',
                        ),
                        _Metric(
                          'Precedente',
                          previous == null
                              ? 'n/d'
                              : '${previous.valueCm.toStringAsFixed(1)} cm',
                        ),
                        _Metric(
                          'Variazione',
                          delta == null
                              ? 'n/d'
                              : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} cm',
                        ),
                        _Metric('Affidabilità', latest.reliabilityCode),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Storico',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (history.isEmpty)
                    const Text('Nessun valore disponibile per questa zona.')
                  else
                    for (final _BodyMeasurementPoint point in history.take(8))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(point.dateKey),
                        subtitle:
                            Text('Affidabilità: ${point.reliabilityCode}'),
                        trailing: Text(
                          '${point.valueCm.toStringAsFixed(1)} cm',
                          style: Theme.of(sheetContext).textTheme.titleMedium,
                        ),
                      ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await Future<void>.delayed(
                          const Duration(milliseconds: 180));
                      if (context.mounted) {
                        await _showTapeDialog(context, ref);
                      }
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Registra nuova misura'),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

const List<String> tapeMeasurementCodes = <String>[
  'neck_cm',
  'shoulders_cm',
  'chest_cm',
  'waist_cm',
  'abdomen_cm',
  'hips_cm',
  'left_arm_cm',
  'right_arm_cm',
  'left_forearm_cm',
  'right_forearm_cm',
  'left_thigh_cm',
  'right_thigh_cm',
  'left_calf_cm',
  'right_calf_cm',
];

String _tapeLabel(String code) {
  return const <String, String>{
        'neck_cm': 'Collo',
        'shoulders_cm': 'Spalle',
        'chest_cm': 'Torace',
        'waist_cm': 'Vita',
        'abdomen_cm': 'Addome',
        'hips_cm': 'Fianchi',
        'left_arm_cm': 'Braccio sx',
        'right_arm_cm': 'Braccio dx',
        'left_forearm_cm': 'Avambraccio sx',
        'right_forearm_cm': 'Avambraccio dx',
        'left_thigh_cm': 'Coscia sx',
        'right_thigh_cm': 'Coscia dx',
        'left_calf_cm': 'Polpaccio sx',
        'right_calf_cm': 'Polpaccio dx',
      }[code] ??
      code;
}

EdgeInsets get _screenPadding {
  return const EdgeInsets.fromLTRB(
    AppSpacing.screenHorizontal,
    AppSpacing.screenVertical,
    AppSpacing.screenHorizontal,
    AppSpacing.xxxl,
  );
}

String _scaleIdentity(ScaleMeasurementEntity item) {
  final String uuid = item.uuid.trim();
  return uuid.isNotEmpty ? uuid : 'id:${item.id}';
}

String _normalizeScaleReliability(String? value) {
  final String normalized = value?.trim().toLowerCase() ?? '';
  return normalized == 'low' || normalized == 'bassa' ? 'low' : 'normal';
}

String _dateKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

TimeOfDay? _parseTimeOfDay(String value) {
  final List<String> parts = value.trim().split(':');
  if (parts.length != 2) {
    return null;
  }
  final int? hour = int.tryParse(parts[0]);
  final int? minute = int.tryParse(parts[1]);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return null;
  }
  return TimeOfDay(hour: hour, minute: minute);
}

String _timeKey(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

String _fmtNullable(double? value, String suffix) {
  if (value == null) {
    return 'n/d';
  }
  return '${_fmt(value)} $suffix';
}

String _fmt(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

double? _toDouble(String value) {
  final String normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) {
    return null;
  }
  return double.tryParse(normalized);
}
