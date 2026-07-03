import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
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
    required this.jobId,
    required this.appVersion,
    required this.queuedAtEpochMs,
    required this.startedAtEpochMs,
    required this.heartbeatAtEpochMs,
    required this.completedAtEpochMs,
  });

  final String status;
  final String stage;
  final String message;
  final double? fraction;
  final int parsedRows;
  final int importedRows;
  final int skippedRows;
  final int failedRows;
  final String jobId;
  final String appVersion;
  final int queuedAtEpochMs;
  final int startedAtEpochMs;
  final int heartbeatAtEpochMs;
  final int completedAtEpochMs;

  bool get isRunning => status == 'queued' || status == 'running';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  int get percent => ((fraction ?? 0) * 100).round().clamp(0, 100).toInt();
}

class OpenNutritionBackgroundJobs {
  const OpenNutritionBackgroundJobs._();

  static const String _uniqueName =
      'com.raffymanzo.totaltracker.opennutrition.import';
  static final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  static Future<void> initialize() async {
    await Workmanager().initialize(totalTrackerBackgroundDispatcher);
  }

  static Future<void> enqueueDownload({
    required int licenseAcceptedAtEpochMs,
  }) async {
    final Map<String, dynamic> metadata = await _newJobMetadata();
    await _writeQueued(metadata);
    await _showQueuedNotification();
    await Workmanager().registerOneOffTask(
      _uniqueName,
      TotalTrackerBackgroundTaskNames.openNutritionImport,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.connected),
      inputData: <String, dynamic>{
        'mode': 'download',
        'licenseAcceptedAtEpochMs': licenseAcceptedAtEpochMs,
        ...metadata,
      },
    );
  }

  static Future<void> enqueueLocalArchive({
    required File sourceFile,
    required int licenseAcceptedAtEpochMs,
  }) async {
    final Directory support = await getApplicationSupportDirectory();
    final Directory directory =
        Directory(path.join(support.path, 'background_imports'));
    await directory.create(recursive: true);
    final File stableFile = File(
      path.join(
        directory.path,
        'opennutrition-${DateTime.now().millisecondsSinceEpoch}.zip',
      ),
    );
    await sourceFile.copy(stableFile.path);

    final Map<String, dynamic> metadata = await _newJobMetadata();
    await _writeQueued(metadata);
    await _showQueuedNotification();
    await Workmanager().registerOneOffTask(
      _uniqueName,
      TotalTrackerBackgroundTaskNames.openNutritionImport,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      inputData: <String, dynamic>{
        'mode': 'local',
        'archivePath': stableFile.path,
        'licenseAcceptedAtEpochMs': licenseAcceptedAtEpochMs,
        ...metadata,
      },
    );
  }

  static Future<Map<String, dynamic>> _newJobMetadata() async {
    String appVersion = '';
    try {
      final PackageInfo package = await PackageInfo.fromPlatform();
      appVersion = '${package.version}+${package.buildNumber}';
    } catch (_) {
      // Il job resta eseguibile anche senza metadati del pacchetto.
    }
    return <String, dynamic>{
      'jobId': const Uuid().v4(),
      'appVersion': appVersion,
    };
  }

  static Future<void> _showQueuedNotification() async {
    if (!await _operationNotificationsEnabled()) return;
    try {
      await LocalNotificationService.showImportProgress(
        stage: 'In coda',
        message: 'In attesa dell’avvio del worker.',
        percent: 0,
      );
    } catch (_) {
      // Lo stato persistente continua a essere disponibile.
    }
  }

  static Future<void> cancel() async {
    await Workmanager().cancelByUniqueName(_uniqueName);
    final int now = DateTime.now().millisecondsSinceEpoch;
    await _setJobState(
      status: 'cancelled',
      stage: 'cancelled',
      message: 'Operazione annullata.',
      heartbeatAtEpochMs: now,
      completedAtEpochMs: now,
    );
    try {
      await LocalNotificationService.cancel(
        LocalNotificationService.importNotificationId,
      );
    } catch (_) {
      // La cancellazione del job non dipende dalla notifica.
    }
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
      jobId: await _preferences.getString('on_job_id') ?? '',
      appVersion: await _preferences.getString('on_job_app_version') ?? '',
      queuedAtEpochMs: await _preferences.getInt('on_job_queued_at') ?? 0,
      startedAtEpochMs: await _preferences.getInt('on_job_started_at') ?? 0,
      heartbeatAtEpochMs: await _preferences.getInt('on_job_heartbeat_at') ?? 0,
      completedAtEpochMs: await _preferences.getInt('on_job_completed_at') ?? 0,
    );
  }

  static Future<void> _writeQueued(
    Map<String, dynamic> metadata,
  ) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    await _setJobState(
      status: 'queued',
      stage: 'queued',
      message: 'Operazione accodata in background.',
      fraction: 0,
      jobId: metadata['jobId'] as String? ?? '',
      appVersion: metadata['appVersion'] as String? ?? '',
      queuedAtEpochMs: now,
      startedAtEpochMs: 0,
      heartbeatAtEpochMs: now,
      completedAtEpochMs: 0,
    );
  }

  static Future<void> _setJobState({
    required String status,
    required String stage,
    required String message,
    double? fraction,
    int parsedRows = 0,
    int importedRows = 0,
    int skippedRows = 0,
    int failedRows = 0,
    String? jobId,
    String? appVersion,
    int? queuedAtEpochMs,
    int? startedAtEpochMs,
    int? heartbeatAtEpochMs,
    int? completedAtEpochMs,
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
    if (jobId != null) {
      await _preferences.setString('on_job_id', jobId);
    }
    if (appVersion != null) {
      await _preferences.setString('on_job_app_version', appVersion);
    }
    if (queuedAtEpochMs != null) {
      await _preferences.setInt('on_job_queued_at', queuedAtEpochMs);
    }
    if (startedAtEpochMs != null) {
      await _preferences.setInt('on_job_started_at', startedAtEpochMs);
    }
    if (heartbeatAtEpochMs != null) {
      await _preferences.setInt('on_job_heartbeat_at', heartbeatAtEpochMs);
    }
    if (completedAtEpochMs != null) {
      await _preferences.setInt('on_job_completed_at', completedAtEpochMs);
    }
  }

  static Future<bool> _operationNotificationsEnabled() async {
    final bool master = await FoodServicePreferences.getBool(
      FoodServicePreferenceKeys.notificationsEnabled,
      defaultValue: false,
    );
    final bool operations = await FoodServicePreferences.getBool(
      FoodServicePreferenceKeys.backgroundOperationsEnabled,
    );
    return master && operations;
  }

  static String stageLabel(String stageCode) {
    return switch (stageCode) {
      'queued' => 'In coda',
      'starting' => 'Avvio',
      'downloading' => 'Download',
      'verifying' => 'Verifica',
      'extracting' => 'Estrazione',
      'validating_schema' => 'Validazione',
      'converting' => 'Importazione',
      'indexing' => 'Creazione indici',
      'activating' => 'Attivazione',
      'installed' => 'Completato',
      'cancelled' => 'Annullato',
      'failed' => 'Errore',
      _ => stageCode.isEmpty ? 'Importazione' : stageCode,
    };
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
  Workmanager().executeTask((
    String task,
    Map<String, dynamic>? inputData,
  ) async {
    DartPluginRegistrant.ensureInitialized();
    if (task == TotalTrackerBackgroundTaskNames.openNutritionImport ||
        task == OpenNutritionBackgroundJobs._uniqueName) {
      return _runOpenNutritionImport(
        inputData ?? const <String, dynamic>{},
      );
    }

    try {
      await LocalNotificationService.initialize();
    } catch (_) {
      // I reminder restano fail-soft se il plugin non è disponibile.
    }

    if (task == TotalTrackerBackgroundTaskNames.reminderReconciliation ||
        task == TotalTrackerBackgroundTaskNames.reminderUniqueName) {
      return _runReminderReconciliation();
    }
    return true;
  });
}

Future<bool> _runOpenNutritionImport(
  Map<String, dynamic> inputData,
) async {
  final OpenNutritionCatalogDatabase database = OpenNutritionCatalogDatabase();
  final OpenNutritionCatalogRepository repository =
      OpenNutritionCatalogRepository(database);
  final OpenNutritionImportService service =
      OpenNutritionImportService(repository);
  final OpenNutritionImportCancellation cancellation =
      OpenNutritionImportCancellation();
  final int acceptedAt = inputData['licenseAcceptedAtEpochMs'] as int? ??
      DateTime.now().millisecondsSinceEpoch;
  final String localPath = inputData['archivePath'] as String? ?? '';
  final String jobId = inputData['jobId'] as String? ?? '';
  final String appVersion = inputData['appVersion'] as String? ?? '';

  var deleteLocalArchive = true;
  var lastNotificationPercent = -1;
  var lastNotificationStage = '';

  try {
    final int startedAt = DateTime.now().millisecondsSinceEpoch;
    await OpenNutritionBackgroundJobs._setJobState(
      status: 'running',
      stage: 'starting',
      message: 'Avvio importazione OpenNutrition.',
      fraction: 0,
      jobId: jobId,
      appVersion: appVersion,
      startedAtEpochMs: startedAt,
      heartbeatAtEpochMs: startedAt,
    );

    try {
      await LocalNotificationService.initialize();
      if (await OpenNutritionBackgroundJobs._operationNotificationsEnabled()) {
        await LocalNotificationService.showImportProgress(
          stage: 'Avvio',
          message: 'Preparazione del catalogo.',
          percent: 0,
        );
      }
    } catch (_) {
      // Il worker non resta in coda se il plugin notifiche fallisce.
    }

    final Stream<OpenNutritionImportProgress> stream = localPath.isNotEmpty
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
    await for (final OpenNutritionImportProgress progress in stream) {
      last = progress;
      final int percent =
          ((progress.fraction ?? 0) * 100).round().clamp(0, 100).toInt();
      final int now = DateTime.now().millisecondsSinceEpoch;

      await OpenNutritionBackgroundJobs._setJobState(
        status: 'running',
        stage: progress.stageCode,
        message: progress.message,
        fraction: progress.fraction,
        parsedRows: progress.parsedRows,
        importedRows: progress.importedRows,
        skippedRows: progress.skippedRows,
        failedRows: progress.failedRows,
        jobId: jobId,
        appVersion: appVersion,
        heartbeatAtEpochMs: now,
      );

      if ((percent != lastNotificationPercent ||
              progress.stageCode != lastNotificationStage) &&
          await OpenNutritionBackgroundJobs._operationNotificationsEnabled()) {
        lastNotificationPercent = percent;
        lastNotificationStage = progress.stageCode;
        try {
          await LocalNotificationService.showImportProgress(
            stage: OpenNutritionBackgroundJobs.stageLabel(
              progress.stageCode,
            ),
            message: progress.message,
            percent: percent,
          );
        } catch (_) {
          // Lo stato persistente resta la fonte primaria.
        }
      }
    }

    final int completedAt = DateTime.now().millisecondsSinceEpoch;
    await OpenNutritionBackgroundJobs._setJobState(
      status: 'completed',
      stage: last?.stageCode ?? 'installed',
      message: last?.message ?? 'Catalogo installato.',
      fraction: 1,
      parsedRows: last?.parsedRows ?? 0,
      importedRows: last?.importedRows ?? 0,
      skippedRows: last?.skippedRows ?? 0,
      failedRows: last?.failedRows ?? 0,
      jobId: jobId,
      appVersion: appVersion,
      heartbeatAtEpochMs: completedAt,
      completedAtEpochMs: completedAt,
    );

    if (await OpenNutritionBackgroundJobs._operationNotificationsEnabled()) {
      try {
        await LocalNotificationService.showImportCompleted(
          importedRows: last?.importedRows ?? 0,
        );
      } catch (_) {
        // Il risultato dell'import non dipende dalla notifica.
      }
    }
    return true;
  } catch (error) {
    final int failedAt = DateTime.now().millisecondsSinceEpoch;
    await OpenNutritionBackgroundJobs._setJobState(
      status: 'failed',
      stage: 'failed',
      message: error.toString(),
      jobId: jobId,
      appVersion: appVersion,
      heartbeatAtEpochMs: failedAt,
      completedAtEpochMs: failedAt,
    );

    if (await OpenNutritionBackgroundJobs._operationNotificationsEnabled()) {
      try {
        await LocalNotificationService.showImportFailed(
          'Apri le impostazioni OpenNutrition per i dettagli.',
        );
      } catch (_) {
        // Lo stato persistente espone comunque il dettaglio.
      }
    }

    final bool retryable = _isRetryableBackgroundError(error);
    if (retryable && localPath.isNotEmpty) {
      deleteLocalArchive = false;
    }
    return !retryable;
  } finally {
    service.dispose();
    database.close();
    if (deleteLocalArchive && localPath.isNotEmpty) {
      final File file = File(localPath);
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
    final hasRecordedMeal = mealRepository.getMealsWithItemsForDate(today).any(
        (MealWithItems meal) =>
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
