import Foundation

@MainActor
struct PVTEvaluationStoreSyncService {
    private let evaluationService: EvaluationService

    init(evaluationService: EvaluationService = EvaluationService()) {
        self.evaluationService = evaluationService
    }

    func refreshTodayStoresAfterDeletion(
        on date: Date,
        remainingMeasurements: [PVTDetailMeasurement]? = nil
    ) async {
        guard Self.koreaCalendar.isDateInToday(date) else { return }

        do {
            let evaluation = try await evaluationService.fetchToday()
            EvaluationResultStore.shared.apply(evaluation)
        } catch {
            EvaluationResultStore.shared.clear()
        }

        if let remainingMeasurements {
            if let latestMeasurement = remainingMeasurements.sorted(by: { $0.measuredAt < $1.measuredAt }).last {
                savePVTResult(from: latestMeasurement)
            } else {
                PVTResultStore.shared.clear()
            }
            return
        }

        do {
            if let latestMeasurement = try await evaluationService.fetchLatestPVTMeasurementForMeasurementDay(containing: date) {
                savePVTResult(from: latestMeasurement)
            } else {
                PVTResultStore.shared.clear()
            }
        } catch {
            PVTResultStore.shared.clear()
        }
    }

    private func savePVTResult(from measurement: PVTDetailMeasurement) {
        PVTResultStore.shared.save(
            Self.makeSummary(from: measurement),
            measuredAt: measurement.measuredAt,
            measurementId: measurement.measurementId
        )
    }

    private func savePVTResult(from record: EvaluationPVTMeasurement) {
        PVTResultStore.shared.save(
            Self.makeSummary(from: record),
            measuredAt: record.measuredAt,
            measurementId: record.pvt.measurementId
        )
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

    private static func makeSummary(from measurement: PVTDetailMeasurement) -> PVTSummary {
        let trials = measurement.rawReactionTimes.enumerated().map { index, reactionTime in
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
            falseStartCount: measurement.falseStartCount
        )
    }

    private static var koreaCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }
}
