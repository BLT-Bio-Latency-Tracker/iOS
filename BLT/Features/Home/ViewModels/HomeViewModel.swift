import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var state: HomeViewState
    @Published private(set) var currentDate: Date

    private let calendar: Calendar
    private let timeFormatter: DateFormatter
    private let healthKitService: HealthKitService
    private let pvtResultStore: PVTResultStore
    private var cancellables = Set<AnyCancellable>()

    init(
        state: HomeViewState? = nil,
        currentDate: Date = Date(),
        healthKitService: HealthKitService? = nil,
        pvtResultStore: PVTResultStore? = nil
    ) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        self.calendar = calendar

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "HH:mm"
        self.timeFormatter = formatter
        self.healthKitService = healthKitService ?? HealthKitService()
        self.pvtResultStore = pvtResultStore ?? PVTResultStore.shared

        self.state = state ?? HomeViewState.placeholder
        self.currentDate = currentDate

        bindPVTResultStore()
        applyLatestPVTResultIfNeeded()
    }

    var greetingText: String {
        let hour = calendar.component(.hour, from: currentDate)

        switch hour {
        case 5..<12:
            return "좋은 아침이에요,"
        case 12..<18:
            return "좋은 오후예요,"
        default:
            return "좋은 저녁이에요,"
        }
    }

    var measurementSummaryText: String {
        "오늘 \(timeFormatter.string(from: state.measuredAt)) 측정 · \(state.sleepSummary) + \(state.pvtSummary)"
    }

    var currentTimeProgress: Double {
        let hour = Double(calendar.component(.hour, from: currentDate))
        let minute = Double(calendar.component(.minute, from: currentDate))
        let currentHour = hour + minute / 60
        return min(max((currentHour - 6) / 17, 0), 1)
    }

    func updateCurrentDate(_ date: Date) {
        currentDate = date
    }

    func loadHealthKitSleepSummary() async {
        do {
            guard let sleepSummary = try await latestAvailableSleepSummary(from: Date()) else {
                state = state.replacingMeasurementSummary(sleepSummary: "Sleep --")
                return
            }

            state = state.replacingMeasurementSummary(
                sleepSummary: "Sleep \(durationText(from: sleepSummary.totalMinutes))"
            )
        } catch {
            state = state.replacingMeasurementSummary(sleepSummary: "Sleep --")
        }
    }

    private func bindPVTResultStore() {
        pvtResultStore.$latestSummary
            .combineLatest(pvtResultStore.$measuredAt)
            .sink { [weak self] summary, measuredAt in
                self?.applyPVTSummary(summary, measuredAt: measuredAt)
            }
            .store(in: &cancellables)
    }

    private func applyLatestPVTResultIfNeeded() {
        applyPVTSummary(pvtResultStore.latestSummary, measuredAt: pvtResultStore.measuredAt)
    }

    private func applyPVTSummary(_ summary: PVTSummary?, measuredAt: Date?) {
        guard let summary, let averageMilliseconds = summary.averageMilliseconds else {
            return
        }

        state = state.replacingMeasurementSummary(
            measuredAt: measuredAt ?? Date(),
            pvtSummary: "PVT \(averageMilliseconds)ms"
        )
    }

    private func latestAvailableSleepSummary(from date: Date) async throws -> HealthKitSleepSummary? {
        if let summary = try await healthKitService.fetchSleepSummary(for: date) {
            return summary
        }

        guard let fallbackDate = calendar.date(byAdding: .day, value: -1, to: date) else {
            return nil
        }

        return try await healthKitService.fetchSleepSummary(for: fallbackDate)
    }

    private func durationText(from minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
}
