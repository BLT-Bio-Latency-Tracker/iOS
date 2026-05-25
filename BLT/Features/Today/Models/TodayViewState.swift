import Foundation

struct TodayViewState {
    let score: Int
    let scoreMode: TodayScoreMode
    let roiStatusText: String
    let roiChangePercent: Int
    let measuredAt: Date
    let comparisonSummary: String
    let sleep: TodaySleepData?
    let sleepStatus: TodaySleepDataStatus
    let pvt: TodayPVTData
    let pvtStatus: TodayPVTDataStatus

    var isSleepDataConnected: Bool {
        sleepStatus == .available || sleepStatus == .noSleep
    }

    var hasTodayPVTData: Bool {
        pvtStatus == .available
    }

    func replacingSleep(
        _ sleep: TodaySleepData?,
        sleepStatus: TodaySleepDataStatus,
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
            sleepStatus: sleepStatus,
            pvt: pvt,
            pvtStatus: pvtStatus
        )
    }

    func replacingPVT(
        _ pvt: TodayPVTData,
        pvtStatus: TodayPVTDataStatus,
        measuredAt: Date? = nil
    ) -> TodayViewState {
        TodayViewState(
            score: score,
            scoreMode: scoreMode,
            roiStatusText: roiStatusText,
            roiChangePercent: roiChangePercent,
            measuredAt: measuredAt ?? self.measuredAt,
            comparisonSummary: comparisonSummary,
            sleep: sleep,
            sleepStatus: sleepStatus,
            pvt: pvt,
            pvtStatus: pvtStatus
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
                totalMinutes: 400,
                differenceText: "▼ 8%",
                differenceDirection: .negative,
                stages: [
                    TodaySleepStage(kind: .core, startRatio: 0.00, ratio: 0.60),
                    TodaySleepStage(kind: .deep, startRatio: 0.60, ratio: 0.18),
                    TodaySleepStage(kind: .rem, startRatio: 0.78, ratio: 0.22)
                ],
                coreMinutes: 240,
                deepMinutes: 72,
                remMinutes: 88,
                awakeMinutes: 35,
                inBedMinutes: 460,
                bedStartText: "23:08",
                bedEndText: "06:48",
                awakeCount: 2
            ),
            sleepStatus: .available,
            pvt: TodayPVTData(
                averageMs: 312,
                changeText: "▲ 18ms",
                highlightText: "✨ 일주일 최고",
                trials: [250, 292, 278, 340, 230, 270, 218]
            ),
            pvtStatus: .noMeasurement
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
            sleepStatus: .notConnected,
            pvt: TodayPVTData(
                averageMs: 312,
                changeText: "▲ 18ms",
                highlightText: "✨ 일주일 최고",
                trials: [250, 292, 278, 340, 230, 270, 218]
            ),
            pvtStatus: .noMeasurement
        )
    }()
}

enum TodayScoreMode {
    case full
    case pvtOnly
}

enum TodaySleepDataStatus {
    case available
    case notConnected
    case syncing
    case noSleep
    case noWearableData
}
