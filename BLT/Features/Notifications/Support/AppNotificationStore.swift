import Combine
import Foundation

@MainActor
final class AppNotificationStore: ObservableObject {
    static let shared = AppNotificationStore()

    @Published private(set) var notifications: [AppNotificationItem]

    var hasUnreadNotifications: Bool {
        notifications.contains { !$0.isRead }
    }

    init(notifications: [AppNotificationItem] = []) {
        self.notifications = notifications
    }

    func markAllAsRead() {
        notifications = notifications.map { item in
            var updatedItem = item
            updatedItem.isRead = true
            return updatedItem
        }
    }

    func applyServerNotifications(_ serverNotifications: [AppNotificationItem]) {
        notifications = serverNotifications
    }
}
