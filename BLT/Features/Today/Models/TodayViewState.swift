import Foundation

struct TodayViewState {
    let score: Int
    let scoreMode: TodayScoreMode
    let roiStatusText: String
    let roiChangePercent: Int
    let measuredAt: Date
    let comparisonSummary: String
    let sleep: TodaySleepData?
    let pvt: TodayPVTData

    var isSleepDataConnected: Bool {
        sleep != nil
    }

    func replacingSleep(
        _ sleep: TodaySleepData?,
        scoreMode: TodayScoreMode,
        roiStatusText: String
    ) -> TodayViewState {
        TodayViewState(
            score: score,
            scoreMode: scoreMode,
            roiStatusText: roiStatusText,
            roiChangePercent: roiChangePercent,
            measuredAt: measuredAt,
            comparisonSummary: comparisonSummary,
            sleep: sleep,
            pvt: pvt
        )
    }

    static let sleepConnectedPlaceholder: TodayViewState = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let now = Date()
        let measuredAt = calendar.date(bySettingHour: 9, minute: 43, second: 0, of: now) ?? now

        return TodayViewState(
            score: 72,
            scoreMode: .full,
            roiStatusText: "안정적인 방전 상태",
            roiChangePercent: 12,
            measuredAt: measuredAt,
            comparisonSummary: "일주일 만에 최고치예요",
            sleep: TodaySleepData(
                totalSleepText: "6h 40m",
                differenceText: "▼ 8%",
                differenceDirection: .negative,
                stages: [
                    TodaySleepStage(kind: .core, startRatio: 0.00, ratio: 0.60),
                    TodaySleepStage(kind: .deep, startRatio: 0.60, ratio: 0.18),
                    TodaySleepStage(kind: .rem, startRatio: 0.78, ratio: 0.22)
                ]
            ),
            pvt: TodayPVTData(
                averageMs: 312,
                changeText: "▲ 18ms",
                highlightText: "✨ 일주일 최고",
                trials: [250, 292, 278, 340, 230, 270, 218]
            )
        )
    }()

    static let sleepDisconnectedPlaceholder: TodayViewState = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let now = Date()
        let measuredAt = calendar.date(bySettingHour: 9, minute: 43, second: 0, of: now) ?? now

        return TodayViewState(
            score: 65,
            scoreMode: .pvtOnly,
            roiStatusText: "PVT만 반영",
            roiChangePercent: 6,
            measuredAt: measuredAt,
            comparisonSummary: "",
            sleep: nil,
            pvt: TodayPVTData(
                averageMs: 312,
                changeText: "▲ 18ms",
                highlightText: "✨ 일주일 최고",
                trials: [250, 292, 278, 340, 230, 270, 218]
            )
        )
    }()
}

enum TodayScoreMode {
    case full
    case pvtOnly
}
