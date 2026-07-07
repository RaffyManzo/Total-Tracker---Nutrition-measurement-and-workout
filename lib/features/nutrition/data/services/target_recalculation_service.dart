import '../../../profile/data/repositories/user_profile_repository.dart';
import '../entities/nutrition_tracking_entities.dart';
import '../food_data_refresh_bus.dart';
import '../repositories/daily_record_repository.dart';
import 'food_analytics_service.dart';

class TargetRecalculationProgress {
  const TargetRecalculationProgress({
    required this.completed,
    required this.total,
    required this.message,
  });

  final int completed;
  final int total;
  final String message;

  double? get ratio => total <= 0 ? null : completed / total;
}

class TargetRecalculationReport {
  const TargetRecalculationReport({
    required this.updatedDays,
    required this.firstUpdatedDate,
    required this.lastUpdatedDate,
  });

  final int updatedDays;
  final String? firstUpdatedDate;
  final String? lastUpdatedDate;
}

class TargetRecalculationService {
  TargetRecalculationService({
    required UserProfileRepository profiles,
    required DailyRecordRepository dailyRecords,
    required FoodAnalyticsService analytics,
  })  : _profiles = profiles,
        _dailyRecords = dailyRecords,
        _analytics = analytics;

  final UserProfileRepository _profiles;
  final DailyRecordRepository _dailyRecords;
  final FoodAnalyticsService _analytics;

  Future<TargetRecalculationReport> recalculateCurrentAndFutureTargets({
    void Function(TargetRecalculationProgress progress)? onProgress,
  }) async {
    final String todayKey = _dateKey(DateTime.now());
    _dailyRecords.ensureForDate(todayKey);
    return _recalculateWhere(
      include: (DailyRecordEntity day) => day.dateKey.compareTo(todayKey) >= 0,
      onProgress: onProgress,
    );
  }

  Future<TargetRecalculationReport> recalculateAllHistoricalTargets({
    void Function(TargetRecalculationProgress progress)? onProgress,
  }) {
    return _recalculateWhere(
      include: (DailyRecordEntity day) => true,
      onProgress: onProgress,
    );
  }

  Future<TargetRecalculationReport> recalculateDay(
    String dateKey, {
    void Function(TargetRecalculationProgress progress)? onProgress,
  }) {
    _dailyRecords.ensureForDate(dateKey);
    return _recalculateWhere(
      include: (DailyRecordEntity day) => day.dateKey == dateKey,
      onProgress: onProgress,
    );
  }

  Future<TargetRecalculationReport> _recalculateWhere({
    required bool Function(DailyRecordEntity day) include,
    void Function(TargetRecalculationProgress progress)? onProgress,
  }) async {
    final profile = _profiles.getActiveProfile() ??
        _profiles.createDefaultProfileIfMissing();
    final List<DailyRecordEntity> allDays = _dailyRecords.getAllActive()
      ..sort(
        (DailyRecordEntity a, DailyRecordEntity b) =>
            a.dateKey.compareTo(b.dateKey),
      );
    final List<DailyRecordEntity> days = allDays.where(include).toList();

    onProgress?.call(
      TargetRecalculationProgress(
        completed: 0,
        total: days.length,
        message: days.isEmpty
            ? 'Nessuna giornata da aggiornare.'
            : 'Preparazione del ricalcolo...',
      ),
    );

    for (int index = 0; index < days.length; index += 1) {
      final DailyRecordEntity day = days[index];
      final TargetDayResult result = _analytics.targetResultForDay(
        day: day,
        allDays: allDays,
        profile: profile,
      );
      _analytics.applyTargetSnapshot(day, result);
      onProgress?.call(
        TargetRecalculationProgress(
          completed: index + 1,
          total: days.length,
          message: 'Ricalcolo target: ${index + 1} di ${days.length}',
        ),
      );
      if (index.isEven) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (days.isNotEmpty) {
      _profiles.saveWithDailyRecords(profile, days);
      for (final DailyRecordEntity day in days) {
        FoodDataRefreshBus.publishManualRefresh(day.dateKey);
      }
    }
    return TargetRecalculationReport(
      updatedDays: days.length,
      firstUpdatedDate: days.isEmpty ? null : days.first.dateKey,
      lastUpdatedDate: days.isEmpty ? null : days.last.dateKey,
    );
  }

  String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
