import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        refreshFCMTokenIfAvailable()

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        refreshFCMTokenIfAvailable()
    }

    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard let fcmToken else { return }

        Task {
            await PushDeviceRegistrationService.shared.updateFCMToken(fcmToken)
        }
    }

    private func refreshFCMTokenIfAvailable() {
        Messaging.messaging().token { token, _ in
            guard let token else { return }

            Task {
                await PushDeviceRegistrationService.shared.updateFCMToken(token)
            }
        }
    }
}
