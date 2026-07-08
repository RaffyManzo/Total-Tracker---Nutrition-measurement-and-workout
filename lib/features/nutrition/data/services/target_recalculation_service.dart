import '../../../profile/data/repositories/user_profile_repository.dart';
import '../../domain/target_model_constants.dart';
import '../entities/nutrition_tracking_entities.dart';
import '../repositories/daily_record_repository.dart';
import 'food_analytics_service.dart';
import 'target_input_hasher.dart';

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
    required this.skippedDays,
    required this.firstUpdatedDate,
    required this.lastUpdatedDate,
  });

  final int updatedDays;
  final int skippedDays;
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

  Future<TargetRecalculationReport> recalculateExistingRange({
    required String fromDateKey,
    required String toDateKey,
    String? inputRevisionSeed,
    void Function(TargetRecalculationProgress progress)? onProgress,
  }) {
    return _recalculateWhere(
      include: (DailyRecordEntity day) =>
          day.dateKey.compareTo(fromDateKey) >= 0 &&
          day.dateKey.compareTo(toDateKey) <= 0,
      inputRevisionSeed: inputRevisionSeed,
      onProgress: onProgress,
    );
  }

  Future<TargetRecalculationReport> _recalculateWhere({
    required bool Function(DailyRecordEntity day) include,
    String? inputRevisionSeed,
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
            ? 'Nessuna giornata esistente da aggiornare.'
            : 'Preparazione del ricalcolo incrementale...',
      ),
    );

    int updatedDays = 0;
    int skippedDays = 0;
    final List<DailyRecordEntity> changed = <DailyRecordEntity>[];
    for (int index = 0; index < days.length; index += 1) {
      final DailyRecordEntity day = days[index];
      final String inputHash = TargetInputHasher.hashForDay(
        day: day,
        chronologicalHistory: allDays,
        modelVersion: TargetModelConstants.modelVersion,
        inputRevisionSeed: inputRevisionSeed,
      );
      final bool unchanged =
          day.targetInputHashVersion == TargetInputHasher.version &&
              day.targetInputHash == inputHash &&
              day.targetSourceHash
                  .startsWith('${TargetModelConstants.modelVersion}|');
      if (unchanged) {
        skippedDays += 1;
      } else {
        final TargetDayResult result = _analytics.targetResultForDay(
          day: day,
          allDays: allDays,
          profile: profile,
        );
        _analytics.applyTargetSnapshot(day, result);
        day.targetInputHash = inputHash;
        day.targetInputHashVersion = TargetInputHasher.version;
        day.targetCalculationRevision += 1;
        changed.add(day);
        updatedDays += 1;
      }
      onProgress?.call(
        TargetRecalculationProgress(
          completed: index + 1,
          total: days.length,
          message: 'Ricalcolo target: ${index + 1} di ${days.length}',
        ),
      );
      if (index.isEven) await Future<void>.delayed(Duration.zero);
    }

    if (changed.isNotEmpty) {
      _dailyRecords.saveCalculatedSnapshots(changed);
    }
    return TargetRecalculationReport(
      updatedDays: updatedDays,
      skippedDays: skippedDays,
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
