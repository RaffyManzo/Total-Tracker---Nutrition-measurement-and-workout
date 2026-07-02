import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../database/objectbox_database.dart';
import '../notifications/local_notification_service.dart';
import '../preferences/food_service_preferences.dart';
import '../../features/nutrition/data/repositories/meal_repository.dart';
import '../../features/nutrition/data/repositories/measurement_repository.dart';
import '../../features/nutrition/data/repositories/open_nutrition_catalog_repository.dart';
import '../../features/nutrition/data/services/open_nutrition_catalog_database.dart';
import '../../features/nutrition/data/services/open_nutrition_import_service.dart';

class TotalTrackerBackgroundTaskNames {
  const TotalTrackerBackgroundTaskNames._();

  static const openNutritionImport = 'total_tracker_open_nutrition_import';
  static const reminderReconciliation =
      'total_tracker_notification_reconciliation';
  static const reminderUniqueName =
      'com.raffymanzo.totaltracker.reminders.reconcile';
}

class OpenNutritionBackgroundJobState {
  const OpenNutritionBackgroundJobState({
    required this.status,
    required this.stage,
    required this.message,
    required this.fraction,
    required this.parsedRows,
    required this.importedRows,
    required this.skippedRows,
    required this.failedRows,
  });

  final String status;
  final String stage;
  final String message;
  final double? fraction;
  final int parsedRows;
  final int importedRows;
  final int skippedRows;
  final int failedRows;

  bool get isRunning => status == 'queued' || status == 'running';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
}

class OpenNutritionBackgroundJobs {
  const OpenNutritionBackgroundJobs._();

  static const _uniqueName =
      'com.raffymanzo.totaltracker.opennutrition.import';
  static final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  static Future<void> initialize() async {
    await Workmanager().initialize(totalTrackerBackgroundDispatcher);
  }

  static Future<void> enqueueDownload({
    required int licenseAcceptedAtEpochMs,
  }) async {
    await _writeQueued();
    await Workmanager().registerOneOffTask(
      _uniqueName,
      TotalTrackerBackgroundTaskNames.openNutritionImport,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.connected),
      inputData: <String, dynamic>{
        'mode': 'download',
        'licenseAcceptedAtEpochMs': licenseAcceptedAtEpochMs,
      },
    );
  }

  static Future<void> enqueueLocalArchive({
    required File sourceFile,
    required int licenseAcceptedAtEpochMs,
  }) async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(path.join(support.path, 'background_imports'));
    await directory.create(recursive: true);
    final stableFile = File(
      path.join(
        directory.path,
        'opennutrition-${DateTime.now().millisecondsSinceEpoch}.zip',
      ),
    );
    await sourceFile.copy(stableFile.path);
    await _writeQueued();
    await Workmanager().registerOneOffTask(
      _uniqueName,
      TotalTrackerBackgroundTaskNames.openNutritionImport,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      inputData: <String, dynamic>{
        'mode': 'local',
        'archivePath': stableFile.path,
        'licenseAcceptedAtEpochMs': licenseAcceptedAtEpochMs,
      },
    );
  }

  static Future<void> cancel() async {
    await Workmanager().cancelByUniqueName(_uniqueName);
    await _setJobState(
      status: 'cancelled',
      stage: 'cancelled',
      message: 'Operazione annullata.',
    );
  }

  static Future<OpenNutritionBackgroundJobState> readState() async {
    return OpenNutritionBackgroundJobState(
      status: await _preferences.getString('on_job_status') ?? 'idle',
      stage: await _preferences.getString('on_job_stage') ?? '',
      message: await _preferences.getString('on_job_message') ?? '',
      fraction: await _preferences.getDouble('on_job_fraction'),
      parsedRows: await _preferences.getInt('on_job_parsed') ?? 0,
      importedRows: await _preferences.getInt('on_job_imported') ?? 0,
      skippedRows: await _preferences.getInt('on_job_skipped') ?? 0,
      failedRows: await _preferences.getInt('on_job_failed') ?? 0,
    );
  }

  static Future<void> _writeQueued() => _setJobState(
        status: 'queued',
        stage: 'queued',
        message: 'Operazione accodata in background.',
        fraction: 0,
      );

  static Future<void> _setJobState({
    required String status,
    required String stage,
    required String message,
    double? fraction,
    int parsedRows = 0,
    int importedRows = 0,
    int skippedRows = 0,
    int failedRows = 0,
  }) async {
    await _preferences.setString('on_job_status', status);
    await _preferences.setString('on_job_stage', stage);
    await _preferences.setString('on_job_message', message);
    if (fraction == null) {
      await _preferences.remove('on_job_fraction');
    } else {
      await _preferences.setDouble('on_job_fraction', fraction);
    }
    await _preferences.setInt('on_job_parsed', parsedRows);
    await _preferences.setInt('on_job_imported', importedRows);
    await _preferences.setInt('on_job_skipped', skippedRows);
    await _preferences.setInt('on_job_failed', failedRows);
  }
}

