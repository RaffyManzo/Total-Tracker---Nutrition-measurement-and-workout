import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/core/platform/device_permission_service.dart';

void main() {
  test('decodes Android permission status defensively', () {
    final DevicePermissionSnapshot value =
        DevicePermissionSnapshot.fromMap(<Object?, Object?>{
      'notificationRuntimeGranted': true,
      'notificationsEnabled': false,
      'reminderChannelEnabled': true,
      'backgroundChannelEnabled': false,
      'cameraGranted': true,
      'batteryOptimizationIgnored': false,
      'androidSdkInt': 35,
    });

    expect(value.notificationRuntimeGranted, isTrue);
    expect(value.notificationsEnabled, isFalse);
    expect(value.notificationOperational, isFalse);
    expect(value.reminderChannelEnabled, isTrue);
    expect(value.backgroundChannelEnabled, isFalse);
    expect(value.allNotificationChannelsOperational, isFalse);
    expect(value.cameraGranted, isTrue);
    expect(value.batteryOptimizationIgnored, isFalse);
    expect(value.androidSdkInt, 35);
  });

  test('uses safe defaults for malformed platform values', () {
    final DevicePermissionSnapshot value =
        DevicePermissionSnapshot.fromMap(<Object?, Object?>{
      'androidSdkInt': '34',
    });

    expect(value.notificationRuntimeGranted, isFalse);
    expect(value.notificationsEnabled, isFalse);
    expect(value.reminderChannelEnabled, isFalse);
    expect(value.backgroundChannelEnabled, isFalse);
    expect(value.cameraGranted, isFalse);
    expect(value.androidSdkInt, 34);
  });
}
