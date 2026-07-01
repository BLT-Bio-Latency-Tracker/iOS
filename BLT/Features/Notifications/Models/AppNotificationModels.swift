import Foundation

struct AppNotificationItem: Identifiable, Equatable {
    let id: String
    let styleKey: AppNotificationStyleKey
    let category: AppNotificationCategory
    let section: AppNotificationSection
    let icon: String
    let title: String
    let message: String
    let timeText: String
    var isRead: Bool
}

enum AppNotificationStyleKey: String, Equatable {
    case morningMeasurement
    case sleepReminder
    case weeklyReport
    case invalidMeasurement
    case system
}

enum AppNotificationCategory: String, CaseIterable, Identifiable {
    case all
    case measurement
    case report

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "전체"
        case .measurement:
            return "측정 알림"
        case .report:
            return "리포트"
        }
    }
}

enum AppNotificationSection: String, CaseIterable, Identifiable {
    case today
    case thisWeek

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:
            return "오늘"
        case .thisWeek:
            return "이번 주"
        }
    }
}

struct AppNotificationSectionGroup: Identifiable, Equatable {
    let section: AppNotificationSection
    let items: [AppNotificationItem]

    var id: AppNotificationSection { section }
}
