import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:objectbox/objectbox.dart';

import '../../../../core/database/objectbox_providers.dart';
import '../../../../core/diagnostics/app_diagnostics.dart';
import '../../data/repositories/meal_repository.dart';

class MonthMealCalendarCard extends ConsumerStatefulWidget {
  const MonthMealCalendarCard({super.key});

  @override
  ConsumerState<MonthMealCalendarCard> createState() =>
      _MonthMealCalendarCardState();
}

class _MonthMealCalendarCardState extends ConsumerState<MonthMealCalendarCard> {
  static final Map<String, _MonthCalendarSnapshot> _cache =
      <String, _MonthCalendarSnapshot>{};

  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  _MonthCalendarSnapshot? _snapshot;
  bool _loading = true;
  Object? _error;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMonth(_month));
  }

  Future<void> _loadMonth(DateTime month) async {
    final String cacheKey = _monthKey(month);
    final _MonthCalendarSnapshot? cached = _cache[cacheKey];
    final int generation = ++_requestGeneration;

    setState(() {
      _month = month;
      _snapshot = cached;
      _loading = cached == null;
      _error = null;
    });
    if (cached != null) return;

    final Stopwatch watch = Stopwatch()..start();
    try {
      final DateTime first = DateTime(month.year, month.month);
      final DateTime last = DateTime(month.year, month.month + 1, 0);
      final Map<String, Map<String, num>> aggregated = await ref
          .read(objectBoxStoreProvider)
          .runAsync<List<String>, Map<String, Map<String, num>>>(
        _queryAndAggregateMonthMeals,
        <String>[_dateKey(first), _dateKey(last)],
      );
      watch.stop();

      final _MonthCalendarSnapshot snapshot = _MonthCalendarSnapshot(
        month: first,
        days: aggregated.map(
          (String key, Map<String, num> value) => MapEntry<String, _DayMeals>(
            key,
            _DayMeals(
              meals: value['meals']!.toInt(),
              kcal: value['kcal']!.toDouble(),
              freeMeals: value['freeMeals']!.toInt(),
            ),
          ),
        ),
      );
      _cache[cacheKey] = snapshot;

      unawaited(
        AppDiagnostics.instance.info(
          'dashboard.month_calendar_load.completed',
          data: <String, Object?>{
            'month': cacheKey,
            'backgroundObjectBoxMs': watch.elapsedMilliseconds,
            'dayCount': aggregated.length,
          },
        ),
      );

      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error, stackTrace) {
      watch.stop();
      await AppDiagnostics.instance.error(
        'dashboard.month_calendar_load.failed',
        error: error,
        stackTrace: stackTrace,
        data: <String, Object?>{
          'month': cacheKey,
          'totalMs': watch.elapsedMilliseconds,
        },
      );
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _changeMonth(int delta) {
    unawaited(_loadMonth(DateTime(_month.year, _month.month + delta)));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Mese precedente',
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Text(
                        _monthLabel(_month),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Caricamento limitato al mese visualizzato.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Mese successivo',
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading && _snapshot == null)
              const _CalendarSkeleton()
            else if (_error != null && _snapshot == null)
              Center(
                child: Column(
                  children: <Widget>[
                    const Text('Calendario non disponibile.'),
                    TextButton.icon(
                      onPressed: () => _loadMonth(_month),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Riprova'),
                    ),
                  ],
                ),
              )
            else ...<Widget>[
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 7),
              _buildCalendar(context, _snapshot!, colors),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(
    BuildContext context,
    _MonthCalendarSnapshot snapshot,
    ColorScheme colors,
  ) {
    const List<String> weekdays = <String>['L', 'M', 'M', 'G', 'V', 'S', 'D'];
    final DateTime first = snapshot.month;
    final int leading = first.weekday - 1;
    final int daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final int totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final DateTime today = DateTime.now();

    return Column(
      children: <Widget>[
        Row(
          children: weekdays
              .map(
                (String label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 5),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: .66,
          ),
          itemCount: totalCells,
          itemBuilder: (BuildContext context, int index) {
            final int dayNumber = index - leading + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox.shrink();
            }
            final DateTime date = DateTime(first.year, first.month, dayNumber);
            final String dateKey = _dateKey(date);
            final _DayMeals? info = snapshot.days[dateKey];
            final bool isToday = today.year == date.year &&
                today.month == date.month &&
                today.day == date.day;
            final String tooltip = info == null
                ? '$dateKey: nessun dato'
                : '$dateKey: ${info.meals} pasti, '
                    '${info.kcal.round()} kcal';

            return Tooltip(
              message: tooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => context.push('/food/days/$dateKey'),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isToday ? colors.primary : colors.outlineVariant,
                      width: isToday ? 2 : 1,
                    ),
                    color: info == null
                        ? colors.surfaceContainerLow
                        : colors.primaryContainer.withValues(alpha: .55),
                  ),
                  child: Stack(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 3,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '$dayNumber',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                            if (info != null) ...<Widget>[
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${info.kcal.round()}',
                                  maxLines: 1,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(fontSize: 8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (info != null && info.freeMeals > 0)
                        Positioned(
                          right: 3,
                          top: 3,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: colors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

Map<String, Map<String, num>> _queryAndAggregateMonthMeals(
  Store store,
  List<String> range,
) {
  final List<MealWithItems> meals =
      MealRepository(store).getMealsWithItemsInRange(
    fromDateKey: range[0],
    toDateKey: range[1],
  );
  final Map<String, Map<String, num>> output = <String, Map<String, num>>{};
  for (final MealWithItems meal in meals) {
    final Map<String, num> day = output.putIfAbsent(
      meal.meal.dateKey,
      () => <String, num>{'meals': 0, 'kcal': 0, 'freeMeals': 0},
    );
    day['meals'] = day['meals']! + 1;
    day['kcal'] = day['kcal']! + meal.totals.kcal;
    if (meal.meal.mealModeCode == 'free' ||
        meal.meal.freeMealTrackingCode.isNotEmpty) {
      day['freeMeals'] = day['freeMeals']! + 1;
    }
  }
  return output;
}

class _MonthCalendarSnapshot {
  const _MonthCalendarSnapshot({required this.month, required this.days});

  final DateTime month;
  final Map<String, _DayMeals> days;
}

class _DayMeals {
  const _DayMeals({
    required this.meals,
    required this.kcal,
    required this.freeMeals,
  });

  final int meals;
  final double kcal;
  final int freeMeals;
}

class _CalendarSkeleton extends StatelessWidget {
  const _CalendarSkeleton();

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: .66,
      ),
      itemCount: 35,
      itemBuilder: (_, __) => DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

String _monthKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}';

String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _monthLabel(DateTime date) {
  const List<String> months = <String>[
    'Gennaio',
    'Febbraio',
    'Marzo',
    'Aprile',
    'Maggio',
    'Giugno',
    'Luglio',
    'Agosto',
    'Settembre',
    'Ottobre',
    'Novembre',
    'Dicembre',
  ];
  return '${months[date.month - 1]} ${date.year}';
}
