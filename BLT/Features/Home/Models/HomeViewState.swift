import Foundation

struct HomeViewState {
    let userName: String
    let profileInitial: String
    let brainROI: Int?
    let roiChangePercent: Int?
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

    func replacingROI(score: Int?, changePercent: Int?, measuredAt: Date?) -> HomeViewState {
        HomeViewState(
            userName: userName,
            profileInitial: profileInitial,
            brainROI: score,
            roiChangePercent: changePercent,
            measuredAt: measuredAt ?? self.measuredAt,
            sleepSummary: sleepSummary,
            pvtSummary: pvtSummary,
            pvtStatus: pvtStatus
        )
    }

    static let initial = HomeViewState(
        userName: "Bryki",
        profileInitial: "B",
        brainROI: nil,
        roiChangePercent: nil,
        measuredAt: Date(),
        sleepSummary: "Sleep --",
        pvtSummary: "PVT 미측정",
        pvtStatus: .noMeasurement
    )
}

enum HomePVTDataStatus {
    case available
    case noMeasurement
}

struct HomeROIDisplayState {
    let score: Int?
    let accent: HomeROIAccent
    let statusText: String
    let warningText: String?
    let changeText: String
    let changeDirection: HomeROIChangeDirection

    init(score: Int?, changePercent: Int?) {
        self.score = score

        guard let score else {
            self.accent = .unmeasured
            self.statusText = "미측정"
            self.warningText = nil
            self.changeDirection = .neutral
            self.changeText = "미측정"
            return
        }

        self.accent = HomeROIAccent(score: score)

        self.changeDirection = HomeROIChangeDirection(roiDirection: ROIChangeFormatter.direction(for: changePercent))
        self.changeText = ROIChangeFormatter.text(for: changePercent, spacing: true)

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

enum HomeROIChangeDirection {
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

enum ROIChangeDirection {
    case positive
    case neutral
    case negative
}

enum ROIChangeFormatter {
    static func text(
        for changePercent: Int?,
        spacing: Bool = false,
        nilText: String = "-",
        zeroText: String = "-"
    ) -> String {
        guard let changePercent else { return nilText }

        let separator = spacing ? " " : ""

        if changePercent > 0 {
            return "▲\(separator)\(changePercent)%"
        }

        if changePercent < 0 {
            return "▼\(separator)\(abs(changePercent))%"
        }

        return zeroText
    }

    static func direction(for changePercent: Int?) -> ROIChangeDirection {
        guard let changePercent else { return .neutral }

        if changePercent > 0 {
            return .positive
        }

        if changePercent < 0 {
            return .negative
        }

        return .neutral
    }
}

enum HomeROIAccent {
    case unmeasured
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
