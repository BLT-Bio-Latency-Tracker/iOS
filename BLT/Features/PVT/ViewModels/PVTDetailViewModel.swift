import Combine
import Foundation

@MainActor
final class PVTDetailViewModel: ObservableObject {
    @Published private(set) var state: PVTDetailViewState

    init(summary: PVTSummary?) {
        self.state = Self.makeState(from: summary)
    }

    private static func makeState(from summary: PVTSummary?) -> PVTDetailViewState {
        guard let summary,
              let averageMilliseconds = summary.averageMilliseconds,
              let bestMilliseconds = summary.bestMilliseconds,
              !summary.trials.isEmpty else {
            return .placeholder
        }

        let trialPoints = summary.trials.map {
            PVTDetailTrialPoint(index: $0.index, milliseconds: $0.reactionTimeMilliseconds)
        }

        return PVTDetailViewState(
            averageMilliseconds: averageMilliseconds,
            bestMilliseconds: bestMilliseconds,
            lapseCount: summary.lapseCount,
            falseStartCount: summary.falseStartCount,
            responseStability: responseStability(for: summary.environmentCalibration),
            arousalLevel: arousalLevel(for: averageMilliseconds),
            trials: trialPoints
        )
    }

    private static func responseStability(for calibration: PVTEnvironmentCalibrationResult?) -> PVTDetailStatus {
        guard let calibration else {
            return .good
        }

        if calibration.maxTimerDriftMilliseconds >= 150 || calibration.unstableFrameCount >= 8 {
            return .poor
        }

        if calibration.maxTimerDriftMilliseconds >= 80 ||
            calibration.unstableFrameCount >= 3 ||
            calibration.isLowPowerModeEnabled {
            return .caution
        }

        return .good
    }

    private static func arousalLevel(for averageMilliseconds: Int) -> PVTDetailStatus {
        if averageMilliseconds <= 350 {
            return .good
        }

        if averageMilliseconds <= 500 {
            return .caution
        }

        return .poor
    }
}
