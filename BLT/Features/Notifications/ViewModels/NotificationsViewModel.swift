import Combine
import Foundation

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var selectedCategory: AppNotificationCategory = .all
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let store: AppNotificationStore
    private let service: NotificationsService
    private var cancellables = Set<AnyCancellable>()

    init(store: AppNotificationStore? = nil, service: NotificationsService = NotificationsService()) {
        self.store = store ?? .shared
        self.service = service

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
        Task {
            await fetchNotifications()
        }
    }

    func markAllAsRead() async {
        do {
            try await service.markAllAsRead()
            store.markAllAsRead()
        } catch {
            errorMessage = "알림 읽음 처리에 실패했어요."
        }
    }

    func fetchNotifications() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            store.applyServerNotifications(
                try await service.fetchNotifications(category: selectedCategory)
            )
        } catch {
            errorMessage = "알림을 불러오지 못했어요."
            store.applyServerNotifications([])
        }
    }

    func applyServerNotifications(_ serverNotifications: [AppNotificationItem]) {
        store.applyServerNotifications(serverNotifications)
    }

    private func matchesSelectedCategory(_ item: AppNotificationItem) -> Bool {
        selectedCategory == .all || item.category == selectedCategory
    }
}
