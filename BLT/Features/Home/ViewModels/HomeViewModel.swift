import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var state: HomeViewState
    @Published private(set) var currentDate: Date

    private let calendar: Calendar
    private let timeFormatter: DateFormatter

    init(
        state: HomeViewState? = nil,
        currentDate: Date = Date()
    ) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        self.calendar = calendar

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "HH:mm"
        self.timeFormatter = formatter

        self.state = state ?? HomeViewState.placeholder
        self.currentDate = currentDate
    }

    var greetingText: String {
        let hour = calendar.component(.hour, from: currentDate)

        switch hour {
        case 5..<12:
            return "좋은 아침이에요,"
        case 12..<18:
            return "좋은 오후예요,"
        default:
            return "좋은 저녁이에요,"
        }
    }

    var measurementSummaryText: String {
        "오늘 \(timeFormatter.string(from: state.measuredAt)) 측정 · \(state.sleepSummary) + \(state.pvtSummary)"
    }

    var currentTimeProgress: Double {
        let hour = Double(calendar.component(.hour, from: currentDate))
        let minute = Double(calendar.component(.minute, from: currentDate))
        let currentHour = hour + minute / 60
        return min(max((currentHour - 6) / 17, 0), 1)
    }

    func updateCurrentDate(_ date: Date) {
        currentDate = date
    }
}
