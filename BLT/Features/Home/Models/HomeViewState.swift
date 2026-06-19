import Foundation

struct HomeViewState {
    let userName: String
    let profileInitial: String
    let brainROI: Int
    let roiChangePercent: Int
    let measuredAt: Date
    let sleepSummary: String
    let pvtSummary: String
    let pvtStatus: HomePVTDataStatus

    func replacingMeasurementSummary(
        measuredAt: Date? = nil,
        sleepSummary: String? = nil,
        pvtSummary: String? = nil,
        pvtStatus: HomePVTDataStatus? = nil
    ) -> HomeViewState {
        HomeViewState(
            userName: userName,
            profileInitial: profileInitial,
            brainROI: brainROI,
            roiChangePercent: roiChangePercent,
            measuredAt: measuredAt ?? self.measuredAt,
            sleepSummary: sleepSummary ?? self.sleepSummary,
            pvtSummary: pvtSummary ?? self.pvtSummary,
            pvtStatus: pvtStatus ?? self.pvtStatus
        )
    }

    func replacingUser(name: String, profileInitial: String) -> HomeViewState {
        HomeViewState(
            userName: name,
            profileInitial: profileInitial,
            brainROI: brainROI,
            roiChangePercent: roiChangePercent,
            measuredAt: measuredAt,
            sleepSummary: sleepSummary,
            pvtSummary: pvtSummary,
            pvtStatus: pvtStatus
        )
    }

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
            userName: "Bryki",
            profileInitial: "B",
            brainROI: 50,
            roiChangePercent: 12,
            measuredAt: measuredAt,
            sleepSummary: "Sleep 6h 40m",
            pvtSummary: "PVT 미측정",
            pvtStatus: .noMeasurement
        )
    }()
}

enum HomePVTDataStatus {
    case available
    case noMeasurement
}

struct HomeROIDisplayState {
    let score: Int
    let accent: HomeROIAccent
    let statusText: String
    let warningText: String?
    let changeText: String
    let isChangePositive: Bool

    init(score: Int, changePercent: Int) {
        self.score = score
        self.accent = HomeROIAccent(score: score)
        self.isChangePositive = changePercent >= 0
        self.changeText = changePercent >= 0 ? "▲ \(changePercent)%" : "▼ \(abs(changePercent))%"

        switch score {
        case ..<20:
            self.statusText = "위험 — 즉각 휴식 필요"
            self.warningText = "위험 상태입니다 — 측정을 멈추고 즉시 휴식하세요"
        case ..<40:
            self.statusText = "인지 저하 우려"
            self.warningText = "인지 효율 저하 상태입니다 — 쉬운 업무를 먼저 처리하세요"
        case ..<70:
            self.statusText = "주의 — 쉬운 업무 권장"
            self.warningText = nil
        default:
            self.statusText = "안정적 인지 상태"
            self.warningText = nil
        }
    }
}

enum HomeROIAccent {
    case warning
    case caution
    case stable

    init(score: Int) {
        switch score {
        case ..<40:
            self = .warning
        case ..<70:
            self = .caution
        default:
            self = .stable
        }
    }
}
