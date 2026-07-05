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
  late Future<_InsightsSnapshot> _future = _load();

  Future<_InsightsSnapshot> _load() async {
    final Stopwatch totalWatch = Stopwatch()..start();
    try {
      final DateTime now = DateTime.now();
      final DateTime from = now.subtract(const Duration(days: 89));
      final _InsightsSnapshot snapshot = await ref
          .read(objectBoxStoreProvider)
          .runAsync<List<String>, _InsightsSnapshot>(
        _queryAndAggregateInsights,
        <String>[_dateKey(from), _dateKey(now)],
      );
      totalWatch.stop();
      unawaited(
        AppDiagnostics.instance.info(
          'insights.load.completed',
          data: <String, Object?>{
            'backgroundObjectBoxMs': totalWatch.elapsedMilliseconds,
            'trackedDays': snapshot.trackedDays,
            'mealCount': snapshot.totalMeals,
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
          'totalMs': totalWatch.elapsedMilliseconds,
        },
      );
      rethrow;
    }
  }

  void _retry() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insight alimentari')),
      body: FutureBuilder<_InsightsSnapshot>(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.error_outline_rounded, size: 44),
                  const SizedBox(height: 12),
                  Text('Impossibile calcolare gli insight: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Riprova'),
                  ),
                ],
              ),
            );
          }
          return _InsightsBody(data: snapshot.data!);
        },
      ),
    );
  }
}

class _InsightsBody extends StatelessWidget {
  const _InsightsBody({required this.data});

