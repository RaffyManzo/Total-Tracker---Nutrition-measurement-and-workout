import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  const LocalNotificationService._();

  static const int importNotificationId = 4100;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const AndroidNotificationChannel _reminderChannel =
      AndroidNotificationChannel(
    'total_tracker_reminders',
    'Promemoria',
    description: 'Promemoria per pasti, peso e misurazioni corporee.',
    importance: Importance.defaultImportance,
  );

  static const AndroidNotificationChannel _operationChannel =
      AndroidNotificationChannel(
    'total_tracker_background_operations',
    'Operazioni in background',
    description: 'Stato di download e importazioni in background.',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  static Future<void> initialize() async {
    if (_initialized) return;
    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);

    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      _reminderChannel,
    );
    await android?.createNotificationChannel(
      _operationChannel,
    );
    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    await initialize();
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final IOSFlutterLocalNotificationsPlugin? ios =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    final bool? androidGranted =
        await android?.requestNotificationsPermission();
    final bool? iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return androidGranted ?? iosGranted ?? true;
  }

  static Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  static Future<void> cancel(int id) async {
    await initialize();
    await _plugin.cancel(id);
  }

  static Future<void> showReminder({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'total_tracker_reminders',
          'Promemoria',
          channelDescription:
              'Promemoria per pasti, peso e misurazioni corporee.',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> showBackgroundOperation({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'total_tracker_background_operations',
          'Operazioni in background',
          channelDescription: 'Stato di download e importazioni in background.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          onlyAlertOnce: true,
          ongoing: false,
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> showImportProgress({
    required String stage,
    required String message,
    required int percent,
  }) async {
    await initialize();
    final int safePercent = percent.clamp(0, 100).toInt();

    await _plugin.show(
      importNotificationId,
      'Importazione OpenNutrition · $safePercent%',
      '$stage · $message',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'total_tracker_background_operations',
          'Operazioni in background',
          channelDescription: 'Stato di download e importazioni in background.',
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          ongoing: true,
          autoCancel: false,
          showProgress: true,
          maxProgress: 100,
          progress: safePercent,
          playSound: false,
          enableVibration: false,
          category: AndroidNotificationCategory.progress,
        ),
        iOS: const DarwinNotificationDetails(
          presentSound: false,
        ),
      ),
    );
  }

  static Future<void> showImportCompleted({
    required int importedRows,
  }) async {
    await showBackgroundOperation(
      id: importNotificationId,
      title: 'OpenNutrition pronto',
      body: '$importedRows alimenti importati nel catalogo.',
    );
  }

  static Future<void> showImportFailed(
    String message,
  ) async {
    await showBackgroundOperation(
      id: importNotificationId,
      title: 'Importazione OpenNutrition non riuscita',
      body: message,
    );
  }

  static Future<void> showTestNotification() async {
    await showReminder(
      id: 4299,
      title: 'Notifiche Total Tracker',
      body: 'Le notifiche generali sono configurate correttamente.',
    );
  }
}
