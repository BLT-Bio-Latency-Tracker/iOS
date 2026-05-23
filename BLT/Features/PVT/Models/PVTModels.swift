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

    nonisolated init(
        trials: [PVTTrial],
        lapseThresholdMilliseconds: Int,
        excludesLapsesFromAverage: Bool
    ) {
        self.trials = trials
        self.lapseThresholdMilliseconds = lapseThresholdMilliseconds
        self.excludesLapsesFromAverage = excludesLapsesFromAverage
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
