import Combine
import Foundation

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var selectedCategory: AppNotificationCategory = .all

    private let store: AppNotificationStore
    private var cancellables = Set<AnyCancellable>()

    init(store: AppNotificationStore? = nil) {
        self.store = store ?? .shared

        self.store.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var sectionGroups: [AppNotificationSectionGroup] {
        AppNotificationSection.allCases.compactMap { section in
            let filteredItems = store.notifications.filter { item in
                item.section == section && matchesSelectedCategory(item)
            }

            guard !filteredItems.isEmpty else { return nil }
            return AppNotificationSectionGroup(section: section, items: filteredItems)
        }
    }

    var hasUnreadNotifications: Bool {
        store.hasUnreadNotifications
    }

    func selectCategory(_ category: AppNotificationCategory) {
        selectedCategory = category
    }

    func markAllAsRead() {
        store.markAllAsRead()
    }

    func applyServerNotifications(_ serverNotifications: [AppNotificationItem]) {
        store.applyServerNotifications(serverNotifications)
    }

    private func matchesSelectedCategory(_ item: AppNotificationItem) -> Bool {
        selectedCategory == .all || item.category == selectedCategory
    }
}
