import 'dart:math' as math;

import '../../../profile/data/entities/user_profile_entity.dart';
import '../../../workout/data/repositories/workout_session_repository.dart';
import '../entities/nutrition_tracking_entities.dart';
import '../repositories/meal_repository.dart';
import '../repositories/measurement_repository.dart';

class ActivityBreakdown {
  const ActivityBreakdown({
    required this.stepKcal,
    required this.completedWorkoutKcal,
    required this.actualTotalKcal,
  });

  final double stepKcal;
  final double completedWorkoutKcal;
  final double actualTotalKcal;
}

class ObservedTdeeResult {
  const ObservedTdeeResult({
    required this.tdeeObserved,
    required this.observedConfidence,
    required this.validIntakeDays,
    required this.validWeightDays,
    required this.deltaWeightKg,
    required this.avgCalories,
  });

  final double? tdeeObserved;
  final double observedConfidence;
  final int validIntakeDays;
  final int validWeightDays;
  final double? deltaWeightKg;
  final double? avgCalories;
}

class WeekAdaptiveSummary {
  const WeekAdaptiveSummary({
    required this.monday,
    required this.sunday,
    required this.targetKcal,
    required this.targetStatusCode,
    required this.tdeeRefKcal,
    required this.tdeeTheoreticalKcal,
    required this.tdeeObservedKcal,
    required this.observedConfidence,
    required this.referenceDaysCount,
    required this.validIntakeDays,
    required this.validWeightDays,
    required this.rmrKcal,
    required this.weightRefKg,
    required this.activeRefKcal,
    required this.currentWeekActiveKcal,
    required this.activityDeltaKcal,
    required this.deltaWeightKg,
    required this.avgCalories,
  });

  final DateTime monday;
  final DateTime sunday;
  final double targetKcal;
  final String targetStatusCode;
  final double tdeeRefKcal;
  final double tdeeTheoreticalKcal;
  final double? tdeeObservedKcal;
  final double observedConfidence;
  final int referenceDaysCount;
  final int validIntakeDays;
  final int validWeightDays;
  final double? rmrKcal;
  final double? weightRefKg;
  final double activeRefKcal;
  final double currentWeekActiveKcal;
  final double activityDeltaKcal;
  final double? deltaWeightKg;
  final double? avgCalories;
}

class FoodAnalyticsService {
  FoodAnalyticsService({
    required MealRepository meals,
    required MeasurementRepository measurements,
    required WorkoutSessionRepository workoutSessions,
  })  : _meals = meals,
        _measurements = measurements,
        _workoutSessions = workoutSessions;

  final MealRepository _meals;
  final MeasurementRepository _measurements;
  final WorkoutSessionRepository _workoutSessions;

  ActivityBreakdown activityForDay(
    DailyRecordEntity day, {
    UserProfileEntity? profile,
  }) {
    final double stepCoeff = profile?.stepKcalCoefficient ?? 0.025;
    final double stepKcal = day.activeKcalSteps ?? day.steps * stepCoeff;
    final double completedWorkout =
        _workoutSessions.completedKcalForDate(day.dateKey);
    final double fallbackCompleted =
        day.activeKcalWorkoutCompleted ?? completedWorkout;
    final double actual = math.max(0, stepKcal + fallbackCompleted);
    return ActivityBreakdown(
      stepKcal: stepKcal,
      completedWorkoutKcal: fallbackCompleted,
      actualTotalKcal: actual,
    );
  }

  double caloriesForDate(String dateKey) {
    return _meals.getMealsWithItemsForDate(dateKey).fold<double>(
          0,
          (double sum, MealWithItems meal) => sum + meal.totals.kcal,
        );
  }

  bool hasPartialNutrition(String dateKey) {
    return _meals.getMealsWithItemsForDate(dateKey).any(
          (MealWithItems meal) => meal.isNutritionPartial,
        );
  }

