import SwiftUI
import UserNotifications

@main
struct AlarmApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// App Delegate to handle notifications and background tasks
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        return true
    }

    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification actions
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let alarmManager = AlarmManager.shared

        switch response.actionIdentifier {
        case "SNOOZE_ACTION":
            // Extract alarm ID from notification
            if let alarmId = response.notification.request.content.userInfo["alarmId"] as? String {
                alarmManager.handleSnooze(for: alarmId)
            }

        case "DISMISS_ACTION":
            // Just dismiss the notification
            break

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            break

        default:
            break
        }

        completionHandler()
    }
}
