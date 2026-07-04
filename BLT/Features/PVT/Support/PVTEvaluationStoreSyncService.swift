import Foundation

@MainActor
struct PVTEvaluationStoreSyncService {
    private let evaluationService: EvaluationService

    init(evaluationService: EvaluationService = EvaluationService()) {
        self.evaluationService = evaluationService
    }

    /// 로컬 PVT 저장소가 비어 있으면(재설치 등) 서버에서 현재 측정일의 최신 PVT를 복원한다.
    func restoreTodayPVTResultIfNeeded(for date: Date = Date()) async {
        guard AuthSessionStore.shared.accessToken != nil else { return }
        guard PVTResultStore.shared.displayResult(for: date) == nil else { return }

        guard let latestMeasurement = try? await evaluationService.fetchLatestPVTMeasurementForMeasurementDay(containing: date) else {
            return
        }

        savePVTResult(from: latestMeasurement)
    }

    func refreshTodayStoresAfterDeletion(
        on date: Date,
        remainingMeasurements: [PVTDetailMeasurement]? = nil
    ) async {
        guard Self.isCurrentMeasurementDay(date) else { return }

        do {
            if let evaluation = try await evaluationService.fetchLatestEvaluationForMeasurementDay() {
                EvaluationResultStore.shared.apply(evaluation)
            } else {
                EvaluationResultStore.shared.clear()
            }
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

    private static func isCurrentMeasurementDay(_ date: Date) -> Bool {
        let interval = EvaluationService.measurementDayInterval(containing: Date())
        if date >= interval.start && date < interval.end {
            return true
        }

        let currentDayLabel = koreaCalendar.startOfDay(for: interval.start)
        return koreaCalendar.isDate(date, inSameDayAs: currentDayLabel)
    }

    private static var koreaCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }
}