  String freeMealModeForDate(String dateKey) {
    final List<MealWithItems> meals = _meals.getMealsWithItemsForDate(dateKey);
    final bool hasFree =
        meals.any((MealWithItems meal) => meal.meal.mealModeCode == 'free');
    if (!hasFree) {
      return 'none';
    }
    if (meals.any(
      (MealWithItems meal) => meal.meal.freeMealTrackingCode == 'untracked',
    )) {
      return 'untracked';
    }
    if (meals.any(
      (MealWithItems meal) => meal.meal.freeMealTrackingCode == 'estimated',
    )) {
      return 'estimated';
    }
    return 'tracked';
  }

  double? weightForDay(DailyRecordEntity day) {
    return _measurements.findScaleByDate(day.dateKey)?.weightKg ?? day.weightKg;
  }

  WeekAdaptiveSummary adaptiveSummaryForWeek({
    required DateTime monday,
    required List<DailyRecordEntity> allDays,
    UserProfileEntity? profile,
    DateTime? now,
  }) {
    final DateTime sunday = monday.add(const Duration(days: 6));
    final String mondayKey = _dateKey(monday);
    final List<DailyRecordEntity> sorted = List<DailyRecordEntity>.from(allDays)
      ..sort((DailyRecordEntity a, DailyRecordEntity b) {
        return a.dateKey.compareTo(b.dateKey);
      });
    final int referenceLimit = profile?.adaptiveReferenceDays ?? 28;
    final List<DailyRecordEntity> reference = sorted
        .where((DailyRecordEntity day) => day.dateKey.compareTo(mondayKey) < 0)
        .toList()
        .takeLast(referenceLimit);
    final List<DailyRecordEntity> currentWeek = sorted.where(
      (DailyRecordEntity day) {
        final DateTime parsed = DateTime.parse(day.dateKey);
        return !parsed.isBefore(monday) && !parsed.isAfter(sunday);
      },
    ).toList();
    final List<ActivityBreakdown> referenceActivity = reference
        .map((DailyRecordEntity day) => activityForDay(day, profile: profile))
        .toList();
    final List<double> activeValues = referenceActivity
        .map((ActivityBreakdown item) => item.actualTotalKcal)
        .where((double value) => value > 0)
        .toList();
    final double activeRef = _average(activeValues) ?? 0;
    final List<ActivityBreakdown> currentActivity = currentWeek
        .map((DailyRecordEntity day) => activityForDay(day, profile: profile))
        .toList();
    final double currentWeekActive = _average(
          currentActivity
              .map((ActivityBreakdown item) => item.actualTotalKcal)
              .where((double value) => value > 0)
              .toList(),
        ) ??
        activeRef;
    final double? weightRef = _referenceWeight(reference, currentWeek);
    final double? rmr = _calculateRmr(weightRef, profile, now: now);
    final double theoretical = rmr == null
        ? (profile?.defaultTargetKcal ?? 1980).toDouble()
        : (rmr * (profile?.rmrActivityFactor ?? 1.10)) + activeRef;
    final ObservedTdeeResult observed = _calculateObservedTdee(
      reference,
      minimumObservedDays: profile?.adaptiveMinimumObservedDays ?? 7,
      kcalPerKg: profile?.kcalPerKg ?? 7700,
      minTdee: profile?.minimumReasonableTdee ?? 1300,
      maxTdee: profile?.maximumReasonableTdee ?? 4600,
    );
    final double confidence =
        observed.tdeeObserved == null ? 0 : observed.observedConfidence;
    final double calculated = observed.tdeeObserved == null
        ? theoretical
        : confidence * observed.tdeeObserved! + (1 - confidence) * theoretical;
    final double tdeeRef = _clamp(
      calculated,
      profile?.minimumReasonableTdee ?? 1300,
      profile?.maximumReasonableTdee ?? 4600,
    );
    final double activityDelta = currentWeekActive - activeRef;
    final double target = _clamp(
      tdeeRef + activityDelta,
      profile?.minimumReasonableTdee ?? 1300,
      profile?.maximumReasonableTdee ?? 4600,
    );
    return WeekAdaptiveSummary(
      monday: monday,
      sunday: sunday,
      targetKcal: target,
      targetStatusCode: confidence >= 0.35 || reference.length >= 7
          ? 'adaptive'
          : 'provisional',
      tdeeRefKcal: tdeeRef,
      tdeeTheoreticalKcal: theoretical,
      tdeeObservedKcal: observed.tdeeObserved,
      observedConfidence: confidence,
      referenceDaysCount: reference.length,
      validIntakeDays: observed.validIntakeDays,
      validWeightDays: observed.validWeightDays,
      rmrKcal: rmr,
      weightRefKg: weightRef,
      activeRefKcal: activeRef,
      currentWeekActiveKcal: currentWeekActive,
      activityDeltaKcal: activityDelta,
      deltaWeightKg: observed.deltaWeightKg,
      avgCalories: observed.avgCalories,
    );
  }

