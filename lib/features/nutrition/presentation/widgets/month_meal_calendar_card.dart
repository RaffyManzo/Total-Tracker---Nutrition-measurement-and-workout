import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:objectbox/objectbox.dart';

import '../../../../core/database/objectbox_providers.dart';
import '../../../../core/diagnostics/app_diagnostics.dart';
import '../../data/food_data_refresh_bus.dart';
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
  static final Map<String, Future<_MonthCalendarSnapshot>> _inFlight =
      <String, Future<_MonthCalendarSnapshot>>{};

  static void invalidateDateKey(String dateKey) {
    final DateTime? date = DateTime.tryParse(dateKey);
    if (date == null) return;
    final String key = _monthKey(date);
    _cache.remove(key);
  }

  late DateTime _month = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  _MonthCalendarSnapshot? _snapshot;
  bool _loading = true;
  Object? _error;
  int _requestGeneration = 0;
  StreamSubscription<FoodDataChange>? _changeSubscription;

  @override
  void initState() {
    super.initState();
    _changeSubscription = FoodDataRefreshBus.changes.listen(_onDataChange);
    final FoodDataChange? lastChange = FoodDataRefreshBus.lastChange;
    if (lastChange != null &&
        lastChange.kind != FoodDataChangeKind.dailyRecord) {
      invalidateDateKey(lastChange.dateKey);
    }
    unawaited(_loadMonth(_month));
  }

  @override
  void dispose() {
    _changeSubscription?.cancel();
    super.dispose();
  }

  void _onDataChange(FoodDataChange change) {
    if (change.kind == FoodDataChangeKind.dailyRecord) return;
    final DateTime? changedDate = DateTime.tryParse(change.dateKey);
    if (changedDate == null) return;
    invalidateDateKey(change.dateKey);
    if (!mounted || _monthKey(changedDate) != _monthKey(_month)) return;
    unawaited(_loadMonth(_month, force: true));
  }

  Future<_MonthCalendarSnapshot> _fetchMonth(
    DateTime first,
    DateTime last,
  ) {
    final String key = _monthKey(first);
    final Future<_MonthCalendarSnapshot>? existing = _inFlight[key];
    if (existing != null) return existing;

    final Future<_MonthCalendarSnapshot> future = () async {
      final Stopwatch watch = Stopwatch()..start();
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
              filledMealSlots: value['filledMealSlots']!.toInt(),
              itemCount: value['itemCount']!.toInt(),
              kcal: value['kcal']!.toDouble(),
              trackedFreeMeals: value['trackedFreeMeals']!.toInt(),
              estimatedFreeMeals: value['estimatedFreeMeals']!.toInt(),
              untrackedFreeMeals: value['untrackedFreeMeals']!.toInt(),
            ),
          ),
        ),
      );
      unawaited(
        AppDiagnostics.instance.info(
          'dashboard.month_calendar_load.completed',
          data: <String, Object?>{
            'month': key,
            'backgroundObjectBoxMs': watch.elapsedMilliseconds,
            'dayCount': aggregated.length,
            'deduplicated': false,
          },
        ),
      );
      return snapshot;
    }();

    _inFlight[key] = future;
    void clearInFlight() {
      if (identical(_inFlight[key], future)) {
        _inFlight.remove(key);
      }
    }

    unawaited(
      future.then<void>(
        (_) => clearInFlight(),
        onError: (Object _, StackTrace __) {
          clearInFlight();
        },
      ),
    );
    return future;
  }

  Future<void> _loadMonth(DateTime month, {bool force = false}) async {
    final String cacheKey = _monthKey(month);
    final _MonthCalendarSnapshot? cached = force ? null : _cache[cacheKey];
    final int generation = ++_requestGeneration;
    setState(() {
      _month = month;
      _snapshot = cached ?? _snapshot;
      _loading = cached == null;
      _error = null;
    });
    if (cached != null) return;

    final DateTime first = DateTime(month.year, month.month);
    final DateTime last = DateTime(month.year, month.month + 1, 0);
    final bool joinedInFlight = _inFlight.containsKey(cacheKey);
    try {
      final _MonthCalendarSnapshot snapshot = await _fetchMonth(first, last);
      _cache[cacheKey] = snapshot;
      if (joinedInFlight) {
        unawaited(
          AppDiagnostics.instance.info(
            'dashboard.month_calendar_load.deduplicated',
            data: <String, Object?>{'month': cacheKey},
          ),
        );
      }
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error, stackTrace) {
      await AppDiagnostics.instance.error(
        'dashboard.month_calendar_load.failed',
        error: error,
        stackTrace: stackTrace,
        data: <String, Object?>{'month': cacheKey},
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
                        'Stato dei pasti del mese visualizzato.',
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
                      onPressed: () => _loadMonth(_month, force: true),
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
    final DateTime rawToday = DateTime.now();
    final DateTime today =
        DateTime(rawToday.year, rawToday.month, rawToday.day);

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
            final bool isToday = date == today;
            final bool isFuture = date.isAfter(today);
            final bool isPast = date.isBefore(today);
            final bool hasFood = (info?.itemCount ?? 0) > 0;
            final bool hasFreeMeal = info?.hasFreeMeal ?? false;
            final bool complete = (info?.filledMealSlots ?? 0) >= 4;
            final bool pastIncomplete = isPast &&
                info != null &&
                info.meals > 0 &&
                !hasFreeMeal &&
                !complete;

            final Color fillColor;
            final Color textColor;
            if ((info?.untrackedFreeMeals ?? 0) > 0) {
              fillColor = colors.errorContainer;
              textColor = colors.onErrorContainer;
            } else if ((info?.trackedOrEstimatedFreeMeals ?? 0) > 0) {
              fillColor = Colors.orange.withValues(alpha: .42);
              textColor = colors.onSurface;
            } else if (isFuture && hasFood) {
              fillColor = colors.surfaceContainerHighest;
              textColor = colors.onSurface;
            } else if (!isFuture && complete) {
              fillColor = Colors.green.withValues(alpha: .34);
              textColor = colors.onSurface;
            } else {
              fillColor = colors.surfaceContainerLow;
              textColor = colors.onSurfaceVariant;
            }

            final Color borderColor = isToday
                ? const Color(0xFF228B22)
                : pastIncomplete
                    ? Colors.orange.shade700
                    : colors.outlineVariant;
            final double borderWidth = isToday
                ? 2.6
                : pastIncomplete
                    ? 2
                    : 1;
            final String tooltip = _tooltip(dateKey, info, isFuture);

            return Tooltip(
              message: tooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => context.push('/food/days/$dateKey'),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: borderColor,
                      width: borderWidth,
                    ),
                    color: fillColor,
                  ),
                  child: Padding(
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
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        if (!isFuture &&
                            info != null &&
                            info.itemCount > 0) ...<Widget>[
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 9,
                                  color: textColor,
                                  semanticLabel: 'Calorie assunte',
                                ),
                                const SizedBox(width: 1),
                                Text(
                                  '${info.kcal.round()} kcal',
                                  maxLines: 1,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: textColor,
                                        fontSize: 7.5,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        const Wrap(
          spacing: 12,
          runSpacing: 8,
          children: <Widget>[
            _CalendarLegendItem(
              fillColor: Colors.green,
              label: 'Completo, nessun pasto libero',
            ),
            _CalendarLegendItem(
              fillColor: Colors.red,
              label: 'Libero non tracciato',
            ),
            _CalendarLegendItem(
              fillColor: Colors.orange,
              label: 'Libero tracciato o stimato',
            ),
            _CalendarLegendItem(
              fillColor: Color(0xFFE0E0E0),
              label: 'Pasti futuri pianificati',
            ),
            _CalendarLegendItem(
              fillColor: Colors.transparent,
              borderColor: Color(0xFF228B22),
              label: 'Giorno corrente',
            ),
            _CalendarLegendItem(
              fillColor: Colors.transparent,
              borderColor: Colors.orange,
              label: 'Giorno passato incompleto',
            ),
          ],
        ),
      ],
    );
  }
}

