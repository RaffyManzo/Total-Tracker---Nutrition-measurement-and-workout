import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DevicePermissionSnapshot {
  const DevicePermissionSnapshot({
    required this.notificationRuntimeGranted,
    required this.notificationsEnabled,
    required this.reminderChannelEnabled,
    required this.backgroundChannelEnabled,
    required this.cameraGranted,
    required this.batteryOptimizationIgnored,
    required this.androidSdkInt,
  });

  factory DevicePermissionSnapshot.fromMap(Map<Object?, Object?> map) {
    bool value(String key, {bool fallback = false}) {
      final Object? raw = map[key];
      return raw is bool ? raw : fallback;
    }

    int intValue(String key) {
      final Object? raw = map[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    return DevicePermissionSnapshot(
      notificationRuntimeGranted: value('notificationRuntimeGranted'),
      notificationsEnabled: value('notificationsEnabled'),
      reminderChannelEnabled: value('reminderChannelEnabled'),
      backgroundChannelEnabled: value('backgroundChannelEnabled'),
      cameraGranted: value('cameraGranted'),
      batteryOptimizationIgnored: value('batteryOptimizationIgnored'),
      androidSdkInt: intValue('androidSdkInt'),
    );
  }

  final bool notificationRuntimeGranted;
  final bool notificationsEnabled;
  final bool reminderChannelEnabled;
  final bool backgroundChannelEnabled;
  final bool cameraGranted;
  final bool batteryOptimizationIgnored;
  final int androidSdkInt;

  bool get notificationOperational =>
      notificationRuntimeGranted && notificationsEnabled;

  bool get reminderNotificationsOperational =>
      notificationOperational && reminderChannelEnabled;

  bool get backgroundNotificationsOperational =>
      notificationOperational && backgroundChannelEnabled;

  bool get allNotificationChannelsOperational =>
      reminderNotificationsOperational && backgroundNotificationsOperational;
}

class DevicePermissionService {
  const DevicePermissionService._();

  static const MethodChannel _channel = MethodChannel(
    'com.raffymanzo.totaltracker/device_permissions',
  );

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<DevicePermissionSnapshot> readStatus() async {
    if (!isAndroid) {
      return const DevicePermissionSnapshot(
        notificationRuntimeGranted: true,
        notificationsEnabled: true,
        reminderChannelEnabled: true,
        backgroundChannelEnabled: true,
        cameraGranted: true,
        batteryOptimizationIgnored: true,
        androidSdkInt: 0,
      );
    }

    final Map<Object?, Object?>? raw =
        await _channel.invokeMapMethod<Object?, Object?>('getStatus');
    if (raw == null) {
      throw PlatformException(
        code: 'missing_status',
        message: 'Android non ha restituito lo stato dei permessi.',
      );
    }
    return DevicePermissionSnapshot.fromMap(raw);
  }

  static Future<bool> requestNotifications() {
    return _invokeBool('requestNotifications');
  }

  static Future<bool> requestCamera() {
    return _invokeBool('requestCamera');
  }

  static Future<bool> openAppSettings() {
    return _invokeBool('openAppSettings');
  }

  static Future<bool> openNotificationSettings() {
    return _invokeBool('openNotificationSettings');
  }

  static Future<bool> openBatteryOptimizationSettings() {
    return _invokeBool('openBatteryOptimizationSettings');
  }

  static Future<bool> _invokeBool(String method) async {
    if (!isAndroid) return false;
    return await _channel.invokeMethod<bool>(method) ?? false;
  }
}
