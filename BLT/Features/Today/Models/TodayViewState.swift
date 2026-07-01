import Foundation

struct TodayViewState {
    let score: Int?
    let scoreMode: TodayScoreMode
    let roiStatusText: String
    let roiChangePercent: Int?
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

    var hasROIResult: Bool {
        score != nil
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

    func replacingROI(score: Int?, statusText: String, changePercent: Int?, measuredAt: Date?) -> TodayViewState {
        TodayViewState(
            score: score,
            scoreMode: scoreMode,
            roiStatusText: statusText,
            roiChangePercent: changePercent,
            measuredAt: measuredAt ?? self.measuredAt,
            comparisonSummary: comparisonSummary,
            sleep: sleep,
            sleepStatus: sleepStatus,
            pvt: pvt,
            pvtStatus: pvtStatus
        )
    }

    static let initial = TodayViewState(
        score: nil,
        scoreMode: .pvtOnly,
        roiStatusText: "PVT 미측정",
        roiChangePercent: nil,
        measuredAt: Date(),
        comparisonSummary: "",
        sleep: nil,
        sleepStatus: .syncing,
        pvt: TodayPVTData(
            averageMs: 0,
            changeText: nil,
            highlightText: nil,
            trials: []
        ),
        pvtStatus: .noMeasurement
    )
}

enum TodayScoreMode {
    case full
    case pvtOnly
}

enum TodayROIChangeDirection {
    case positive
    case neutral
    case negative

    init(roiDirection: ROIChangeDirection) {
        switch roiDirection {
        case .positive:
            self = .positive
        case .neutral:
            self = .neutral
        case .negative:
            self = .negative
        }
    }
}

enum TodaySleepDataStatus {
    case available
    case notConnected
    case syncing
    case noSleep
    case noWearableData
}
