import Foundation

@MainActor
struct PVTEvaluationStoreSyncService {
    private let evaluationService: EvaluationService

    init(evaluationService: EvaluationService = EvaluationService()) {
        self.evaluationService = evaluationService
    }

    func refreshTodayStoresAfterDeletion(on date: Date) async {
        guard Self.koreaCalendar.isDateInToday(date) else { return }

        do {
            let evaluation = try await evaluationService.fetchToday()
            EvaluationResultStore.shared.apply(evaluation)

            if let latestMeasurement = try await evaluationService.fetchLatestPVTMeasurementForMeasurementDay(containing: date) {
                PVTResultStore.shared.save(
                    Self.makeSummary(from: latestMeasurement),
                    measuredAt: latestMeasurement.measuredAt,
                    measurementId: latestMeasurement.pvt.measurementId
                )
            } else {
                PVTResultStore.shared.clear()
            }
        } catch {
            EvaluationResultStore.shared.clear()
            PVTResultStore.shared.clear()
        }
    }

    private static func makeSummary(from record: EvaluationPVTMeasurement) -> PVTSummary {
        let trials = record.pvt.rawRtMs.enumerated().map { index, reactionTime in
            PVTTrial(
                index: index + 1,
                reactionTimeMilliseconds: reactionTime,
                isLapse: reactionTime > 500
            )
        }

        return PVTSummary(
            trials: trials,
            lapseThresholdMilliseconds: 500,
            excludesLapsesFromAverage: true,
            falseStartCount: record.pvt.falseStarts
        )
    }

    private static var koreaCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }
}