String _tooltip(String dateKey, _DayMeals? info, bool isFuture) {
  if (info == null) return '$dateKey: nessun pasto compilato';
  final List<String> parts = <String>[
    '$dateKey: ${info.filledMealSlots}/4 pasti compilati',
  ];
  if (!isFuture && info.itemCount > 0) parts.add('${info.kcal.round()} kcal');
  if (info.untrackedFreeMeals > 0) {
    parts.add('pasto libero non tracciato');
  } else if (info.estimatedFreeMeals > 0) {
    parts.add('pasto libero stimato');
  } else if (info.trackedFreeMeals > 0) {
    parts.add('pasto libero tracciato');
  }
  return parts.join(' · ');
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
  final Map<String, Set<String>> filledSlots = <String, Set<String>>{};

  for (final MealWithItems meal in meals) {
    final String dateKey = meal.meal.dateKey;
    final Map<String, num> day = output.putIfAbsent(
      dateKey,
      () => <String, num>{
        'meals': 0,
        'filledMealSlots': 0,
        'itemCount': 0,
        'kcal': 0,
        'trackedFreeMeals': 0,
        'estimatedFreeMeals': 0,
        'untrackedFreeMeals': 0,
      },
    );
    day['meals'] = day['meals']! + 1;
    day['itemCount'] = day['itemCount']! + meal.items.length;
    day['kcal'] = day['kcal']! + meal.totals.kcal;
    if (meal.items.isNotEmpty) {
      filledSlots
          .putIfAbsent(dateKey, () => <String>{})
          .add(meal.meal.mealTypeCode);
    }

    final bool isFree = meal.meal.mealModeCode == 'free' ||
        meal.meal.freeMealTrackingCode.isNotEmpty;
    if (isFree) {
      final String tracking =
          meal.meal.freeMealTrackingCode.trim().toLowerCase();
      if (tracking == 'untracked') {
        day['untrackedFreeMeals'] = day['untrackedFreeMeals']! + 1;
      } else if (tracking == 'estimated') {
        day['estimatedFreeMeals'] = day['estimatedFreeMeals']! + 1;
      } else {
        day['trackedFreeMeals'] = day['trackedFreeMeals']! + 1;
      }
    }
  }

  for (final MapEntry<String, Set<String>> entry in filledSlots.entries) {
    output[entry.key]!['filledMealSlots'] = entry.value.length;
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
    required this.filledMealSlots,
    required this.itemCount,
    required this.kcal,
    required this.trackedFreeMeals,
    required this.estimatedFreeMeals,
    required this.untrackedFreeMeals,
  });

  final int meals;
  final int filledMealSlots;
  final int itemCount;
  final double kcal;
  final int trackedFreeMeals;
  final int estimatedFreeMeals;
  final int untrackedFreeMeals;

  int get trackedOrEstimatedFreeMeals => trackedFreeMeals + estimatedFreeMeals;
  bool get hasFreeMeal =>
      trackedOrEstimatedFreeMeals > 0 || untrackedFreeMeals > 0;
}

class _CalendarLegendItem extends StatelessWidget {
  const _CalendarLegendItem({
    required this.fillColor,
    required this.label,
    this.borderColor,
  });

  final Color fillColor;
  final Color? borderColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: fillColor.withValues(
                alpha: fillColor == Colors.transparent ? 1 : .55),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color:
                  borderColor ?? Theme.of(context).colorScheme.outlineVariant,
              width: borderColor == null ? 1 : 2,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
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
