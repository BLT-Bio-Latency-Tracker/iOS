import Foundation
import SwiftUI

struct HistoryDailyRecord: Identifiable, Equatable {
    let date: Date
    let roiScore: Int
    let measuredAt: Date?

    init(date: Date, roiScore: Int, measuredAt: Date? = nil) {
        self.date = date
        self.roiScore = roiScore
        self.measuredAt = measuredAt
    }

    var id: Date { Calendar.current.startOfDay(for: date) }
}

enum HistoryROILevel: Equatable {
    case excellent
    case good
    case caution
    case low
    case empty

    init(score: Int?) {
        guard let score else {
            self = .empty
            return
        }

        switch score {
        case 80...:
            self = .excellent
        case 65...79:
            self = .good
        case 50...64:
            self = .caution
        default:
            self = .low
        }
    }

    var color: Color {
        switch self {
        case .excellent:
            return Color(red: 0.063, green: 0.725, blue: 0.506)
        case .good:
            return Color(red: 0.133, green: 0.827, blue: 0.933)
        case .caution:
            return Color(red: 0.961, green: 0.62, blue: 0.043)
        case .low:
            return Color(red: 0.937, green: 0.267, blue: 0.267)
        case .empty:
            return Color(red: 0.45, green: 0.47, blue: 0.6)
        }
    }
}

enum HistoryEvaluationDateResolver {
    static func recordDate(
        measuredAt: Date,
        sleepDateText: String?,
        calendar: Calendar = koreaCalendar
    ) -> Date {
        if let sleepDateText,
           let sleepDate = sleepDateFormatter.date(from: sleepDateText) {
            return calendar.startOfDay(for: sleepDate)
        }

        return calendarRecordDate(for: measuredAt, calendar: calendar)
    }

    static func calendarRecordDate(
        for measuredAt: Date,
        calendar: Calendar = koreaCalendar
    ) -> Date {
        calendar.startOfDay(for: measuredAt)
    }

    static func measurementServiceDate(
        for measuredAt: Date,
        calendar: Calendar = koreaCalendar
    ) -> Date {
        let interval = EvaluationService.measurementDayInterval(containing: measuredAt)
        return calendar.startOfDay(for: interval.start)
    }

    static func isRecord(
        measuredAt: Date,
        sleepDateText: String?,
        in selectedDate: Date,
        calendar: Calendar = koreaCalendar
    ) -> Bool {
        let date = recordDate(
            measuredAt: measuredAt,
            sleepDateText: sleepDateText,
            calendar: calendar
        )
        return calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private static let sleepDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static var koreaCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }
}