  final _InsightsSnapshot data;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        Text('Panoramica', style: textTheme.headlineSmall),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 4 : 2,
          childAspectRatio: 1.45,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: <Widget>[
            _MetricCard(
              label: 'Giorni tracciati',
              value: '${data.trackedDays}',
              icon: Icons.calendar_month_outlined,
            ),
            _MetricCard(
              label: 'Media kcal',
              value: '${data.averageKcal.round()}',
              icon: Icons.local_fire_department_outlined,
            ),
            _MetricCard(
              label: 'Media passi',
              value: '${data.averageSteps.round()}',
              icon: Icons.directions_walk_outlined,
            ),
            _MetricCard(
              label: 'Pasti registrati',
              value: '${data.totalMeals}',
              icon: Icons.restaurant_outlined,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SectionCard(
          title: 'Andamento calorie',
          subtitle: 'Ultimi 30 giorni con dati disponibili',
          child: _MiniBarChart(
            values: data.calorieTrend,
            unit: 'kcal',
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Attivita giornaliera',
          subtitle: 'Passi degli ultimi 30 giorni',
          child: _MiniBarChart(
            values: data.stepTrend,
            unit: 'passi',
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Alimenti piu frequenti',
          subtitle: 'Occorrenze, calorie e grammi negli ultimi 90 giorni',
          child: data.topFoods.isEmpty
              ? const Text('Nessun alimento sufficiente per la statistica.')
              : Column(
                  children: data.topFoods
                      .map((food) => _FoodStatRow(food: food))
                      .toList(growable: false),
                ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Distribuzione dei pasti',
          subtitle: 'Numero di registrazioni per fascia alimentare',
          child: Column(
            children: data.mealSlots.entries
                .map(
                  (entry) => _DistributionRow(
                    label: _slotLabel(entry.key),
                    value: entry.value,
                    max: data.mealSlots.values.fold<int>(
                      1,
                      (int a, int b) => a > b ? a : b,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        if (data.weightTrend.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Peso',
            subtitle: 'Misurazioni giornaliere disponibili',
            child: _MiniBarChart(
              values: data.weightTrend,
              unit: 'kg',
              decimals: 1,
            ),
          ),
        ],
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
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  const _MiniBarChart({
    required this.values,
    required this.unit,
    this.decimals = 0,
  });

  final List<_TrendPoint> values;
  final String unit;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const Text('Dati non disponibili.');
    final double maxValue =
        values.map((point) => point.value).fold<double>(1, math.max);
    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.map((point) {
          final double height = 130 * (point.value / maxValue);
          return Expanded(
            child: Tooltip(
              message:
                  '${point.label}: ${point.value.toStringAsFixed(decimals)} $unit',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Container(
                      height: math.max(3.0, height).toDouble(),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (values.length <= 14)
                      Text(
                        point.label.substring(point.label.length - 2),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _FoodStatRow extends StatelessWidget {
  const _FoodStatRow({required this.food});

  final _FoodStat food;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(food.name),
      subtitle: Text(
        '${food.occurrences} volte · ${food.grams.round()} g complessivi',
      ),
      trailing: Text('${food.kcal.round()} kcal'),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.label,
    required this.value,
    required this.max,
  });

  final String label;
  final int value;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          SizedBox(width: 84, child: Text(label)),
          Expanded(
            child: LinearProgressIndicator(value: value / math.max(1, max)),
          ),
          const SizedBox(width: 10),
          Text('$value'),
        ],
      ),
    );
  }
}

_InsightsSnapshot _queryAndAggregateInsights(
  Store store,
  List<String> range,
) {
  final List<DailyRecordEntity> days = DailyRecordRepository(store)
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

  final List<Map<String, Object?>> dayPayload = days
      .map(
        (DailyRecordEntity day) => <String, Object?>{
          'date': day.dateKey,
          'steps': day.steps,
          'weight': day.weightKg,
          'target': day.targetKcal,
        },
      )
      .toList(growable: false);
  final List<Map<String, Object?>> mealPayload = meals
      .map(
        (MealWithItems meal) => <String, Object?>{
          'date': meal.meal.dateKey,
          'slot': meal.meal.mealTypeCode,
          'items': meal.items
              .where((item) => item.deletedAtEpochMs == null)
              .map(
                (item) => <String, Object?>{
                  'name': item.itemNameSnapshot,
                  'kcal': item.kcal,
                  'grams': item.grams ?? 0,
                },
              )
              .toList(growable: false),
        },
      )
      .toList(growable: false);
  return _aggregateInsights(dayPayload, mealPayload);
}

_InsightsSnapshot _aggregateInsights(
  List<Map<String, Object?>> days,
  List<Map<String, Object?>> meals,
) {
  final Map<String, double> kcalByDate = <String, double>{};
  final Map<String, int> mealSlots = <String, int>{};
  final Map<String, _MutableFoodStat> foodStats = <String, _MutableFoodStat>{};

  for (final Map<String, Object?> meal in meals) {
    final String date = meal['date']! as String;
    final String slot = meal['slot']! as String;
    mealSlots[slot] = (mealSlots[slot] ?? 0) + 1;
    final List<Object?> items = meal['items']! as List<Object?>;
    for (final Object? rawItem in items) {
      final Map<String, Object?> item = rawItem! as Map<String, Object?>;
      final String name = (item['name']! as String).trim();
      final double kcal = (item['kcal']! as num).toDouble();
      final double grams = (item['grams']! as num).toDouble();
      kcalByDate[date] = (kcalByDate[date] ?? 0) + kcal;
      final String key = name.toLowerCase();
      final _MutableFoodStat stat = foodStats.putIfAbsent(
        key,
        () => _MutableFoodStat(name),
      );
      stat.occurrences += 1;
      stat.kcal += kcal;
      stat.grams += grams;
    }
  }

  final List<MapEntry<String, double>> calorieEntries =
      kcalByDate.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  final List<_TrendPoint> calories = calorieEntries
      .map((entry) => _TrendPoint(entry.key, entry.value))
      .toList(growable: false);

  final List<_TrendPoint> steps = <_TrendPoint>[];
  final List<_TrendPoint> weights = <_TrendPoint>[];
  for (final Map<String, Object?> day in days) {
    final String date = day['date']! as String;
    steps.add(_TrendPoint(date, (day['steps']! as num).toDouble()));
    final Object? weight = day['weight'];
    if (weight is num && weight > 0) {
      weights.add(_TrendPoint(date, weight.toDouble()));
    }
  }
  steps.sort((a, b) => a.label.compareTo(b.label));
  weights.sort((a, b) => a.label.compareTo(b.label));

  final List<_FoodStat> topFoods = foodStats.values
      .map(
        (stat) => _FoodStat(
          name: stat.name,
          occurrences: stat.occurrences,
          kcal: stat.kcal,
          grams: stat.grams,
        ),
      )
      .toList()
    ..sort((a, b) => b.occurrences.compareTo(a.occurrences));

  final int trackedDays = kcalByDate.length;
  final double averageKcal = trackedDays == 0
      ? 0
      : kcalByDate.values.reduce((a, b) => a + b) / trackedDays;
  final double averageSteps = steps.isEmpty
      ? 0
      : steps.map((point) => point.value).reduce((a, b) => a + b) /
          steps.length;

  return _InsightsSnapshot(
    trackedDays: trackedDays,
    totalMeals: meals.length,
    averageKcal: averageKcal,
    averageSteps: averageSteps,
    calorieTrend: _takeLast(calories, 30),
    stepTrend: _takeLast(steps, 30),
    weightTrend: _takeLast(weights, 30),
    topFoods: topFoods.take(10).toList(growable: false),
    mealSlots: mealSlots,
  );
}

List<_TrendPoint> _takeLast(List<_TrendPoint> source, int count) {
  if (source.length <= count) return source;
  return source.sublist(source.length - count);
}

String _slotLabel(String value) {
  switch (value) {
    case 'colazione':
      return 'Colazione';
    case 'spuntino':
      return 'Spuntino';
    case 'pranzo':
      return 'Pranzo';
    case 'cena':
      return 'Cena';
    default:
      return value;
  }
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class _InsightsSnapshot {
  const _InsightsSnapshot({
    required this.trackedDays,
    required this.totalMeals,
    required this.averageKcal,
    required this.averageSteps,
    required this.calorieTrend,
    required this.stepTrend,
    required this.weightTrend,
    required this.topFoods,
    required this.mealSlots,
  });

  final int trackedDays;
  final int totalMeals;
  final double averageKcal;
  final double averageSteps;
  final List<_TrendPoint> calorieTrend;
  final List<_TrendPoint> stepTrend;
  final List<_TrendPoint> weightTrend;
  final List<_FoodStat> topFoods;
  final Map<String, int> mealSlots;
}

class _TrendPoint {
  const _TrendPoint(this.label, this.value);
  final String label;
  final double value;
}

class _FoodStat {
  const _FoodStat({
    required this.name,
    required this.occurrences,
    required this.kcal,
    required this.grams,
  });

  final String name;
  final int occurrences;
  final double kcal;
  final double grams;
}

class _MutableFoodStat {
  _MutableFoodStat(this.name);
  final String name;
  int occurrences = 0;
  double kcal = 0;
  double grams = 0;
}