class ReminderBackgroundJobs {
  const ReminderBackgroundJobs._();

  static Timer? _foregroundTimer;

  static Future<void> reconcileRegistration() async {
    final enabled = await FoodServicePreferences.getBool(
      FoodServicePreferenceKeys.notificationsEnabled,
      defaultValue: false,
    );
    if (!enabled) {
      await Workmanager().cancelByUniqueName(
        TotalTrackerBackgroundTaskNames.reminderUniqueName,
      );
      return;
    }
    await Workmanager().registerPeriodicTask(
      TotalTrackerBackgroundTaskNames.reminderUniqueName,
      TotalTrackerBackgroundTaskNames.reminderReconciliation,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      frequency: const Duration(minutes: 15),
    );
  }

  static void startForegroundReconciliation(ObjectBoxDatabase database) {
    _foregroundTimer?.cancel();
    unawaited(_reconcileWithOpenDatabase(database));
    _foregroundTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => unawaited(_reconcileWithOpenDatabase(database)),
    );
  }
}

@pragma('vm:entry-point')
void totalTrackerBackgroundDispatcher() {
  Workmanager().executeTask((String task, Map<String, dynamic>? inputData) async {
    DartPluginRegistrant.ensureInitialized();
    await LocalNotificationService.initialize();
    if (task == TotalTrackerBackgroundTaskNames.openNutritionImport ||
        task == OpenNutritionBackgroundJobs._uniqueName) {
      return _runOpenNutritionImport(inputData ?? const <String, dynamic>{});
    }
    if (task == TotalTrackerBackgroundTaskNames.reminderReconciliation ||
        task == TotalTrackerBackgroundTaskNames.reminderUniqueName) {
      return _runReminderReconciliation();
    }
    return true;
  });
}

