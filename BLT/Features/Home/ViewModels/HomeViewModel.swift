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
        bindHealthKitSleepUpdates()
        startHealthKitSleepObservationIfNeeded()
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
        switch state.pvtStatus {
        case .available:
            return "\(measurementTimeLabel(for: state.measuredAt)) 측정 · \(state.sleepSummary) + \(state.pvtSummary)"
        case .noMeasurement:
            return "\(state.sleepSummary) · 오늘 PVT 측정 데이터 없음"
        }
    }

    var currentTimeProgress: Double {
        let hour = Double(calendar.component(.hour, from: currentDate))
        let minute = Double(calendar.component(.minute, from: currentDate))
        let currentHour = hour + minute / 60
        return min(max((currentHour - 6) / 17, 0), 1)
    }

    func updateCurrentDate(_ date: Date) {
        currentDate = date
        applyLatestPVTResultIfNeeded()
    }

    func loadHealthKitSleepSummary() async {
        do {
            let resolvedSleep = try await healthKitService.fetchDisplaySleepSummary(for: Date())
            let sleepSummaryText: String

            switch resolvedSleep.status {
            case .available:
                sleepSummaryText = "Sleep \(durationText(from: resolvedSleep.summary?.totalMinutes ?? 0))"
            case .noSleep:
                sleepSummaryText = "Sleep 0h"
            case .syncing:
                sleepSummaryText = "Sleep 동기화 중"
            case .noWearableData:
                sleepSummaryText = "Sleep 기록 없음"
            case .notConnected:
                sleepSummaryText = "Sleep --"
            }

            state = state.replacingMeasurementSummary(
                sleepSummary: sleepSummaryText
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

    private func bindHealthKitSleepUpdates() {
        NotificationCenter.default.publisher(for: HealthKitService.sleepDataDidChangeNotification)
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task {
                    await self?.loadHealthKitSleepSummary()
                }
            }
            .store(in: &cancellables)
    }

    private func startHealthKitSleepObservationIfNeeded() {
        try? healthKitService.startObservingSleepChanges()
    }

    private func applyLatestPVTResultIfNeeded() {
        applyPVTSummary(pvtResultStore.latestSummary, measuredAt: pvtResultStore.measuredAt)
    }

    private func applyPVTSummary(_ summary: PVTSummary?, measuredAt: Date?) {
        guard let result = pvtResultStore.displayResult(for: Date()),
              let averageMilliseconds = result.summary.averageMilliseconds else {
            state = state.replacingMeasurementSummary(
                pvtSummary: "PVT 미측정",
                pvtStatus: .noMeasurement
            )
            return
        }

        state = state.replacingMeasurementSummary(
            measuredAt: result.measuredAt,
            pvtSummary: "PVT \(averageMilliseconds)ms",
            pvtStatus: .available
        )
    }

    private func durationText(from minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }

    private func measurementTimeLabel(for measuredAt: Date) -> String {
        let timeText = timeFormatter.string(from: measuredAt)

        if calendar.isDate(measuredAt, inSameDayAs: currentDate) {
            return "오늘 \(timeText)"
        }

        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: currentDate),
              calendar.isDate(measuredAt, inSameDayAs: yesterday) else {
            return timeText
        }

        return "어제 \(timeText)"
    }
}
