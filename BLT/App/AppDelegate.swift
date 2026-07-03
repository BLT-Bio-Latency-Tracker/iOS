import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    private var hasAPNsToken = false

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            PushLog.debug("Firebase configured")
        }

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        PushLog.debug("App launched, start remote notification registration")
        registerForRemoteNotifications()

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        PushLog.debug("App became active, refresh remote notification registration")
        registerForRemoteNotifications()
        refreshFCMTokenIfAvailable()
        refreshNotificationStore()
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushLog.debug("APNs token registered")
        hasAPNsToken = true
        Messaging.messaging().apnsToken = deviceToken
        refreshFCMTokenIfAvailable()
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushLog.debug("APNs registration failed: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let keys = userInfo.keys.map { String(describing: $0) }
        PushLog.debug("Remote notification received: keys=\(keys)")
        Task {
            let result = await AppNotificationStore.shared.refreshFromServer(force: true)
            completionHandler(backgroundFetchResult(for: result))
        }
    }

    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard let fcmToken else {
            PushLog.debug("Messaging delegate returned nil FCM token")
            return
        }

        PushLog.debug("Messaging delegate received FCM token")

        Task {
            await PushDeviceRegistrationService.shared.updateFCMToken(fcmToken)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        refreshNotificationStore()
        return UNNotificationPresentationOptions([.banner, .list, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        handleNotificationTap(response.notification.request.content.userInfo)
    }

    private func handleNotificationTap(_ userInfo: [AnyHashable: Any]) {
        let keys = userInfo.keys.map { String(describing: $0) }
        PushLog.debug("Notification tapped: keys=\(keys)")
        refreshNotificationStore()
    }

    private func refreshNotificationStore() {
        Task {
            await AppNotificationStore.shared.refreshFromServer(force: true)
        }
    }

    private func backgroundFetchResult(for result: AppNotificationRefreshResult) -> UIBackgroundFetchResult {
        switch result {
        case .updated:
            return .newData
        case .unchanged:
            return .noData
        case .failed:
            return .failed
        }
    }

    private func refreshFCMTokenIfAvailable() {
        guard hasAPNsToken else {
            PushLog.debug("Skip FCM token refresh: missing APNs token")
            return
        }

        PushLog.debug("Request FCM token refresh")
        Messaging.messaging().token { token, error in
            if let error {
                PushLog.debug("FCM token refresh failed: \(error.localizedDescription)")
                return
            }

            guard let token else {
                PushLog.debug("FCM token refresh returned nil")
                return
            }

            PushLog.debug("FCM token refresh succeeded")
            Task {
                await PushDeviceRegistrationService.shared.updateFCMToken(token)
            }
        }
    }

    private func registerForRemoteNotifications() {
        Task { @MainActor in
            PushLog.debug("Request APNs registration")
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}