Future<bool> _runOpenNutritionImport(Map<String, dynamic> inputData) async {
  final database = OpenNutritionCatalogDatabase();
  final repository = OpenNutritionCatalogRepository(database);
  final service = OpenNutritionImportService(repository);
  final cancellation = OpenNutritionImportCancellation();
  final acceptedAt = inputData['licenseAcceptedAtEpochMs'] as int? ??
      DateTime.now().millisecondsSinceEpoch;
  final localPath = inputData['archivePath'] as String? ?? '';

  var deleteLocalArchive = true;
  try {
    await OpenNutritionBackgroundJobs._setJobState(
      status: 'running',
      stage: 'starting',
      message: 'Avvio importazione OpenNutrition.',
    );
    final stream = localPath.isNotEmpty
        ? service.importLocalArchive(
            archiveFile: File(localPath),
            licenseAcceptedAtEpochMs: acceptedAt,
            cancellation: cancellation,
          )
        : service.downloadAndImport(
            licenseAcceptedAtEpochMs: acceptedAt,
            cancellation: cancellation,
          );

    OpenNutritionImportProgress? last;
    await for (final progress in stream) {
      last = progress;
      await OpenNutritionBackgroundJobs._setJobState(
        status: 'running',
        stage: progress.stageCode,
        message: progress.message,
        fraction: progress.fraction,
        parsedRows: progress.parsedRows,
        importedRows: progress.importedRows,
        skippedRows: progress.skippedRows,
        failedRows: progress.failedRows,
      );
    }
    await OpenNutritionBackgroundJobs._setJobState(
      status: 'completed',
      stage: last?.stageCode ?? 'installed',
      message: last?.message ?? 'Catalogo installato.',
      fraction: 1,
      parsedRows: last?.parsedRows ?? 0,
      importedRows: last?.importedRows ?? 0,
      skippedRows: last?.skippedRows ?? 0,
      failedRows: last?.failedRows ?? 0,
    );
    final notificationsEnabled = await FoodServicePreferences.getBool(
      FoodServicePreferenceKeys.notificationsEnabled,
      defaultValue: false,
    );
    final operationNotifications = await FoodServicePreferences.getBool(
      FoodServicePreferenceKeys.backgroundOperationsEnabled,
    );
    if (notificationsEnabled && operationNotifications) {
      try {
        await LocalNotificationService.showBackgroundOperation(
          id: 4100,
          title: 'OpenNutrition pronto',
          body: '${last?.importedRows ?? 0} alimenti importati nel catalogo.',
        );
      } catch (_) {
        // The import result remains successful even if the OS blocks notices.
      }
    }
    return true;
  } catch (error) {
    await OpenNutritionBackgroundJobs._setJobState(
      status: 'failed',
      stage: 'failed',
      message: error.toString(),
    );
    final notificationsEnabled = await FoodServicePreferences.getBool(
      FoodServicePreferenceKeys.notificationsEnabled,
      defaultValue: false,
    );
    final operationNotifications = await FoodServicePreferences.getBool(
      FoodServicePreferenceKeys.backgroundOperationsEnabled,
    );
    if (notificationsEnabled && operationNotifications) {
      try {
        await LocalNotificationService.showBackgroundOperation(
          id: 4101,
          title: 'Importazione OpenNutrition non riuscita',
          body: 'Apri le impostazioni per consultare il dettaglio.',
        );
      } catch (_) {
        // The persistent job state still exposes the failure details.
      }
    }
    final retryable = _isRetryableBackgroundError(error);
    if (retryable && localPath.isNotEmpty) {
      deleteLocalArchive = false;
    }
    return !retryable;
  } finally {
    service.dispose();
    database.close();
    if (deleteLocalArchive && localPath.isNotEmpty) {
      final file = File(localPath);
      if (await file.exists()) await file.delete();
    }
  }
}

bool _isRetryableBackgroundError(Object error) {
  if (error is SocketException || error is TimeoutException) return true;
  final text = error.toString().toLowerCase();
  return text.contains('connection reset') ||
      text.contains('connection refused') ||
      text.contains('temporarily unavailable') ||
      text.contains('timed out') ||
      text.contains('network is unreachable') ||
      text.contains('failed host lookup');
}

Future<bool> _runReminderReconciliation() async {
  final database = ObjectBoxDatabase();
  try {
    await database.open();
    return await _reconcileWithOpenDatabase(database);
  } catch (_) {
    return false;
  } finally {
    await database.close();
  }
}

