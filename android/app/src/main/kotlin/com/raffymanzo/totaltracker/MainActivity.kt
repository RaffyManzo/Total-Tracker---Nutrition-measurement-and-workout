package com.raffymanzo.totaltracker

import android.Manifest
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "com.raffymanzo.totaltracker/device_permissions"
        const val REQUEST_NOTIFICATIONS = 7701
        const val REQUEST_CAMERA = 7702
    }

    private var notificationPermissionResult: MethodChannel.Result? = null
    private var cameraPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStatus" -> result.success(permissionStatus())
                    "requestNotifications" -> requestNotifications(result)
                    "requestCamera" -> requestCamera(result)
                    "openAppSettings" -> result.success(openAppSettings())
                    "openNotificationSettings" ->
                        result.success(openNotificationSettings())
                    "openBatteryOptimizationSettings" ->
                        result.success(openBatteryOptimizationSettings())
                    else -> result.notImplemented()
                }
            }
    }

    private fun permissionStatus(): Map<String, Any> {
        val notificationRuntimeGranted =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED

        val notificationsEnabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val manager = getSystemService(NotificationManager::class.java)
            manager?.areNotificationsEnabled() ?: false
        } else {
            true
        }

        val reminderChannelEnabled = notificationChannelEnabled(
            "total_tracker_reminders",
        )
        val backgroundChannelEnabled = notificationChannelEnabled(
            "total_tracker_background_operations",
        )

        val cameraGranted =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                checkSelfPermission(Manifest.permission.CAMERA) ==
                PackageManager.PERMISSION_GRANTED

        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        val batteryOptimizationIgnored =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                powerManager.isIgnoringBatteryOptimizations(packageName)

        return mapOf(
            "notificationRuntimeGranted" to notificationRuntimeGranted,
            "notificationsEnabled" to notificationsEnabled,
            "reminderChannelEnabled" to reminderChannelEnabled,
            "backgroundChannelEnabled" to backgroundChannelEnabled,
            "cameraGranted" to cameraGranted,
            "batteryOptimizationIgnored" to batteryOptimizationIgnored,
            "androidSdkInt" to Build.VERSION.SDK_INT,
        )
    }


    private fun notificationChannelEnabled(channelId: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        val manager = getSystemService(NotificationManager::class.java)
            ?: return false
        val channel = manager.getNotificationChannel(channelId) ?: return true
        return channel.importance != NotificationManager.IMPORTANCE_NONE
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(permissionStatus()["notificationsEnabled"] == true)
            return
        }
        if (notificationPermissionResult != null) {
            result.error(
                "request_in_progress",
                "Una richiesta del permesso notifiche è già in corso.",
                null,
            )
            return
        }
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }

        notificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_NOTIFICATIONS,
        )
    }

    private fun requestCamera(result: MethodChannel.Result) {
        if (cameraPermissionResult != null) {
            result.error(
                "request_in_progress",
                "Una richiesta del permesso fotocamera è già in corso.",
                null,
            )
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(true)
            return
        }
        if (checkSelfPermission(Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }

        cameraPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.CAMERA),
            REQUEST_CAMERA,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        when (requestCode) {
            REQUEST_NOTIFICATIONS -> {
                notificationPermissionResult?.success(granted)
                notificationPermissionResult = null
            }
            REQUEST_CAMERA -> {
                cameraPermissionResult?.success(granted)
                cameraPermissionResult = null
            }
        }
    }

    private fun openAppSettings(): Boolean {
        return startSettingsIntent(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            ),
        )
    }

    private fun openNotificationSettings(): Boolean {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
        } else {
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            )
        }
        return startSettingsIntent(intent)
    }

    private fun openBatteryOptimizationSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return openAppSettings()
        }
        return startSettingsIntent(
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
        )
    }

    private fun startSettingsIntent(intent: Intent): Boolean {
        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    override fun onDestroy() {
        notificationPermissionResult?.error(
            "activity_destroyed",
            "Activity chiusa durante la richiesta del permesso.",
            null,
        )
        cameraPermissionResult?.error(
            "activity_destroyed",
            "Activity chiusa durante la richiesta del permesso.",
            null,
        )
        notificationPermissionResult = null
        cameraPermissionResult = null
        super.onDestroy()
    }
}
