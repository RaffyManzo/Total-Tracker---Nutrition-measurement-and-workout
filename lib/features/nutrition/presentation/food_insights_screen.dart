import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:objectbox/objectbox.dart';

import '../../../core/database/objectbox_providers.dart';
import '../../../core/diagnostics/app_diagnostics.dart';
import '../data/entities/nutrition_tracking_entities.dart';
import '../data/repositories/daily_record_repository.dart';
import '../data/repositories/meal_repository.dart';

class FoodInsightsScreen extends ConsumerStatefulWidget {
  const FoodInsightsScreen({super.key});

  @override
  ConsumerState<FoodInsightsScreen> createState() => _FoodInsightsScreenState();
}

class _FoodInsightsScreenState extends ConsumerState<FoodInsightsScreen> {
  _InsightsRangePreset _preset = _InsightsRangePreset.last30Days;
  late DateTime _customFrom = DateTime.now().subtract(
    const Duration(days: 29),
  );
  late DateTime _customTo = DateTime.now();
  late Future<_InsightsSnapshot> _future = _loadCurrentRange();
  String _foodSearch = '';

  DateTimeRange get _selectedRange {
    final DateTime today = _dateOnly(DateTime.now());
    switch (_preset) {
      case _InsightsRangePreset.last7Days:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );
      case _InsightsRangePreset.last30Days:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: today,
        );
      case _InsightsRangePreset.last90Days:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 89)),
          end: today,
        );
      case _InsightsRangePreset.all:
        return DateTimeRange(start: DateTime(2000), end: today);
      case _InsightsRangePreset.custom:
        final DateTime from = _dateOnly(_customFrom);
        final DateTime to = _dateOnly(_customTo);
        return DateTimeRange(
          start: from.isAfter(to) ? to : from,
          end: from.isAfter(to) ? from : to,
        );
    }
  }

  Future<_InsightsSnapshot> _loadCurrentRange() {
    final DateTimeRange range = _selectedRange;
    return _load(range.start, range.end);
  }

  Future<_InsightsSnapshot> _load(DateTime from, DateTime to) async {
    final Stopwatch totalWatch = Stopwatch()..start();
    try {
      final _InsightsSnapshot snapshot = await ref
          .read(objectBoxStoreProvider)
          .runAsync<List<String>, _InsightsSnapshot>(
        _queryAndAggregateInsights,
        <String>[_dateKey(from), _dateKey(to)],
      );
      totalWatch.stop();
      unawaited(
        AppDiagnostics.instance.info(
          'insights.load.completed',
          data: <String, Object?>{
            'from': _dateKey(from),
            'to': _dateKey(to),
            'backgroundObjectBoxMs': totalWatch.elapsedMilliseconds,
            'trackedDays': snapshot.days.length,
            'foodCount': snapshot.foods.length,
          },
        ),
      );
      return snapshot;
    } catch (error, stackTrace) {
      totalWatch.stop();
      await AppDiagnostics.instance.error(
        'insights.load.failed',
        error: error,
        stackTrace: stackTrace,
        data: <String, Object?>{
          'from': _dateKey(from),
          'to': _dateKey(to),
          'totalMs': totalWatch.elapsedMilliseconds,
        },
      );
      rethrow;
    }
  }

  void _reload() {
    setState(() {
      _foodSearch = '';
      _future = _loadCurrentRange();
    });
  }

  Future<void> _pickCustomRange() async {
    final DateTimeRange? selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: _customFrom,
        end: _customTo,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _customFrom = selected.start;
      _customTo = selected.end;
      _preset = _InsightsRangePreset.custom;
      _foodSearch = '';
      _future = _loadCurrentRange();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insight alimentari')),
      body: Column(
        children: <Widget>[
          _InsightsRangeToolbar(
            preset: _preset,
            range: _selectedRange,
            onPresetChanged: (_InsightsRangePreset value) {
              setState(() {
                _preset = value;
                _foodSearch = '';
                _future = _loadCurrentRange();
              });
            },
            onCustomRangePressed: _pickCustomRange,
          ),
          Expanded(
            child: FutureBuilder<_InsightsSnapshot>(
              future: _future,
              builder: (
                BuildContext context,
                AsyncSnapshot<_InsightsSnapshot> snapshot,
              ) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Elaborazione degli insight...'),
                      ],
                    ),
                  );
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.error_outline_rounded, size: 44),
                          const SizedBox(height: 12),
                          Text(
                            'Impossibile calcolare gli insight: '
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Riprova'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return _InsightsBody(
                  data: snapshot.data!,
                  foodSearch: _foodSearch,
                  onFoodSearchChanged: (String value) {
                    setState(() => _foodSearch = value);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsRangeToolbar extends StatelessWidget {
  const _InsightsRangeToolbar({
    required this.preset,
    required this.range,
    required this.onPresetChanged,
    required this.onCustomRangePressed,
  });

  final _InsightsRangePreset preset;
  final DateTimeRange range;
  final ValueChanged<_InsightsRangePreset> onPresetChanged;
  final VoidCallback onCustomRangePressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DropdownButtonFormField<_InsightsRangePreset>(
              key: ValueKey<_InsightsRangePreset>(preset),
              initialValue: preset,
              decoration: const InputDecoration(
                labelText: 'Intervallo dati',
                prefixIcon: Icon(Icons.date_range_outlined),
                isDense: true,
              ),
              items: _InsightsRangePreset.values
                  .map(
                    (_InsightsRangePreset value) =>
                        DropdownMenuItem<_InsightsRangePreset>(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (_InsightsRangePreset? value) {
                if (value == null) return;
                if (value == _InsightsRangePreset.custom) {
                  onCustomRangePressed();
                } else {
                  onPresetChanged(value);
                }
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${_displayDate(range.start)} - '
                    '${_displayDate(range.end)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: onCustomRangePressed,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Date'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsBody extends StatelessWidget {
  const _InsightsBody({
    required this.data,
    required this.foodSearch,
    required this.onFoodSearchChanged,
  });

  final _InsightsSnapshot data;
  final String foodSearch;
  final ValueChanged<String> onFoodSearchChanged;

  @override
  Widget build(BuildContext context) {
    final List<_FoodStat> filteredFoods = data.foods.where((_FoodStat food) {
      final String query = foodSearch.trim().toLowerCase();
      return query.isEmpty || food.name.toLowerCase().contains(query);
    }).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
      children: <Widget>[
        Text('Riepilogo nutrizionale',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        _MetricsGrid(data: data),
        const SizedBox(height: 16),
        _CollapsibleSection(
          title: 'Calorie e target',
          subtitle:
              'Linea assunzione e linea target. I punti rossi indicano giorni liberi.',
          initiallyExpanded: true,
          child: _ScrollableLineChart(
            days: data.days,
            series: <_ChartSeries>[
              _ChartSeries(
                label: 'Calorie assunte',
                values: data.days
                    .map((_DayInsight day) => day.kcal)
                    .toList(growable: false),
                color: Theme.of(context).colorScheme.primary,
                pointColor: (int index) => data.days[index].isFree
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                decimals: 0,
              ),
              _ChartSeries(
                label: 'Target',
                values: data.days
                    .map(
                        (_DayInsight day) => day.target > 0 ? day.target : null)
                    .toList(growable: false),
                color: Theme.of(context).colorScheme.tertiary,
                dashed: true,
                decimals: 0,
              ),
            ],
            unit: 'kcal',
          ),
        ),
        const SizedBox(height: 12),
        _CollapsibleSection(
          title: 'Bilancio calorico giornaliero',
          subtitle:
              'Barre negative per deficit e positive per surplus rispetto al target.',
          initiallyExpanded: true,
          child: _BalanceBarChart(days: data.days),
        ),
        const SizedBox(height: 12),
        _CollapsibleSection(
          title: 'Distribuzione dei giorni',
          subtitle:
              'Giorni liberi, parziali, in deficit, in surplus e in normocalorica (+/- 30 kcal).',
          initiallyExpanded: true,
          child: _DayStatusPieChart(counts: data.statusCounts),
        ),
        const SizedBox(height: 12),
        _CollapsibleSection(
          title: 'Macronutrienti',
          subtitle:
              'Proteine, carboidrati e grassi assunti ogni giorno, con valori visibili.',
          initiallyExpanded: true,
          child: Column(
            children: <Widget>[
              _MacroSummary(data: data),
              const SizedBox(height: 18),
              _ScrollableLineChart(
                days: data.days,
                series: <_ChartSeries>[
                  _ChartSeries(
                    label: 'Proteine',
                    values: data.days
                        .map((_DayInsight day) => day.protein)
                        .toList(growable: false),
                    color: const Color(0xFF7E57C2),
                    decimals: 1,
                  ),
                  _ChartSeries(
                    label: 'Carboidrati',
                    values: data.days
                        .map((_DayInsight day) => day.carbs)
                        .toList(growable: false),
                    color: const Color(0xFF26A69A),
                    decimals: 1,
                  ),
                  _ChartSeries(
                    label: 'Grassi',
                    values: data.days
                        .map((_DayInsight day) => day.fat)
                        .toList(growable: false),
                    color: const Color(0xFFFFA726),
                    decimals: 1,
                  ),
                ],
                unit: 'g',
              ),
              const SizedBox(height: 18),
              _MacroCaloriePieChart(data: data),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CollapsibleSection(
          title: 'Fibre e zuccheri',
          subtitle: 'Andamento giornaliero dei micronutrienti disponibili.',
          child: _ScrollableLineChart(
            days: data.days,
            series: <_ChartSeries>[
              _ChartSeries(
                label: 'Fibre',
                values: data.days
                    .map((_DayInsight day) => day.fiber)
                    .toList(growable: false),
                color: const Color(0xFF66BB6A),
                decimals: 1,
              ),
              _ChartSeries(
                label: 'Zuccheri',
                values: data.days
                    .map((_DayInsight day) => day.sugar)
                    .toList(growable: false),
                color: const Color(0xFFEC407A),
                decimals: 1,
              ),
            ],
            unit: 'g',
          ),
        ),
        const SizedBox(height: 12),
        _CollapsibleSection(
          title: 'Idratazione',
          subtitle: 'Litri di acqua registrati per giorno.',
          child: _SimpleValueBars(
            days: data.days,
            values: data.days
                .map((_DayInsight day) => day.waterLiters)
                .toList(growable: false),
            unit: 'L',
            decimals: 1,
            color: const Color(0xFF42A5F5),
          ),
        ),
        const SizedBox(height: 12),
        _CollapsibleSection(
          title: 'Sonno',
          subtitle:
              'Ore di sonno profondo e leggero. Il totale e mostrato sopra ogni barra.',
          child: _SleepStackedBars(days: data.days),
        ),
        const SizedBox(height: 12),
        _CollapsibleSection(
          title: 'Peso',
          subtitle: 'Andamento delle misurazioni disponibili nel periodo.',
          child: _ScrollableLineChart(
            days: data.days,
            series: <_ChartSeries>[
              _ChartSeries(
                label: 'Peso',
                values: data.days
                    .map((_DayInsight day) => day.weight)
                    .toList(growable: false),
                color: const Color(0xFF8D6E63),
                decimals: 1,
              ),
            ],
            unit: 'kg',
          ),
        ),
        const SizedBox(height: 12),
        _CollapsibleSection(
          title: 'Passi e attivita',
          subtitle: 'Passi, obiettivo giornaliero e calorie attive.',
          child: Column(
            children: <Widget>[
              _ScrollableLineChart(
                days: data.days,
                series: <_ChartSeries>[
                  _ChartSeries(
                    label: 'Passi',
                    values: data.days
                        .map((_DayInsight day) => day.steps.toDouble())
                        .toList(growable: false),
                    color: const Color(0xFF5C6BC0),
                    decimals: 0,
                  ),
                  _ChartSeries(
                    label: 'Obiettivo passi',
                    values: data.days
                        .map((_DayInsight day) => day.stepGoal.toDouble())
                        .toList(growable: false),
                    color: const Color(0xFF9FA8DA),
                    dashed: true,
                    decimals: 0,
                  ),
                ],
                unit: 'passi',
              ),
              const SizedBox(height: 18),
              _SimpleValueBars(
                days: data.days,
                values: data.days
                    .map((_DayInsight day) => day.activeKcal)
                    .toList(growable: false),
                unit: 'kcal attive',
                decimals: 0,
                color: const Color(0xFFEF5350),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CollapsibleSection(
          title: 'Alimenti consumati',
          subtitle:
              'Ricerca per nome e statistiche aggregate su quantita, calorie e macro.',
          initiallyExpanded: true,
          child: Column(
            children: <Widget>[
              TextField(
                onChanged: onFoodSearchChanged,
                decoration: const InputDecoration(
                  labelText: 'Cerca alimento',
                  prefixIcon: Icon(Icons.search_rounded),
                  suffixIcon: Icon(Icons.manage_search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              if (filteredFoods.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nessun alimento corrispondente.'),
                )
              else
                ...filteredFoods.take(80).map(
                      (_FoodStat food) => _FoodStatRow(food: food),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.data});

  final _InsightsSnapshot data;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.sizeOf(context).width >= 720 ? 4 : 2,
      childAspectRatio: 1.36,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: <Widget>[
        _MetricCard(
          label: 'Media kcal',
          value: data.averageKcal.toStringAsFixed(0),
          icon: Icons.local_fire_department_outlined,
        ),
        _MetricCard(
          label: 'Media target',
          value: data.averageTarget.toStringAsFixed(0),
          icon: Icons.flag_outlined,
        ),
        _MetricCard(
          label: 'Proteine medie',
          value: '${data.averageProtein.toStringAsFixed(1)} g',
          icon: Icons.fitness_center_outlined,
        ),
        _MetricCard(
          label: 'Carbo medi',
          value: '${data.averageCarbs.toStringAsFixed(1)} g',
          icon: Icons.grain_outlined,
        ),
        _MetricCard(
          label: 'Grassi medi',
          value: '${data.averageFat.toStringAsFixed(1)} g',
          icon: Icons.opacity_outlined,
        ),
        _MetricCard(
          label: 'Acqua media',
          value: '${data.averageWater.toStringAsFixed(1)} L',
          icon: Icons.water_drop_outlined,
        ),
        _MetricCard(
          label: 'Sonno medio',
          value: '${data.averageSleep.toStringAsFixed(1)} h',
          icon: Icons.bedtime_outlined,
        ),
        _MetricCard(
          label: 'Variazione peso',
          value: data.weightDelta == null
              ? '-'
              : '${data.weightDelta! >= 0 ? '+' : ''}'
                  '${data.weightDelta!.toStringAsFixed(1)} kg',
          icon: Icons.monitor_weight_outlined,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    required this.title,
    required this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        maintainState: true,
        title: Text(title),
        subtitle: Text(subtitle),
        childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
        children: <Widget>[child],
      ),
    );
  }
}

class _MacroSummary extends StatelessWidget {
  const _MacroSummary({required this.data});

  final _InsightsSnapshot data;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _ValueChip(
          label: 'Proteine',
          value: '${data.averageProtein.toStringAsFixed(1)} g/giorno',
          color: const Color(0xFF7E57C2),
        ),
        _ValueChip(
          label: 'Carboidrati',
          value: '${data.averageCarbs.toStringAsFixed(1)} g/giorno',
          color: const Color(0xFF26A69A),
        ),
        _ValueChip(
          label: 'Grassi',
          value: '${data.averageFat.toStringAsFixed(1)} g/giorno',
          color: const Color(0xFFFFA726),
        ),
        _ValueChip(
          label: 'Fibre',
          value: '${data.averageFiber.toStringAsFixed(1)} g/giorno',
          color: const Color(0xFF66BB6A),
        ),
        _ValueChip(
          label: 'Zuccheri',
          value: '${data.averageSugar.toStringAsFixed(1)} g/giorno',
          color: const Color(0xFFEC407A),
        ),
      ],
    );
  }
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text('$label: $value'),
      ),
    );
  }
}

class _ScrollableLineChart extends StatelessWidget {
  const _ScrollableLineChart({
    required this.days,
    required this.series,
    required this.unit,
  });

  final List<_DayInsight> days;
  final List<_ChartSeries> series;
  final String unit;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const Text('Dati non disponibili.');
    final double chartWidth = math.max(
      MediaQuery.sizeOf(context).width - 64,
      days.length * 62.0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: series
              .map(
                (_ChartSeries item) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 12,
                      height: 4,
                      color: item.color,
                    ),
                    const SizedBox(width: 5),
                    Text(item.label),
                  ],
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartWidth,
            height: 250,
            child: CustomPaint(
              painter: _LineChartPainter(
                days: days,
                series: series,
                unit: unit,
                gridColor: Theme.of(context).colorScheme.outlineVariant,
                textColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.days,
    required this.series,
    required this.unit,
    required this.gridColor,
    required this.textColor,
  });

  final List<_DayInsight> days;
  final List<_ChartSeries> series;
  final String unit;
  final Color gridColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double left = 42;
    const double right = 18;
    const double top = 34;
    const double bottom = 42;
    final Rect plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final List<double> available = <double>[
      for (final _ChartSeries item in series)
        for (final double? value in item.values)
          if (value != null && value.isFinite) value,
    ];
    if (available.isEmpty) return;
    final double maxValue = math.max(1.0, available.reduce(math.max));
    final double minValue = math.min(0.0, available.reduce(math.min));
    final double span = math.max(1.0, maxValue - minValue);

    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int step = 0; step <= 4; step += 1) {
      final double y = plot.top + plot.height * step / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final double value = maxValue - span * step / 4;
      _paintText(
        canvas,
        value.toStringAsFixed(0),
        Offset(2, y - 7),
        10,
        textColor,
      );
    }

    final double xStep = days.length <= 1 ? 0 : plot.width / (days.length - 1);
    for (int index = 0; index < days.length; index += 1) {
      final double x =
          days.length <= 1 ? plot.center.dx : plot.left + xStep * index;
      _paintText(
        canvas,
        days[index].date.substring(5),
        Offset(x - 18, plot.bottom + 8),
        9,
        textColor,
      );
    }

    for (final _ChartSeries item in series) {
      final Paint linePaint = Paint()
        ..color = item.color
        ..strokeWidth = 2.3
        ..style = PaintingStyle.stroke;
      Offset? previous;
      for (int index = 0; index < days.length; index += 1) {
        final double? value = item.values[index];
        if (value == null || !value.isFinite) {
          previous = null;
          continue;
        }
        final double x =
            days.length <= 1 ? plot.center.dx : plot.left + xStep * index;
        final double y = plot.bottom -
            ((value - minValue) / span).clamp(0.0, 1.0).toDouble() *
                plot.height;
        final Offset current = Offset(x, y);
        if (previous != null) {
          if (item.dashed) {
            _drawDashedLine(canvas, previous, current, linePaint);
          } else {
            canvas.drawLine(previous, current, linePaint);
          }
        }
        final Color pointColor = item.pointColor?.call(index) ?? item.color;
        canvas.drawCircle(
          current,
          4.2,
          Paint()..color = pointColor,
        );
        _paintText(
          canvas,
          value.toStringAsFixed(item.decimals),
          Offset(x - 22, y - 20),
          9,
          pointColor,
        );
        previous = current;
      }
    }
    _paintText(
      canvas,
      unit,
      Offset(plot.right - 34, 2),
      10,
      textColor,
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    const double dash = 5;
    const double gap = 4;
    final double length = (end - start).distance;
    if (length == 0) return;
    final Offset direction = (end - start) / length;
    double distance = 0;
    while (distance < length) {
      final double next = math.min(distance + dash, length);
      canvas.drawLine(
        start + direction * distance,
        start + direction * next,
        paint,
      );
      distance = next + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}

class _BalanceBarChart extends StatelessWidget {
  const _BalanceBarChart({required this.days});

  final List<_DayInsight> days;

  @override
  Widget build(BuildContext context) {
    final List<_DayInsight> usable =
        days.where((_DayInsight day) => day.target > 0).toList(growable: false);
    if (usable.isEmpty) return const Text('Target non disponibili.');
    final double width = math.max(
      MediaQuery.sizeOf(context).width - 64,
      usable.length * 54.0,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        height: 230,
        child: CustomPaint(
          painter: _BalanceBarPainter(
            days: usable,
            positiveColor: Theme.of(context).colorScheme.error,
            negativeColor: const Color(0xFF42A5F5),
            gridColor: Theme.of(context).colorScheme.outlineVariant,
            textColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _BalanceBarPainter extends CustomPainter {
  _BalanceBarPainter({
    required this.days,
    required this.positiveColor,
    required this.negativeColor,
    required this.gridColor,
    required this.textColor,
  });

  final List<_DayInsight> days;
  final Color positiveColor;
  final Color negativeColor;
  final Color gridColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double top = 22;
    const double bottom = 40;
    final double baseline = (size.height - bottom + top) / 2;
    final double maxAbs = math.max(
      1.0,
      days.map((_DayInsight day) => day.balance.abs()).reduce(math.max),
    );
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      Paint()
        ..color = gridColor
        ..strokeWidth = 1.4,
    );
    final double cell = size.width / days.length;
    for (int index = 0; index < days.length; index += 1) {
      final _DayInsight day = days[index];
      final double value = day.balance;
      final double height = (value.abs() / maxAbs) * 72;
      final double x = cell * index + cell * .2;
      final double width = cell * .6;
      final Rect bar = value >= 0
          ? Rect.fromLTWH(x, baseline - height, width, height)
          : Rect.fromLTWH(x, baseline, width, height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(4)),
        Paint()..color = value >= 0 ? positiveColor : negativeColor,
      );
      _paintText(
        canvas,
        '${value >= 0 ? '+' : ''}${value.round()}',
        Offset(x - 5, value >= 0 ? bar.top - 17 : bar.bottom + 2),
        9,
        value >= 0 ? positiveColor : negativeColor,
      );
      _paintText(
        canvas,
        day.date.substring(5),
        Offset(x - 5, size.height - 18),
        9,
        textColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BalanceBarPainter oldDelegate) => true;
}

class _DayStatusPieChart extends StatelessWidget {
  const _DayStatusPieChart({required this.counts});

  final Map<_DayStatus, int> counts;

  @override
  Widget build(BuildContext context) {
    final int total = counts.values.fold<int>(0, (int a, int b) => a + b);
    if (total == 0) return const Text('Dati non disponibili.');
    final Map<_DayStatus, Color> colors = <_DayStatus, Color>{
      _DayStatus.free: Theme.of(context).colorScheme.error,
      _DayStatus.partial: Colors.orange,
      _DayStatus.deficit: Colors.blue,
      _DayStatus.surplus: Colors.purple,
      _DayStatus.normo: Colors.green,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 150,
          height: 150,
          child: CustomPaint(
            painter: _PiePainter(counts: counts, colors: colors),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: _DayStatus.values.map((_DayStatus status) {
              final int value = counts[status] ?? 0;
              final double percentage = total == 0 ? 0.0 : value * 100 / total;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 10,
                      height: 10,
                      color: colors[status],
                    ),
                    const SizedBox(width: 7),
                    Expanded(child: Text(status.label)),
                    Text('$value · ${percentage.toStringAsFixed(1)}%'),
                  ],
                ),
              );
            }).toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({required this.counts, required this.colors});

  final Map<_DayStatus, int> counts;
  final Map<_DayStatus, Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final int total = counts.values.fold<int>(0, (int a, int b) => a + b);
    if (total == 0) return;
    final Rect rect = Offset.zero & size;
    double start = -math.pi / 2;
    for (final _DayStatus status in _DayStatus.values) {
      final int value = counts[status] ?? 0;
      if (value == 0) continue;
      final double sweep = math.pi * 2 * value / total;
      canvas.drawArc(
        rect.deflate(8),
        start,
        sweep,
        true,
        Paint()..color = colors[status]!,
      );
      start += sweep;
    }
    canvas.drawCircle(
      rect.center,
      size.shortestSide * .24,
      Paint()..color = Colors.white.withValues(alpha: .92),
    );
    _paintText(
      canvas,
      '$total',
      Offset(rect.center.dx - 12, rect.center.dy - 9),
      14,
      Colors.black87,
    );
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) => true;
}

class _MacroCaloriePieChart extends StatelessWidget {
  const _MacroCaloriePieChart({required this.data});

  final _InsightsSnapshot data;

  @override
  Widget build(BuildContext context) {
    final double proteinKcal = data.totalProtein * 4;
    final double carbsKcal = data.totalCarbs * 4;
    final double fatKcal = data.totalFat * 9;
    final double total = proteinKcal + carbsKcal + fatKcal;
    if (total <= 0) return const Text('Macro non disponibili.');
    final Map<String, double> values = <String, double>{
      'Proteine': proteinKcal,
      'Carboidrati': carbsKcal,
      'Grassi': fatKcal,
    };
    final Map<String, Color> colors = <String, Color>{
      'Proteine': const Color(0xFF7E57C2),
      'Carboidrati': const Color(0xFF26A69A),
      'Grassi': const Color(0xFFFFA726),
    };
    return Row(
      children: <Widget>[
        SizedBox(
          width: 140,
          height: 140,
          child: CustomPaint(
            painter: _NamedPiePainter(values: values, colors: colors),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: values.entries.map((MapEntry<String, double> entry) {
              final double percentage = entry.value * 100 / total;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 10,
                      height: 10,
                      color: colors[entry.key],
                    ),
                    const SizedBox(width: 7),
                    Expanded(child: Text(entry.key)),
                    Text('${percentage.toStringAsFixed(1)}%'),
                  ],
                ),
              );
            }).toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _NamedPiePainter extends CustomPainter {
  _NamedPiePainter({required this.values, required this.colors});

  final Map<String, double> values;
  final Map<String, Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final double total =
        values.values.fold<double>(0, (double a, double b) => a + b);
    if (total <= 0) return;
    double start = -math.pi / 2;
    final Rect rect = Offset.zero & size;
    for (final MapEntry<String, double> entry in values.entries) {
      final double sweep = math.pi * 2 * entry.value / total;
      canvas.drawArc(
        rect.deflate(7),
        start,
        sweep,
        true,
        Paint()..color = colors[entry.key]!,
      );
      start += sweep;
    }
    canvas.drawCircle(
      rect.center,
      size.shortestSide * .23,
      Paint()..color = Colors.white.withValues(alpha: .92),
    );
  }

  @override
  bool shouldRepaint(covariant _NamedPiePainter oldDelegate) => true;
}

class _SimpleValueBars extends StatelessWidget {
  const _SimpleValueBars({
    required this.days,
    required this.values,
    required this.unit,
    required this.decimals,
    required this.color,
  });

  final List<_DayInsight> days;
  final List<double?> values;
  final String unit;
  final int decimals;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bool hasData =
        values.any((double? value) => value != null && value > 0);
    if (!hasData) return const Text('Dati non disponibili.');
    final double width = math.max(
      MediaQuery.sizeOf(context).width - 64,
      days.length * 54.0,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        height: 210,
        child: CustomPaint(
          painter: _SimpleBarsPainter(
            days: days,
            values: values,
            unit: unit,
            decimals: decimals,
            color: color,
            textColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SimpleBarsPainter extends CustomPainter {
  _SimpleBarsPainter({
    required this.days,
    required this.values,
    required this.unit,
    required this.decimals,
    required this.color,
    required this.textColor,
  });

  final List<_DayInsight> days;
  final List<double?> values;
  final String unit;
  final int decimals;
  final Color color;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final List<double> available = values
        .whereType<double>()
        .where((double value) => value.isFinite)
        .toList(growable: false);
    if (available.isEmpty) return;
    final double maxValue = math.max(1.0, available.reduce(math.max));
    final double cell = size.width / values.length;
    const double baseline = 168;
    for (int index = 0; index < values.length; index += 1) {
      final double? value = values[index];
      final double x = cell * index + cell * .2;
      final double width = cell * .6;
      if (value != null && value.isFinite) {
        final double height = value / maxValue * 118;
        final Rect bar = Rect.fromLTWH(x, baseline - height, width, height);
        canvas.drawRRect(
          RRect.fromRectAndRadius(bar, const Radius.circular(5)),
          Paint()..color = color,
        );
        _paintText(
          canvas,
          value.toStringAsFixed(decimals),
          Offset(x - 3, bar.top - 17),
          9,
          color,
        );
      }
      _paintText(
        canvas,
        days[index].date.substring(5),
        Offset(x - 5, baseline + 10),
        9,
        textColor,
      );
    }
    _paintText(canvas, unit, const Offset(4, 4), 10, textColor);
  }

  @override
  bool shouldRepaint(covariant _SimpleBarsPainter oldDelegate) => true;
}

class _SleepStackedBars extends StatelessWidget {
  const _SleepStackedBars({required this.days});

  final List<_DayInsight> days;

  @override
  Widget build(BuildContext context) {
    if (!days.any((_DayInsight day) => day.sleepTotal > 0)) {
      return const Text('Dati sul sonno non disponibili.');
    }
    final double width = math.max(
      MediaQuery.sizeOf(context).width - 64,
      days.length * 58.0,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        height: 220,
        child: CustomPaint(
          painter: _SleepPainter(
            days: days,
            deepColor: const Color(0xFF5C6BC0),
            lightColor: const Color(0xFFB39DDB),
            textColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SleepPainter extends CustomPainter {
  _SleepPainter({
    required this.days,
    required this.deepColor,
    required this.lightColor,
    required this.textColor,
  });

  final List<_DayInsight> days;
  final Color deepColor;
  final Color lightColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double maxValue = math.max(
      1.0,
      days.map((_DayInsight day) => day.sleepTotal).reduce(math.max),
    );
    final double cell = size.width / days.length;
    const double baseline = 175;
    for (int index = 0; index < days.length; index += 1) {
      final _DayInsight day = days[index];
      final double x = cell * index + cell * .2;
      final double width = cell * .6;
      final double deepHeight = day.sleepDeep / maxValue * 125;
      final double lightHeight = day.sleepLight / maxValue * 125;
      final Rect lightRect = Rect.fromLTWH(
        x,
        baseline - lightHeight,
        width,
        lightHeight,
      );
      final Rect deepRect = Rect.fromLTWH(
        x,
        baseline - lightHeight - deepHeight,
        width,
        deepHeight,
      );
      canvas.drawRect(lightRect, Paint()..color = lightColor);
      canvas.drawRRect(
        RRect.fromRectAndRadius(deepRect, const Radius.circular(4)),
        Paint()..color = deepColor,
      );
      if (day.sleepTotal > 0) {
        _paintText(
          canvas,
          day.sleepTotal.toStringAsFixed(1),
          Offset(x - 2, deepRect.top - 17),
          9,
          deepColor,
        );
      }
      _paintText(
        canvas,
        day.date.substring(5),
        Offset(x - 5, baseline + 9),
        9,
        textColor,
      );
    }
    _paintText(canvas, 'h', const Offset(4, 4), 10, textColor);
  }

  @override
  bool shouldRepaint(covariant _SleepPainter oldDelegate) => true;
}

class _FoodStatRow extends StatelessWidget {
  const _FoodStatRow({required this.food});

  final _FoodStat food;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    food.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text('${food.kcal.round()} kcal'),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 5,
              children: <Widget>[
                Text('${food.occurrences} occorrenze'),
                Text('${food.grams.round()} g'),
                Text('P ${food.protein.toStringAsFixed(1)} g'),
                Text('C ${food.carbs.toStringAsFixed(1)} g'),
                Text('G ${food.fat.toStringAsFixed(1)} g'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartSeries {
  const _ChartSeries({
    required this.label,
    required this.values,
    required this.color,
    this.pointColor,
    this.dashed = false,
    this.decimals = 0,
  });

  final String label;
  final List<double?> values;
  final Color color;
  final Color Function(int index)? pointColor;
  final bool dashed;
  final int decimals;
}

_InsightsSnapshot _queryAndAggregateInsights(
  Store store,
  List<String> range,
) {
  final List<DailyRecordEntity> records = DailyRecordRepository(store)
      .getAllActive()
      .where(
        (DailyRecordEntity day) =>
            day.dateKey.compareTo(range[0]) >= 0 &&
            day.dateKey.compareTo(range[1]) <= 0,
      )
      .toList(growable: false);
  final List<MealWithItems> meals =
      MealRepository(store).getMealsWithItemsInRange(
    fromDateKey: range[0],
    toDateKey: range[1],
  );

  final Map<String, DailyRecordEntity> recordsByDate =
      <String, DailyRecordEntity>{
    for (final DailyRecordEntity record in records) record.dateKey: record,
  };
  final Map<String, _MutableDay> days = <String, _MutableDay>{};
  final Map<String, _MutableFoodStat> foods = <String, _MutableFoodStat>{};

  for (final DailyRecordEntity record in records) {
    final _MutableDay day = days.putIfAbsent(
      record.dateKey,
      () => _MutableDay(record.dateKey),
    );
    day.target = record.targetKcal ?? 0;
    day.weight = record.weightKg;
    day.waterLiters = record.waterLiters ??
        ((record.waterGlasses ?? 0) > 0
            ? (record.waterGlasses ?? 0) * .25
            : null);
    day.sleepDeep = record.sleepDeepHours ?? 0;
    day.sleepLight = record.sleepLightHours ?? 0;
    day.steps = record.steps;
    day.stepGoal = record.stepGoal;
    day.activeKcal = record.activeEffectiveKcal ??
        record.activeKcalActual ??
        record.activeRefKcal ??
        0;
    day.isFree = record.freeMealModeCode != 'none';
    if (record.caloriesInKcal != null && record.caloriesInKcal! > 0) {
      day.fallbackCalories = record.caloriesInKcal!;
    }
  }

  for (final MealWithItems meal in meals) {
    final String date = meal.meal.dateKey;
    final _MutableDay day = days.putIfAbsent(date, () => _MutableDay(date));
    day.isFree = day.isFree ||
        meal.meal.mealModeCode == 'free' ||
        meal.meal.freeMealTrackingCode.isNotEmpty;
    day.isPartial = day.isPartial || meal.isNutritionPartial;
    for (final MealItemEntity item in meal.items) {
      if (item.deletedAtEpochMs != null) continue;
      day.kcal += item.kcal;
      day.protein += item.proteinGrams;
      day.carbs += item.carbsGrams;
      day.fat += item.fatGrams;
      day.fiber += item.fiberGrams;
      day.sugar += item.sugarGrams;

      final String displayName = item.itemNameSnapshot.trim().isEmpty
          ? 'Alimento senza nome'
          : item.itemNameSnapshot.trim();
      final String key = displayName.toLowerCase();
      final _MutableFoodStat food = foods.putIfAbsent(
        key,
        () => _MutableFoodStat(displayName),
      );
      food.occurrences += 1;
      food.grams += item.grams ?? 0;
      food.kcal += item.kcal;
      food.protein += item.proteinGrams;
      food.carbs += item.carbsGrams;
      food.fat += item.fatGrams;
    }
  }

  final List<_DayInsight> outputDays = days.values.map((_MutableDay day) {
    if (day.kcal <= 0 && day.fallbackCalories > 0) {
      day.kcal = day.fallbackCalories;
    }
    final double? completeness = recordsByDate[day.date]?.dataCompletenessScore;
    if (!day.isPartial && completeness != null && completeness < .999) {
      day.isPartial = true;
    }
    final double balance = day.target > 0 ? day.kcal - day.target : 0;
    final _DayStatus status;
    if (day.isFree) {
      status = _DayStatus.free;
    } else if (day.isPartial || day.target <= 0) {
      status = _DayStatus.partial;
    } else if (balance.abs() <= 30) {
      status = _DayStatus.normo;
    } else if (balance < 0) {
      status = _DayStatus.deficit;
    } else {
      status = _DayStatus.surplus;
    }
    return _DayInsight(
      date: day.date,
      kcal: day.kcal,
      target: day.target,
      balance: balance,
      protein: day.protein,
      carbs: day.carbs,
      fat: day.fat,
      fiber: day.fiber,
      sugar: day.sugar,
      waterLiters: day.waterLiters,
      sleepDeep: day.sleepDeep,
      sleepLight: day.sleepLight,
      weight: day.weight,
      steps: day.steps,
      stepGoal: day.stepGoal,
      activeKcal: day.activeKcal,
      isFree: day.isFree,
      status: status,
    );
  }).toList(growable: false)
    ..sort((_DayInsight a, _DayInsight b) => a.date.compareTo(b.date));

  final List<_FoodStat> outputFoods = foods.values
      .map(
        (_MutableFoodStat food) => _FoodStat(
          name: food.name,
          occurrences: food.occurrences,
          grams: food.grams,
          kcal: food.kcal,
          protein: food.protein,
          carbs: food.carbs,
          fat: food.fat,
        ),
      )
      .toList(growable: false)
    ..sort((_FoodStat a, _FoodStat b) {
      final int byOccurrences = b.occurrences.compareTo(a.occurrences);
      return byOccurrences != 0 ? byOccurrences : b.kcal.compareTo(a.kcal);
    });

  return _InsightsSnapshot(days: outputDays, foods: outputFoods);
}

class _InsightsSnapshot {
  const _InsightsSnapshot({required this.days, required this.foods});

  final List<_DayInsight> days;
  final List<_FoodStat> foods;

  int get _trackedDayCount =>
      days.where((_DayInsight day) => day.kcal > 0).length;

  double get totalProtein => _sum(days.map((_DayInsight day) => day.protein));
  double get totalCarbs => _sum(days.map((_DayInsight day) => day.carbs));
  double get totalFat => _sum(days.map((_DayInsight day) => day.fat));

  double get averageKcal => _average(
        days
            .where((_DayInsight day) => day.kcal > 0)
            .map((_DayInsight day) => day.kcal),
      );
  double get averageTarget => _average(
        days
            .where((_DayInsight day) => day.target > 0)
            .map((_DayInsight day) => day.target),
      );
  double get averageProtein =>
      _trackedDayCount == 0 ? 0.0 : totalProtein / _trackedDayCount;
  double get averageCarbs =>
      _trackedDayCount == 0 ? 0.0 : totalCarbs / _trackedDayCount;
  double get averageFat =>
      _trackedDayCount == 0 ? 0.0 : totalFat / _trackedDayCount;
  double get averageFiber => _average(days.map((_DayInsight day) => day.fiber));
  double get averageSugar => _average(days.map((_DayInsight day) => day.sugar));
  double get averageWater => _average(
        days
            .map((_DayInsight day) => day.waterLiters)
            .whereType<double>()
            .where((double value) => value > 0),
      );
  double get averageSleep => _average(
        days
            .map((_DayInsight day) => day.sleepTotal)
            .where((double value) => value > 0),
      );

  double? get weightDelta {
    final List<double> weights = days
        .map((_DayInsight day) => day.weight)
        .whereType<double>()
        .where((double value) => value > 0)
        .toList(growable: false);
    if (weights.length < 2) return null;
    return weights.last - weights.first;
  }

  Map<_DayStatus, int> get statusCounts => <_DayStatus, int>{
        for (final _DayStatus status in _DayStatus.values)
          status: days.where((_DayInsight day) => day.status == status).length,
      };
}

class _DayInsight {
  const _DayInsight({
    required this.date,
    required this.kcal,
    required this.target,
    required this.balance,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.waterLiters,
    required this.sleepDeep,
    required this.sleepLight,
    required this.weight,
    required this.steps,
    required this.stepGoal,
    required this.activeKcal,
    required this.isFree,
    required this.status,
  });

  final String date;
  final double kcal;
  final double target;
  final double balance;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double? waterLiters;
  final double sleepDeep;
  final double sleepLight;
  final double? weight;
  final int steps;
  final int stepGoal;
  final double activeKcal;
  final bool isFree;
  final _DayStatus status;

  double get sleepTotal => sleepDeep + sleepLight;
}

class _FoodStat {
  const _FoodStat({
    required this.name,
    required this.occurrences,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final String name;
  final int occurrences;
  final double grams;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
}

class _MutableDay {
  _MutableDay(this.date);

  final String date;
  double kcal = 0;
  double fallbackCalories = 0;
  double target = 0;
  double protein = 0;
  double carbs = 0;
  double fat = 0;
  double fiber = 0;
  double sugar = 0;
  double? waterLiters;
  double sleepDeep = 0;
  double sleepLight = 0;
  double? weight;
  int steps = 0;
  int stepGoal = 0;
  double activeKcal = 0;
  bool isFree = false;
  bool isPartial = false;
}

class _MutableFoodStat {
  _MutableFoodStat(this.name);

  final String name;
  int occurrences = 0;
  double grams = 0;
  double kcal = 0;
  double protein = 0;
  double carbs = 0;
  double fat = 0;
}

enum _DayStatus {
  free('Libero'),
  partial('Parziale'),
  deficit('Deficit'),
  surplus('Surplus'),
  normo('Normo');

  const _DayStatus(this.label);
  final String label;
}

enum _InsightsRangePreset {
  last7Days('Ultimi 7 giorni'),
  last30Days('Ultimi 30 giorni'),
  last90Days('Ultimi 90 giorni'),
  all('Tutto'),
  custom('Intervallo personalizzato');

  const _InsightsRangePreset(this.label);
  final String label;
}

double _sum(Iterable<double> values) =>
    values.fold<double>(0, (double a, double b) => a + b);

double _average(Iterable<double> values) {
  final List<double> list = values.toList(growable: false);
  if (list.isEmpty) return 0;
  return _sum(list) / list.length;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _displayDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

void _paintText(
  Canvas canvas,
  String text,
  Offset offset,
  double fontSize,
  Color color,
) {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: fontSize, color: color),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  painter.paint(canvas, offset);
}
