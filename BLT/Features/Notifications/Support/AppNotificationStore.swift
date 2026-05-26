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

extension AppNotificationStore {
    static let mockNotifications: [AppNotificationItem] = [
        AppNotificationItem(
            id: "morning-measurement",
            category: .measurement,
            section: .today,
            icon: "🌅",
            title: "아침 측정 알림",
            message: "좋은 아침이에요! 오늘의 컨디션을 측정해보세요",
            timeText: "오늘 07:30",
            isRead: false
        ),
        AppNotificationItem(
            id: "caffeine-limit",
            category: .measurement,
            section: .today,
            icon: "☕",
            title: "오후 카페인 한도",
            message: "오늘은 14시 이후 카페인 섭취를 권장하지 않아요",
            timeText: "오늘 13:00",
            isRead: true
        ),
        AppNotificationItem(
            id: "bedtime-reminder",
            category: .measurement,
            section: .thisWeek,
            icon: "🌙",
            title: "취침 알림",
            message: "권장 취침 시각이에요. 오늘은 23:30에 주무세요",
            timeText: "어제 22:30",
            isRead: true
        ),
        AppNotificationItem(
            id: "weekly-report",
            category: .report,
            section: .thisWeek,
            icon: "📊",
            title: "주간 리포트 도착",
            message: "5월 둘째주 평균 Brain ROI 76점 · 전주 대비 ▲4%",
            timeText: "3일 전",
            isRead: true
        ),
        AppNotificationItem(
            id: "invalid-measurement",
            category: .measurement,
            section: .thisWeek,
            icon: "⚠️",
            title: "측정 무효 처리됨",
            message: "False Start 3회로 측정이 무효 처리되었어요.\n다시 측정해주세요",
            timeText: "5일 전",
            isRead: true
        )
    ]
}
