import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  const LocalNotificationService._();

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
    importance: Importance.defaultImportance,
  );

  static Future<void> initialize() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_reminderChannel);
    await android?.createNotificationChannel(_operationChannel);
    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final androidGranted = await android?.requestNotificationsPermission();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return androidGranted ?? iosGranted ?? true;
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
          channelDescription:
              'Stato di download e importazioni in background.',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
