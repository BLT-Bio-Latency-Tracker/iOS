import Foundation

struct PVTTrial: Equatable, Identifiable {
    let id = UUID()
    let index: Int
    let reactionTimeMilliseconds: Int
    let isLapse: Bool

    nonisolated init(index: Int, reactionTimeMilliseconds: Int, isLapse: Bool) {
        self.index = index
        self.reactionTimeMilliseconds = reactionTimeMilliseconds
        self.isLapse = isLapse
    }
}

struct PVTSummary: Equatable {
    let trials: [PVTTrial]
    let lapseThresholdMilliseconds: Int
    let excludesLapsesFromAverage: Bool
    let falseStartCount: Int
    let environmentCalibration: PVTEnvironmentCalibrationResult?

    nonisolated init(
        trials: [PVTTrial],
        lapseThresholdMilliseconds: Int,
        excludesLapsesFromAverage: Bool,
        falseStartCount: Int = 0,
        environmentCalibration: PVTEnvironmentCalibrationResult? = nil
    ) {
        self.trials = trials
        self.lapseThresholdMilliseconds = lapseThresholdMilliseconds
        self.excludesLapsesFromAverage = excludesLapsesFromAverage
        self.falseStartCount = falseStartCount
        self.environmentCalibration = environmentCalibration
    }

    var bestMilliseconds: Int? {
        trials.map(\.reactionTimeMilliseconds).min()
    }

    var averageMilliseconds: Int? {
        let includedTrials = excludesLapsesFromAverage
            ? trials.filter { !$0.isLapse }
            : trials

        guard !includedTrials.isEmpty else {
            return nil
        }

        let total = includedTrials.reduce(0) { $0 + $1.reactionTimeMilliseconds }
        return Int((Double(total) / Double(includedTrials.count)).rounded())
    }

    var lapseCount: Int {
        trials.filter(\.isLapse).count
    }
}

struct PVTEnvironmentCalibrationResult: Codable, Equatable {
    let maxTimerDriftMilliseconds: Int
    let unstableFrameCount: Int
    let isLowPowerModeEnabled: Bool

    nonisolated init(
        maxTimerDriftMilliseconds: Int,
        unstableFrameCount: Int,
        isLowPowerModeEnabled: Bool
    ) {
        self.maxTimerDriftMilliseconds = maxTimerDriftMilliseconds
        self.unstableFrameCount = unstableFrameCount
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
    }
}
