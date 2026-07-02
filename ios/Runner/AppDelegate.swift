import Flutter
import UIKit
import UserNotifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate =
        self as? UNUserNotificationCenterDelegate
    }
    WorkmanagerPlugin.registerBGProcessingTask(
      withIdentifier: "com.raffymanzo.totaltracker.opennutrition.import"
    )
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.raffymanzo.totaltracker.reminders.reconcile",
      frequency: NSNumber(value: 15 * 60)
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
