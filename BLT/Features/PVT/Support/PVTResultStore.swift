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

    func displayResult(for date: Date = Date()) -> PVTDisplayResult? {
        guard let latestSummary, let measuredAt else {
            return nil
        }

        guard Self.isInCurrentMeasurementDay(measuredAt, referenceDate: date) else {
            return nil
        }

        return PVTDisplayResult(
            summary: latestSummary,
            measuredAt: measuredAt
        )
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

    private static func isInCurrentMeasurementDay(_ measuredAt: Date, referenceDate: Date) -> Bool {
        let start = measurementDayStart(for: referenceDate)
        guard let end = koreaCalendar.date(byAdding: .day, value: 1, to: start) else {
            return false
        }

        return measuredAt >= start && measuredAt < end
    }

    private static func measurementDayStart(for date: Date) -> Date {
        let startOfDay = koreaCalendar.startOfDay(for: date)
        let hour = koreaCalendar.component(.hour, from: date)
        let baseDay = hour < 6
            ? koreaCalendar.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
            : startOfDay

        return koreaCalendar.date(byAdding: .hour, value: 6, to: baseDay) ?? baseDay
    }

    private static var koreaCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }
}

struct PVTDisplayResult {
    let summary: PVTSummary
    let measuredAt: Date
}

private struct StoredPVTResult: Codable {
    let measuredAt: Date
    let trials: [StoredPVTTrial]
    let lapseThresholdMilliseconds: Int
    let excludesLapsesFromAverage: Bool
    let falseStartCount: Int?
    let environmentCalibration: PVTEnvironmentCalibrationResult?

    nonisolated init(summary: PVTSummary, measuredAt: Date) {
        self.measuredAt = measuredAt
        self.trials = summary.trials.map(StoredPVTTrial.init)
        self.lapseThresholdMilliseconds = summary.lapseThresholdMilliseconds
        self.excludesLapsesFromAverage = summary.excludesLapsesFromAverage
        self.falseStartCount = summary.falseStartCount
        self.environmentCalibration = summary.environmentCalibration
    }

    var summary: PVTSummary {
        PVTSummary(
            trials: trials.map(\.trial),
            lapseThresholdMilliseconds: lapseThresholdMilliseconds,
            excludesLapsesFromAverage: excludesLapsesFromAverage,
            falseStartCount: falseStartCount ?? 0,
            environmentCalibration: environmentCalibration
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
