import Combine
import Foundation

@MainActor
final class AppNotificationStore: ObservableObject {
    static let shared = AppNotificationStore()

    @Published private(set) var notifications: [AppNotificationItem]

    var hasUnreadNotifications: Bool {
        notifications.contains { !$0.isRead }
    }

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
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

    func updateReadState(id: AppNotificationItem.ID, isRead: Bool) {
        notifications = notifications.map { item in
            guard item.id == id else { return item }
            var updatedItem = item
            updatedItem.isRead = isRead
            return updatedItem
        }
    }

    func removeAll() {
        notifications = []
    }

    func applyServerNotifications(_ serverNotifications: [AppNotificationItem]) {
        notifications = serverNotifications
    }
}
