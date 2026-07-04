import Combine
import Foundation

@MainActor
final class HistoryDayDetailViewModel: ObservableObject {
    @Published private(set) var state: HistoryDayDetailState

    private let evaluationService: EvaluationService
    private let healthKitService: HealthKitService
    private let storeSyncService: PVTEvaluationStoreSyncService
    private var calendar: Calendar
    private var loadTask: Task<Void, Never>?
    private var loadedDate: Date?

    init(
        date: Date,
        evaluationService: EvaluationService = EvaluationService(),
        healthKitService: HealthKitService = HealthKitService(),
        storeSyncService: PVTEvaluationStoreSyncService? = nil,
        calendar: Calendar = .current
    ) {
        var normalizedCalendar = calendar
        normalizedCalendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? calendar.timeZone
        self.calendar = normalizedCalendar
        self.evaluationService = evaluationService
        self.healthKitService = healthKitService
        self.storeSyncService = storeSyncService ?? PVTEvaluationStoreSyncService(evaluationService: evaluationService)
        self.state = .empty(date: normalizedCalendar.startOfDay(for: date))
    }

    func load() async {
        await load(for: state.selectedDate)
    }

    func loadIfNeeded() async {
        guard !state.isLoading else { return }
        guard loadedDate != state.selectedDate else { return }
        await load(for: state.selectedDate)
    }

    func reloadAfterDeletion() async {
        let selectedDate = state.selectedDate
        loadedDate = nil
        await load(for: selectedDate)
        await storeSyncService.refreshTodayStoresAfterDeletion(
            on: selectedDate,
            remainingMeasurements: state.sortedEvaluations.map(Self.makePVTMeasurement(from:))
        )
    }

    func moveDay(by value: Int) {
        let nextDate = calendar.date(byAdding: .day, value: value, to: state.selectedDate) ?? state.selectedDate
        updateDate(nextDate)
    }

    func moveToToday() {
        updateDate(Date())
    }

    var canMoveToNextDay: Bool {
        guard let nextDate = calendar.date(byAdding: .day, value: 1, to: state.selectedDate) else {
            return false
        }
        return calendar.startOfDay(for: nextDate) <= calendar.startOfDay(for: Date())
    }

