import Combine
import Foundation

@MainActor
final class PVTDetailViewModel: ObservableObject {
    @Published private(set) var state = PVTDetailViewState.empty

    private let evaluationService: EvaluationService
    private let storeSyncService: PVTEvaluationStoreSyncService
    private let date: Date

    init(
        date: Date = Date(),
        evaluationService: EvaluationService = EvaluationService(),
        storeSyncService: PVTEvaluationStoreSyncService? = nil
    ) {
        self.date = date
        self.evaluationService = evaluationService
        self.storeSyncService = storeSyncService ?? PVTEvaluationStoreSyncService(evaluationService: evaluationService)
    }

    func load() async {
        state.isLoading = true
        state.errorMessage = nil

        do {
            let records = try await evaluationService.fetchPVTDetailsForMeasurementDay(containing: date)
            state = PVTDetailViewState(
                isLoading: false,
                errorMessage: nil,
                measurements: records
                    .filter { $0.pvt.isValid }
                    .map(Self.makeMeasurement(from:))
            )
        } catch {
            state.isLoading = false
            state.errorMessage = "PVT 기록을 불러오지 못했어요."
        }
    }

    func loadIfNeeded() async {
        guard !state.isLoading, !state.hasMeasurements else { return }
        await load()
    }

    func reloadAfterDeletion() async {
        await load()
        await storeSyncService.refreshTodayStoresAfterDeletion(
            on: date,
            remainingMeasurements: state.measurements
        )
    }

    private static func makeMeasurement(from record: EvaluationPVTMeasurement) -> PVTDetailMeasurement {
        PVTDetailMeasurement(
            id: record.evaluationId,
            measurementId: record.pvt.measurementId,
            measuredAt: record.measuredAt,
            averageMilliseconds: Int(record.pvt.avgRtMs.rounded()),
            bestMilliseconds: record.pvt.bestRtMs ?? record.pvt.rawRtMs.min(),
            lapseCount: record.pvt.lapsesMild + record.pvt.lapsesTimeout,
            falseStartCount: record.pvt.falseStarts,
            totalCount: record.pvt.totalCount,
            rawReactionTimes: record.pvt.rawRtMs
        )
    }

}
