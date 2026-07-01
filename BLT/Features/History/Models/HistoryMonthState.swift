import Foundation

struct HistoryMonthState: Equatable {
    let month: Date
    let days: [HistoryCalendarDay]
    let summary: HistoryMonthSummary

    func replacingSummary(_ summary: HistoryMonthSummary) -> HistoryMonthState {
        HistoryMonthState(month: month, days: days, summary: summary)
    }
}

struct HistoryCalendarDay: Identifiable, Equatable {
    let id: String
    let date: Date?
    let day: Int?
    let roiScore: Int?
    let isToday: Bool

    var hasRecord: Bool {
        roiScore != nil
    }
}

struct HistoryMonthSummary: Equatable {
    let measuredDays: Int
    let averageROI: Int?
    let bestROI: Int?
    let lowestROI: Int?

    var hasData: Bool {
        measuredDays > 0
    }
}
