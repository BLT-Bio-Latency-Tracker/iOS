import Foundation

struct NotificationsService {
    private let networkClient: NetworkClient

    init(networkClient: NetworkClient = .shared) {
        self.networkClient = networkClient
    }

    func fetchNotifications(category: AppNotificationCategory) async throws -> [AppNotificationItem] {
        let response: NotificationPageResponse = try await networkClient.get(
            "/api/v1/notifications",
            queryItems: [
                URLQueryItem(name: "category", value: category.serverValue),
                URLQueryItem(name: "page", value: "0"),
                URLQueryItem(name: "size", value: "100")
            ],
            requiresAuth: true
        )

        return response.items.map(\.appNotificationItem)
    }

    func deleteAllNotifications() async throws {
        let _: EmptyResponse = try await networkClient.delete(
            "/api/v1/notifications",
            requiresAuth: true
        )
    }
}

private struct NotificationPageResponse: Decodable {
    let items: [NotificationItemResponse]
}

private struct NotificationItemResponse: Decodable {
    let logId: Int
    let notificationType: NotificationType
    let title: String
    let body: String
    let isRead: Bool
    let scheduledAt: Date

    var appNotificationItem: AppNotificationItem {
        AppNotificationItem(
            id: String(logId),
            styleKey: notificationType.styleKey,
            category: notificationType.category,
            section: scheduledAt.notificationSection,
            icon: notificationType.icon,
            title: title,
            message: body,
            timeText: scheduledAt.notificationRelativeText,
            isRead: isRead
        )
    }
}

private enum NotificationType: String, Decodable {
    case pvtReminder = "PVT_REMINDER"
    case sleepReminder = "SLEEP_REMINDER"
    case roiScore = "ROI_SCORE"
    case recommendation = "RECOMMENDATION"
    case system = "SYSTEM"

    var category: AppNotificationCategory {
        switch self {
        case .roiScore, .recommendation:
            return .report
        case .pvtReminder, .sleepReminder, .system:
            return .measurement
        }
    }

    var icon: String {
        switch self {
        case .pvtReminder:
            return "🌅"
        case .sleepReminder:
            return "🌙"
        case .roiScore, .recommendation:
            return "📊"
        case .system:
            return "⚠️"
        }
    }

    var styleKey: AppNotificationStyleKey {
        switch self {
        case .pvtReminder:
            return .morningMeasurement
        case .sleepReminder:
            return .sleepReminder
        case .roiScore, .recommendation:
            return .weeklyReport
        case .system:
            return .invalidMeasurement
        }
    }
}

private extension AppNotificationCategory {
    var serverValue: String {
        switch self {
        case .all:
            return "ALL"
        case .measurement:
            return "MEASUREMENT"
        case .report:
            return "REPORT"
        }
    }
}

private extension Date {
    var notificationSection: AppNotificationSection {
        Calendar.bltNotification.isDateInToday(self) ? .today : .thisWeek
    }

    var notificationRelativeText: String {
        let calendar = Calendar.bltNotification
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "HH:mm"

        if calendar.isDateInToday(self) {
            return "오늘 \(formatter.string(from: self))"
        }

        if calendar.isDateInYesterday(self) {
            return "어제 \(formatter.string(from: self))"
        }

        let day = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: self),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0
        return "\(max(day, 1))일 전"
    }
}

private extension Calendar {
    static var bltNotification: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }
}
