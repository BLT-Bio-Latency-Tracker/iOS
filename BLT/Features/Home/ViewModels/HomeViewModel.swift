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

struct HomeViewState {
    let userName: String
    let profileInitial: String
    let brainROI: Int
    let roiStatusText: String
    let roiChangePercent: Int
    let measuredAt: Date
    let sleepSummary: String
    let pvtSummary: String
    let recommendation: HomeRecommendation
    let nextRecommendation: HomeNextRecommendation
    let timelineSegments: [HomeTimelineSegment]

    static let placeholder: HomeViewState = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current

        let now = Date()
        let measuredAt = calendar.date(
            bySettingHour: 9,
            minute: 43,
            second: 0,
            of: now
        ) ?? now

        return HomeViewState(
            userName: "BLT",
            profileInitial: "B",
            brainROI: 78,
            roiStatusText: "안정적인 방전 상태",
            roiChangePercent: 12,
            measuredAt: measuredAt,
            sleepSummary: "Sleep 6h 40m",
            pvtSummary: "PVT 312ms",
            recommendation: HomeRecommendation(
                helperText: "지금이 가장 집중력이 좋은 시간이에요",
                title: "Deep Work · 09-12",
                description: "오전에 가장 어려운 일을 배치하세요.\n수면+PVT 데이터 기반 추천"
            ),
            nextRecommendation: HomeNextRecommendation(
                timeRange: "12-16",
                title: "창의·확산 사고"
            ),
            timelineSegments: [
                HomeTimelineSegment(startHour: 6, endHour: 9, kind: .rest),
                HomeTimelineSegment(startHour: 9, endHour: 12, kind: .deepWork),
                HomeTimelineSegment(startHour: 12, endHour: 16, kind: .collaboration),
                HomeTimelineSegment(startHour: 16, endHour: 18, kind: .caution),
                HomeTimelineSegment(startHour: 18, endHour: 23, kind: .recovery)
            ]
        )
    }()
}

struct HomeRecommendation {
    let helperText: String
    let title: String
    let description: String
}

struct HomeNextRecommendation {
    let timeRange: String
    let title: String
}

struct HomeTimelineSegment: Identifiable {
    let id = UUID()
    let startHour: Double
    let endHour: Double
    let kind: HomeTimelineSegmentKind
}

enum HomeTimelineSegmentKind {
    case rest
    case deepWork
    case collaboration
    case caution
    case recovery
}
