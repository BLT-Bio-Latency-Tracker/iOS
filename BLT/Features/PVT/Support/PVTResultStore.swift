import Foundation
import Combine

@MainActor
final class PVTResultStore: ObservableObject {
    static let shared = PVTResultStore()

    @Published private(set) var latestSummary: PVTSummary?
    @Published private(set) var measuredAt: Date?

    private let storageKey = "pvt.latestResult"
    private let userDefaults: UserDefaults

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        restoreLatestResult()
    }

    func save(_ summary: PVTSummary, measuredAt: Date = Date()) {
        latestSummary = summary
        self.measuredAt = measuredAt
        persist(summary: summary, measuredAt: measuredAt)
    }

    private func restoreLatestResult() {
        guard let data = userDefaults.data(forKey: storageKey),
              let storedResult = try? JSONDecoder().decode(StoredPVTResult.self, from: data) else {
            return
        }

        latestSummary = storedResult.summary
        measuredAt = storedResult.measuredAt
    }

    private func persist(summary: PVTSummary, measuredAt: Date) {
        let storedResult = StoredPVTResult(summary: summary, measuredAt: measuredAt)

        guard let data = try? JSONEncoder().encode(storedResult) else {
            return
        }

        userDefaults.set(data, forKey: storageKey)
    }
}

private struct StoredPVTResult: Codable {
    let measuredAt: Date
    let trials: [StoredPVTTrial]
    let lapseThresholdMilliseconds: Int
    let excludesLapsesFromAverage: Bool

    nonisolated init(summary: PVTSummary, measuredAt: Date) {
        self.measuredAt = measuredAt
        self.trials = summary.trials.map(StoredPVTTrial.init)
        self.lapseThresholdMilliseconds = summary.lapseThresholdMilliseconds
        self.excludesLapsesFromAverage = summary.excludesLapsesFromAverage
    }

    var summary: PVTSummary {
        PVTSummary(
            trials: trials.map(\.trial),
            lapseThresholdMilliseconds: lapseThresholdMilliseconds,
            excludesLapsesFromAverage: excludesLapsesFromAverage
        )
    }
}

private struct StoredPVTTrial: Codable {
    let index: Int
    let reactionTimeMilliseconds: Int
    let isLapse: Bool

    nonisolated init(trial: PVTTrial) {
        self.index = trial.index
        self.reactionTimeMilliseconds = trial.reactionTimeMilliseconds
        self.isLapse = trial.isLapse
    }

    var trial: PVTTrial {
        PVTTrial(
            index: index,
            reactionTimeMilliseconds: reactionTimeMilliseconds,
            isLapse: isLapse
        )
    }
}