  ObservedTdeeResult _calculateObservedTdee(
    List<DailyRecordEntity> referenceDays, {
    required int minimumObservedDays,
    required double kcalPerKg,
    required double minTdee,
    required double maxTdee,
  }) {
    if (referenceDays.length < minimumObservedDays) {
      return const ObservedTdeeResult(
        tdeeObserved: null,
        observedConfidence: 0,
        validIntakeDays: 0,
        validWeightDays: 0,
        deltaWeightKg: null,
        avgCalories: null,
      );
    }
    final List<_WeightedValue> intakeDays = <_WeightedValue>[];
    final List<_WeightPoint> weightPoints = <_WeightPoint>[];
    for (int index = 0; index < referenceDays.length; index += 1) {
      final DailyRecordEntity day = referenceDays[index];
      final String freeMode = freeMealModeForDate(day.dateKey);
      final double intakeReliability = _intakeReliabilityForMode(freeMode);
      final double kcal = caloriesForDate(day.dateKey);
      if (kcal > 0 && intakeReliability > 0) {
        intakeDays.add(_WeightedValue(value: kcal, weight: intakeReliability));
      }
      final double? weight = weightForDay(day);
      final double reliability = weight == null ? 0 : 1;
      if (weight != null && weight > 0 && reliability > 0.25) {
        weightPoints.add(
          _WeightPoint(
            dateKey: day.dateKey,
            value: weight,
            weight: reliability,
          ),
        );
      }
    }
    if (intakeDays.length < minimumObservedDays) {
      return ObservedTdeeResult(
        tdeeObserved: null,
        observedConfidence: 0.10,
        validIntakeDays: intakeDays.length,
        validWeightDays: 0,
        deltaWeightKg: null,
        avgCalories: intakeDays.isEmpty ? null : _weightedAverage(intakeDays),
      );
    }
    final double avgCalories = _weightedAverage(intakeDays);
    if (weightPoints.length < 4) {
      return ObservedTdeeResult(
        tdeeObserved: null,
        observedConfidence: 0.15,
        validIntakeDays: intakeDays.length,
        validWeightDays: weightPoints.length,
        deltaWeightKg: null,
        avgCalories: avgCalories,
      );
    }
    final int splitSize = math.max(2, weightPoints.length ~/ 2);
    final List<_WeightPoint> firstWindow =
        weightPoints.take(splitSize).toList();
    final List<_WeightPoint> lastWindow = weightPoints
        .skip(math.max(0, weightPoints.length - splitSize))
        .toList();
    final double startWeight = _weightedAverage(firstWindow);
    final double endWeight = _weightedAverage(lastWindow);
    final int elapsedDays = math.max(
      1,
      DateTime.parse(lastWindow.last.dateKey)
          .difference(DateTime.parse(firstWindow.first.dateKey))
          .inDays,
    );
    final double deltaWeightKg = endWeight - startWeight;
    final double observed =
        avgCalories - ((deltaWeightKg * kcalPerKg) / elapsedDays);
    final double dayFactor = _clamp((intakeDays.length - 4) / 10, 0, 1);
    final double weightFactor = _clamp((weightPoints.length - 3) / 8, 0, 1);
    final double intakeReliability = _average(
            intakeDays.map((_WeightedValue item) => item.weight).toList()) ??
        0;
    final double observedConfidence = _clamp(
      dayFactor * 0.42 + weightFactor * 0.28 + intakeReliability * 0.30,
      0,
      0.80,
    );
    return ObservedTdeeResult(
      tdeeObserved: _clamp(observed, minTdee, maxTdee),
      observedConfidence: observedConfidence,
      validIntakeDays: intakeDays.length,
      validWeightDays: weightPoints.length,
      deltaWeightKg: deltaWeightKg,
      avgCalories: avgCalories,
    );
  }

