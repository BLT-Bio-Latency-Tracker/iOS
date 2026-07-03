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
