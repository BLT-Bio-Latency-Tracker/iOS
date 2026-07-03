import Combine
import Foundation

enum AppNotificationRefreshResult {
    case updated
    case unchanged
    case failed
}

@MainActor
final class AppNotificationStore: ObservableObject {
    static let shared = AppNotificationStore()

    @Published private(set) var notifications: [AppNotificationItem]
    private let service: NotificationsService
    private var refreshTask: Task<AppNotificationRefreshResult, Never>?
    private var lastRefreshedAt: Date?
    private var pendingReadIDs = Set<AppNotificationItem.ID>()

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

    @discardableResult
    func refreshFromServer(force: Bool = false) async -> AppNotificationRefreshResult {
        if !force,
           let lastRefreshedAt,
           Date().timeIntervalSince(lastRefreshedAt) < 30 {
            return .unchanged
        }

        refreshTask?.cancel()
        let task = Task { [service] in
            do {
                let serverNotifications = try await service.fetchNotifications(category: .all)
                guard !Task.isCancelled else { return AppNotificationRefreshResult.unchanged }

                return await MainActor.run {
                    let didUpdate = self.applyServerNotifications(serverNotifications)
                    self.lastRefreshedAt = Date()
                    return didUpdate ? .updated : .unchanged
                }
            } catch {
#if DEBUG
                print("[Notifications] Refresh failed: \(error.localizedDescription)")
#endif
                return .failed
            }
        }
        refreshTask = task
        return await task.value
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

    func markAsReadPending(id: AppNotificationItem.ID) {
        pendingReadIDs.insert(id)
        updateReadState(id: id, isRead: true)
    }

    func revertPendingRead(id: AppNotificationItem.ID) {
        pendingReadIDs.remove(id)
        updateReadState(id: id, isRead: false)
    }

    func removeAll() {
        notifications = []
    }

    @discardableResult
    func applyServerNotifications(_ serverNotifications: [AppNotificationItem]) -> Bool {
        let confirmedReadIDs = serverNotifications
            .filter { pendingReadIDs.contains($0.id) && $0.isRead }
            .map(\.id)
        pendingReadIDs.subtract(confirmedReadIDs)

        let reconciledNotifications = serverNotifications.map { item in
            guard pendingReadIDs.contains(item.id) else { return item }
            var updatedItem = item
            updatedItem.isRead = true
            return updatedItem
        }
        let didUpdate = notifications != reconciledNotifications
        notifications = reconciledNotifications
        return didUpdate
    }
}