  double? _calculateRmr(
    double? weightKg,
    UserProfileEntity? profile, {
    DateTime? now,
  }) {
    if (weightKg == null || weightKg <= 0 || profile?.heightCm == null) {
      return null;
    }
    final int? age = _age(profile!.birthDateEpochDay, now ?? DateTime.now());
    if (age == null) {
      return null;
    }
    final double base = 10 * weightKg + 6.25 * profile.heightCm! - 5 * age;
    if (<String>['male', 'm', 'man', 'uomo', 'maschio']
        .contains(profile.biologicalSexCode.toLowerCase())) {
      return base + 5;
    }
    if (<String>['female', 'f', 'woman', 'donna', 'femmina']
        .contains(profile.biologicalSexCode.toLowerCase())) {
      return base - 161;
    }
    return base;
  }

  int? _age(int? birthDateEpochDay, DateTime now) {
    if (birthDateEpochDay == null) {
      return null;
    }
    final DateTime birthDate =
        DateTime.fromMillisecondsSinceEpoch(birthDateEpochDay * 86400000);
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age -= 1;
    }
    return age < 0 ? null : age;
  }

  double? _referenceWeight(
    List<DailyRecordEntity> reference,
    List<DailyRecordEntity> currentWeek,
  ) {
    final List<double> values = <double>[
      for (final DailyRecordEntity day in reference.followedBy(currentWeek))
        if (weightForDay(day) != null) weightForDay(day)!,
    ];
    if (values.isEmpty) {
      return null;
    }
    return values.reduce((double a, double b) => a + b) / values.length;
  }

  double _intakeReliabilityForMode(String mode) {
    if (mode == 'untracked') {
      return 0;
    }
    if (mode == 'estimated') {
      return 0.6;
    }
    return 1;
  }

  double? _average(List<double> values) {
    if (values.isEmpty) {
      return null;
    }
    return values.reduce((double a, double b) => a + b) / values.length;
  }

  double _weightedAverage(Iterable<_WeightedValue> values) {
    final List<_WeightedValue> valueList = values.toList();
    final double weightSum =
        valueList.fold<double>(0, (double sum, _WeightedValue item) {
      return sum + item.weight;
    });
    if (weightSum <= 0) {
      return 0;
    }
    return valueList.fold<double>(
          0,
          (double sum, _WeightedValue item) => sum + item.value * item.weight,
        ) /
        weightSum;
  }

  double _clamp(double value, double min, double max) {
    return math.max(min, math.min(max, value));
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class _WeightedValue {
  const _WeightedValue({
    required this.value,
    required this.weight,
  });

  final double value;
  final double weight;
}

class _WeightPoint extends _WeightedValue {
  const _WeightPoint({
    required this.dateKey,
    required super.value,
    required super.weight,
  });

  final String dateKey;
}

extension _TakeLast<T> on List<T> {
  List<T> takeLast(int count) {
    if (length <= count) {
      return List<T>.from(this);
    }
    return sublist(length - count);
  }
}