    private func updateDate(_ date: Date) {
        let normalizedDate = calendar.startOfDay(for: date)
        loadedDate = nil
        state = .empty(date: normalizedDate)
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            await self?.load(for: normalizedDate)
        }
    }

    private func load(for date: Date) async {
        let requestedDate = calendar.startOfDay(for: date)
        guard calendar.isDate(requestedDate, inSameDayAs: state.selectedDate) else { return }

        state.isLoading = true
        state.errorMessage = nil

        do {
            let evaluations = try await fetchEvaluations(for: requestedDate)
            let sleep = await fetchSleep(for: requestedDate, evaluations: evaluations)
            guard !Task.isCancelled,
                  calendar.isDate(requestedDate, inSameDayAs: state.selectedDate) else {
                return
            }

            state = HistoryDayDetailState(
                selectedDate: requestedDate,
                isLoading: false,
                errorMessage: nil,
                evaluations: evaluations,
                sleep: sleep
            )
            loadedDate = requestedDate
        } catch {
            guard !Task.isCancelled,
                  calendar.isDate(requestedDate, inSameDayAs: state.selectedDate) else {
                return
            }
            state.isLoading = false
            state.errorMessage = "상세 기록을 불러오지 못했어요."
            loadedDate = requestedDate
        }
    }

    private func fetchEvaluations(for date: Date) async throws -> [HistoryDayEvaluation] {
        let summaries = try await evaluationService.fetchSummaries(from: date, to: date, size: 50)
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let daySummaries = summaries
            .filter { $0.measuredAt >= dayStart && $0.measuredAt < dayEnd }
            .sorted { $0.measuredAt < $1.measuredAt }

        var details: [HistoryDayEvaluation] = []
        for summary in daySummaries {
            let detail = try await evaluationService.fetchDetail(id: summary.evaluationId)
            details.append(
                HistoryDayEvaluation(
                    id: summary.evaluationId,
                    measuredAt: detail.evaluation.measuredAt,
                    finalScore: detail.evaluation.finalScore,
                    statusLabel: detail.evaluation.statusLabel,
                    pvt: HistoryDayPVT(detail: detail.pvt),
                    serverSleep: detail.sleep.map(HistoryServerSleepSummary.init)
                )
            )
        }

        return details.sorted { $0.measuredAt < $1.measuredAt }
    }

    private func fetchSleep(
        for date: Date,
        evaluations: [HistoryDayEvaluation]
    ) async -> HistoryDaySleepSummary? {
        let serverSleeps = evaluations.compactMap(\.serverSleep)
        if let serverSleep = serverSleeps
            .filter({ HistoryDaySleepStageSegment.hasDisplayableServerSegments($0.stages) })
            .max(by: { lhs, rhs in
                let lhsTimeline = HistoryDaySleepStageSegment.serverTimeline(from: lhs.stages)
                let rhsTimeline = HistoryDaySleepStageSegment.serverTimeline(from: rhs.stages)
                return (lhsTimeline?.asleepMinutes ?? lhs.totalMinutes) < (rhsTimeline?.asleepMinutes ?? rhs.totalMinutes)
            }) {
            return await makeServerSleepSummary(serverSleep, for: date, serverSleeps: serverSleeps)
        }

        if let localSleep = try? await healthKitService.fetchDisplaySleepSummary(for: sleepReferenceDate(for: date)).summary {
            return HistoryDaySleepSummary(summary: localSleep)
        }

        if let serverSleep = serverSleeps.first {
            return await makeServerSleepSummary(serverSleep, for: date, serverSleeps: serverSleeps)
        }

        return nil
    }

    private func makeServerSleepSummary(
        _ serverSleep: HistoryServerSleepSummary,
        for date: Date,
        serverSleeps: [HistoryServerSleepSummary]
    ) async -> HistoryDaySleepSummary {
        await backfillingHRVIfNeeded(
            HistoryDaySleepSummary(serverSleep: serverSleep),
            for: date,
            serverSleeps: serverSleeps
        )
    }

    private func backfillingHRVIfNeeded(
        _ summary: HistoryDaySleepSummary,
        for date: Date,
        serverSleeps: [HistoryServerSleepSummary]
    ) async -> HistoryDaySleepSummary {
        var nightHrvMs = summary.nightHrvMs ?? serverSleeps.compactMap(\.nightHrvMs).first
        var weeklyHrvBaselineMs = summary.weeklyHrvBaselineMs ?? serverSleeps.compactMap(\.weeklyHrvBaselineMs).first

        if nightHrvMs == nil || weeklyHrvBaselineMs == nil,
           let localSleep = try? await healthKitService.fetchSleepSummary(for: sleepReferenceDate(for: date)) {
            nightHrvMs = nightHrvMs ?? localSleep.nightHrvMs
            weeklyHrvBaselineMs = weeklyHrvBaselineMs ?? localSleep.weeklyHrvBaselineMs
        }

        guard nightHrvMs != summary.nightHrvMs || weeklyHrvBaselineMs != summary.weeklyHrvBaselineMs else {
            return summary
        }

        return summary.replacingHRV(nightHrvMs: nightHrvMs, weeklyHrvBaselineMs: weeklyHrvBaselineMs)
    }

    private func sleepReferenceDate(for date: Date) -> Date {
        calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: date)) ?? date
    }

    private static func makePVTMeasurement(from evaluation: HistoryDayEvaluation) -> PVTDetailMeasurement {
        PVTDetailMeasurement(
            id: evaluation.id,
            measurementId: evaluation.pvt.measurementId,
            measuredAt: evaluation.measuredAt,
            averageMilliseconds: evaluation.pvt.averageMilliseconds,
            bestMilliseconds: evaluation.pvt.bestMilliseconds,
            lapseCount: evaluation.pvt.lapseCount,
            falseStartCount: evaluation.pvt.falseStartCount,
            totalCount: evaluation.pvt.totalCount,
            rawReactionTimes: evaluation.pvt.rawReactionTimes
        )
    }
}
