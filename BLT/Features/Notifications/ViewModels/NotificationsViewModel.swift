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
    private var fetchTask: Task<Void, Never>?

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

    var hasNotifications: Bool {
        !store.notifications.isEmpty
    }

    func selectCategory(_ category: AppNotificationCategory) {
        selectedCategory = category
        scheduleFetchNotifications()
    }

    func deleteAllNotifications() async {
        errorMessage = nil

        do {
            try await service.deleteAllNotifications()
            store.removeAll()
            errorMessage = nil
        } catch {
            errorMessage = "알림을 지우지 못했어요."
        }
    }

    func markNotificationAsRead(_ item: AppNotificationItem) async {
        guard !item.isRead else { return }

        errorMessage = nil
        store.updateReadState(id: item.id, isRead: true)

        do {
            try await service.markNotificationAsRead(id: item.id)
            errorMessage = nil
        } catch {
            store.updateReadState(id: item.id, isRead: false)
            errorMessage = "알림 읽음 처리에 실패했어요."
        }
    }

    func fetchNotifications() async {
        let requestedCategory = selectedCategory

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let notifications = try await service.fetchNotifications(category: requestedCategory)
            guard requestedCategory == selectedCategory else {
                scheduleFetchNotifications()
                return
            }
            store.applyServerNotifications(
                notifications
            )
        } catch {
            guard requestedCategory == selectedCategory else {
                scheduleFetchNotifications()
                return
            }
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

    private func scheduleFetchNotifications() {
        fetchTask?.cancel()
        fetchTask = Task { [weak self] in
            await self?.fetchNotifications()
        }
    }
}
