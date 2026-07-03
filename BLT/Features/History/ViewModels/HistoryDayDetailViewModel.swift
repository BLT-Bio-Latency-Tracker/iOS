import Combine
import Foundation

@MainActor
final class HistoryDayDetailViewModel: ObservableObject {
    @Published private(set) var state: HistoryDayDetailState

    private let evaluationService: EvaluationService
    private let healthKitService: HealthKitService
    private var calendar: Calendar
    private var loadTask: Task<Void, Never>?
    private var loadedDate: Date?

    init(
        date: Date,
        evaluationService: EvaluationService = EvaluationService(),
        healthKitService: HealthKitService = HealthKitService(),
        calendar: Calendar = .current
    ) {
        var normalizedCalendar = calendar
        normalizedCalendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? calendar.timeZone
        self.calendar = normalizedCalendar
        self.evaluationService = evaluationService
        self.healthKitService = healthKitService
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
        state.isLoading = true
        state.errorMessage = nil

        do {
            let evaluations = try await fetchEvaluations(for: date)
            let sleep = await fetchSleep(for: date, evaluations: evaluations)
            guard !Task.isCancelled else { return }

            state = HistoryDayDetailState(
                selectedDate: date,
                isLoading: false,
                errorMessage: nil,
                evaluations: evaluations,
                sleep: sleep
            )
            loadedDate = date
        } catch {
            guard !Task.isCancelled else { return }
            state.isLoading = false
            state.errorMessage = "상세 기록을 불러오지 못했어요."
            loadedDate = date
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
        if let localSleep = try? await healthKitService.fetchDisplaySleepSummary(for: date).summary {
            return HistoryDaySleepSummary(summary: localSleep)
        }

        if let serverSleep = evaluations.compactMap(\.serverSleep).first {
            return HistoryDaySleepSummary(serverSleep: serverSleep)
        }

        return nil
    }
}
