import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/objectbox_providers.dart';
import '../../../shared/widgets/tt_app_card.dart';
import '../../../shared/widgets/tt_global_nav_fab.dart';
import '../../../shared/widgets/tt_mini_charts.dart';
import '../../../shared/widgets/tt_primary_button.dart';
import '../../../shared/widgets/tt_section_header.dart';
import '../data/entities/nutrition_tracking_entities.dart';
import '../data/services/food_planning_service.dart';

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
                for (final ScaleMeasurementEntity item
                    in filteredScale.take(6))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _ScaleTile(
                      item: item,
                      onTap: () =>
                          _showScaleDialog(context, ref, existing: item),
                    ),
                  ),
                for (final TapeMeasurementEntity item
                    in filteredTape.take(6))
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
              return _ScaleTile(
                item: item,
                onTap: () => _showScaleDialog(context, ref, existing: item),
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
          if (data.tapeMeasurements.isEmpty) {
            return _EmptyList(
              message: 'Nessuna misurazione metro.',
              action: () => _showTapeDialog(context, ref),
            );
          }
          return ListView.separated(
            padding: _screenPadding,
            itemCount: data.tapeMeasurements.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              final TapeMeasurementEntity item = data.tapeMeasurements[index];
              return _TapeTile(
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
              );
            },
          );
        },
      ),
    );
  }
}

class _ScaleTile extends StatelessWidget {
  const _ScaleTile({
    required this.item,
    required this.onTap,
  });

  final ScaleMeasurementEntity item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(item.title, style: Theme.of(context).textTheme.titleLarge),
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
  final TextEditingController reliability =
      TextEditingController(text: existing?.reliabilityCode ?? 'normal');
  final TextEditingController notes =
      TextEditingController(text: existing?.notes ?? '');
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
                        existing == null
                            ? 'Nuova bilancia'
                            : 'Modifica bilancia',
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
                        icon: Icons.monitor_weight_outlined,
                        title: 'Dati principali',
                        children: <Widget>[
                          _field(date, 'Data', isRequired: true),
                          _field(
                            weight,
                            'Peso kg',
                            isRequired: true,
                            keyboardType: TextInputType.number,
                          ),
                          _field(time, 'Ora misurazione'),
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
                          _field(reliability, 'Affidabilita'),
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
  final repository = ref.read(measurementRepositoryProvider);
  final ScaleMeasurementEntity measurement = existing ??
      repository.findScaleByDate(dateKey) ??
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
  measurement.reliabilityCode =
      reliability.text.trim().isEmpty ? 'normal' : reliability.text.trim();
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
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: isRequired
          ? (String? value) => value == null || value.trim().isEmpty
              ? 'Campo obbligatorio'
              : null
          : null,
      decoration: InputDecoration(labelText: label),
    ),
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

String _dateKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
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
