import Combine
import Foundation

@MainActor
final class AppNotificationStore: ObservableObject {
    static let shared = AppNotificationStore()

    @Published private(set) var notifications: [AppNotificationItem]
    private let service: NotificationsService
    private var refreshTask: Task<Void, Never>?
    private var lastRefreshedAt: Date?

    var hasUnreadNotifications: Bool {
        notifications.contains { !$0.isRead }
    }

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    init(
        notifications: [AppNotificationItem] = [],
        service: NotificationsService = NotificationsService()
    ) {
        self.notifications = notifications
        self.service = service
    }

    func refreshFromServer(force: Bool = false) async {
        if !force,
           let lastRefreshedAt,
           Date().timeIntervalSince(lastRefreshedAt) < 30 {
            return
        }

        refreshTask?.cancel()
        let task = Task { [service] in
            do {
                let serverNotifications = try await service.fetchNotifications(category: .all)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.applyServerNotifications(serverNotifications)
                    self.lastRefreshedAt = Date()
                }
            } catch {
#if DEBUG
                print("[Notifications] Refresh failed: \(error.localizedDescription)")
#endif
            }
        }
        refreshTask = task
        await task.value
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
