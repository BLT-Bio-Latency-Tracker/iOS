import Foundation

enum TodayComparisonType: String, CaseIterable, Identifiable {
    case yesterday
    case lastSevenDays
    case myAverage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yesterday:
            return "어제"
        case .lastSevenDays:
            return "지난 7일"
        case .myAverage:
            return "내 평균"
        }
    }
}
