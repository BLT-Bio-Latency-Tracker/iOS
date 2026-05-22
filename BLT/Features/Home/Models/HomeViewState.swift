import Foundation

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