Future<bool> _reconcileWithOpenDatabase(ObjectBoxDatabase database) async {
  final master = await FoodServicePreferences.getBool(
    FoodServicePreferenceKeys.notificationsEnabled,
    defaultValue: false,
  );
  if (!master || !database.isOpen) return true;

  final now = DateTime.now();
  final storedReference = await FoodServicePreferences.getInt(
    FoodServicePreferenceKeys.notificationTrackingReferenceEpoch,
  );
  final referenceEpoch = storedReference ?? now.millisecondsSinceEpoch;
  if (storedReference == null) {
    await FoodServicePreferences.setInt(
      FoodServicePreferenceKeys.notificationTrackingReferenceEpoch,
      referenceEpoch,
    );
  }
  if (now.hour < 15) return true;

  try {
    final mealRepository = MealRepository(database.store);
    final measurementRepository = MeasurementRepository(database.store);
    final today = _dateKey(now);

    final mealEnabled = await FoodServicePreferences.getBool(
      FoodServicePreferenceKeys.mealReminderEnabled,
    );
    final hasRecordedMeal = mealRepository
        .getMealsWithItemsForDate(today)
        .any((MealWithItems meal) =>
            meal.items.isNotEmpty || meal.meal.mealModeCode == 'free');
    if (mealEnabled && !hasRecordedMeal) {
      final lastDate = await FoodServicePreferences.getString(
        FoodServicePreferenceKeys.lastMealReminderDate,
      );
      if (lastDate != today) {
        await LocalNotificationService.showReminder(
          id: 4200,
          title: 'Registra i pasti',
          body: 'Oggi non risulta ancora registrato alcun pasto.',
        );
        await FoodServicePreferences.setString(
          FoodServicePreferenceKeys.lastMealReminderDate,
          today,
        );
      }
    }

    final weightEnabled = await FoodServicePreferences.getBool(
      FoodServicePreferenceKeys.weightReminderEnabled,
    );
    final scaleValues = measurementRepository
        .getScaleMeasurements()
        .where((measurement) => measurement.weightKg != null)
        .toList();
    if (weightEnabled) {
      final latestDate = scaleValues.isNotEmpty
          ? scaleValues.first.dateKey
          : _dateKey(DateTime.fromMillisecondsSinceEpoch(referenceEpoch));
      final latest = _parseDateKey(latestDate);
      if (latest != null && now.difference(latest).inDays >= 7) {
        final lastReference = await FoodServicePreferences.getString(
          FoodServicePreferenceKeys.lastWeightReminderReference,
        );
        if (lastReference != latestDate) {
          await LocalNotificationService.showReminder(
            id: 4201,
            title: 'Aggiorna il peso',
            body: 'Non registri una pesata da almeno 7 giorni.',
          );
          await FoodServicePreferences.setString(
            FoodServicePreferenceKeys.lastWeightReminderReference,
            latestDate,
          );
        }
      }
    }

    final bodyEnabled = await FoodServicePreferences.getBool(
      FoodServicePreferenceKeys.bodyReminderEnabled,
    );
    final tapeValues = measurementRepository.getTapeMeasurements();
    if (bodyEnabled) {
      final latestDate = tapeValues.isNotEmpty
          ? tapeValues.first.dateKey
          : _dateKey(DateTime.fromMillisecondsSinceEpoch(referenceEpoch));
      final latest = _parseDateKey(latestDate);
      if (latest != null && !now.isBefore(_addCalendarMonths(latest, 2))) {
        final lastReference = await FoodServicePreferences.getString(
          FoodServicePreferenceKeys.lastBodyReminderReference,
        );
        if (lastReference != latestDate) {
          await LocalNotificationService.showReminder(
            id: 4202,
            title: 'Aggiorna le misurazioni corporee',
            body: 'Sono trascorsi almeno due mesi dall’ultima misurazione.',
          );
          await FoodServicePreferences.setString(
            FoodServicePreferenceKeys.lastBodyReminderReference,
            latestDate,
          );
        }
      }
    }
    return true;
  } catch (_) {
    return false;
  }
}

String _dateKey(DateTime value) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}

DateTime? _parseDateKey(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

DateTime _addCalendarMonths(DateTime value, int months) {
  final targetMonth = value.month - 1 + months;
  final year = value.year + targetMonth ~/ 12;
  final month = targetMonth % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = value.day > lastDay ? lastDay : value.day;
  return DateTime(year, month, day);
}
