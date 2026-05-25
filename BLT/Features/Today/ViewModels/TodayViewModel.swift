import Foundation
import Combine

@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var state: TodayViewState
    @Published private(set) var latestPVTSummary: PVTSummary?
    @Published var selectedComparison: TodayComparisonType

    private let healthKitService: HealthKitService
    private let pvtResultStore: PVTResultStore
    private let calendar: Calendar
    private let timeFormatter: DateFormatter
    private var cancellables = Set<AnyCancellable>()

    init(
        state: TodayViewState? = nil,
        selectedComparison: TodayComparisonType = .yesterday,
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

        self.state = state ?? TodayViewState.sleepConnectedPlaceholder
        self.selectedComparison = selectedComparison

        bindPVTResultStore()
        bindHealthKitSleepUpdates()
        startHealthKitSleepObservationIfNeeded()
        applyLatestPVTResultIfNeeded()
    }

    func loadHealthKitSleepSummary() async {
        do {
            let sleep = try await healthKitService.fetchDisplaySleepSummary(for: Date())

            let previousDate = Calendar.bltKorea.date(byAdding: .day, value: -1, to: sleep.date) ?? sleep.date
            let previousSummary = try? await healthKitService.fetchSleepSummary(for: previousDate)

            guard let summary = sleep.summary else {
                state = state.replacingSleep(
                    placeholderSleepData(for: sleep.status, previousSummary: previousSummary),
                    sleepStatus: todaySleepDataStatus(from: sleep.status),
                    scoreMode: .pvtOnly,
                    roiStatusText: "PVT만 반영"
                )
                return
            }

            let sleepDifference = sleepDifferenceText(
                todayMinutes: summary.totalMinutes,
                yesterdayMinutes: previousSummary?.totalMinutes
            )

            state = state.replacingSleep(
                TodaySleepData(
                    totalSleepText: totalSleepText(from: summary.totalMinutes),
                    totalMinutes: summary.totalMinutes,
                    differenceText: sleepDifference.text,
                    differenceDirection: sleepDifference.direction,
                    stages: sleepStages(from: summary),
                    coreMinutes: summary.coreMinutes,
                    deepMinutes: summary.deepMinutes,
                    remMinutes: summary.remMinutes,
                    awakeMinutes: summary.awakeMinutes,
                    inBedMinutes: summary.inBedMinutes,
                    bedStartText: timeFormatter.string(from: summary.bedStartAt),
                    bedEndText: timeFormatter.string(from: summary.bedEndAt),
                    awakeCount: summary.stageSegments.filter {
                        $0.kind == .awake && $0.durationMinutes > 2
                    }.count
                ),
                sleepStatus: .available,
                scoreMode: .full,
                roiStatusText: state.roiStatusText == "PVT만 반영" ? "안정적인 방전 상태" : state.roiStatusText
            )
        } catch {
            state = state.replacingSleep(
                nil,
                sleepStatus: .notConnected,
                scoreMode: .pvtOnly,
                roiStatusText: "PVT만 반영"
            )
        }
    }

    func refreshPVTResult() {
        applyLatestPVTResultIfNeeded()
    }

    var measuredTimeText: String {
        timeFormatter.string(from: state.measuredAt)
    }

    var measuredTimeLabel: String {
        measurementTimeLabel(for: state.measuredAt, referenceDate: Date())
    }

    var roiFooterText: String {
        guard state.hasTodayPVTData else {
            switch state.sleepStatus {
            case .available:
                return "\(state.roiStatusText) · 오늘 PVT 측정 데이터 없음"
            case .noSleep:
                return "수면 0h · 오늘 PVT 측정 데이터 없음"
            case .syncing:
                return "수면 동기화 대기 중 · 오늘 PVT 측정 데이터 없음"
            case .noWearableData:
                return "수면 기록 없음 · 오늘 PVT 측정 데이터 없음"
            case .notConnected:
                return "수면 미연동 · 오늘 PVT 측정 데이터 없음"
            }
        }

        if state.sleepStatus == .available {
            return "\(state.roiStatusText) · \(measuredTimeLabel) 측정"
        }
        if state.sleepStatus == .noSleep {
            return "\(measuredTimeLabel) 측정 · 수면 0h + PVT 반영"
        }
        return "\(measuredTimeLabel) 측정 · PVT만 반영"
    }

    var roiIndexTitle: String {
        state.isSleepDataConnected ? "BRAIN ROI INDEX" : "BRAIN ROI INDEX · PVT 단독"
    }

    var comparisonSummaryTitle: String {
        switch state.sleepStatus {
        case .available:
            return "✨ 어제보다 \(state.roiChangePercent)% 향상!"
        case .notConnected:
            return "수면 데이터가 없어 종합 점수 산출 불가 · 연동 시 +35%"
        case .syncing:
            return "수면 데이터 동기화 대기 중"
        case .noSleep:
            return "오늘 수면 시간이 0h로 기록됐어요"
        case .noWearableData:
            return "수면 기록을 찾을 수 없어요"
        }
    }

    var comparisonSummarySubtitle: String? {
        switch state.sleepStatus {
        case .available:
            return state.comparisonSummary
        case .syncing:
            return "HealthKit 반영까지 시간이 걸릴 수 있어요"
        case .noSleep:
            return "밤샘 또는 실제 미수면 상태로 처리합니다"
        case .noWearableData:
            return "Apple Watch 착용 또는 수면 집중모드 기록을 확인해주세요"
        case .notConnected:
            return nil
        }
    }

    private func totalSleepText(from totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(minutes)m"
    }

    private func measurementTimeLabel(for measuredAt: Date, referenceDate: Date) -> String {
        let timeText = timeFormatter.string(from: measuredAt)

        if calendar.isDate(measuredAt, inSameDayAs: referenceDate) {
            return "오늘 \(timeText)"
        }

        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate),
              calendar.isDate(measuredAt, inSameDayAs: yesterday) else {
            return timeText
        }

        return "어제 \(timeText)"
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
              let averageMs = result.summary.averageMilliseconds else {
            latestPVTSummary = nil
            state = state.replacingPVT(
                TodayPVTData(
                    averageMs: 0,
                    changeText: nil,
                    highlightText: nil,
                    trials: []
                ),
                pvtStatus: .noMeasurement
            )
            return
        }

        latestPVTSummary = result.summary
        state = state.replacingPVT(
            TodayPVTData(
                averageMs: averageMs,
                changeText: nil,
                highlightText: "직전 측정",
                trials: result.summary.trials.map(\.reactionTimeMilliseconds)
            ),
            pvtStatus: .available,
            measuredAt: result.measuredAt
        )
    }

    private func sleepDifferenceText(
        todayMinutes: Int,
        yesterdayMinutes: Int?
    ) -> (text: String?, direction: TodaySleepDifferenceDirection?) {
        guard let yesterdayMinutes, yesterdayMinutes > 0 else {
            return (nil, nil)
        }

        let changePercent = Int(
            ((Double(todayMinutes - yesterdayMinutes) / Double(yesterdayMinutes)) * 100).rounded()
        )

        if changePercent > 0 {
            return ("▲ \(changePercent)%", .positive)
        }

        if changePercent < 0 {
            return ("▼ \(abs(changePercent))%", .negative)
        }

        return ("0%", .neutral)
    }

    private func placeholderSleepData(
        for status: HealthKitSleepDataStatus,
        previousSummary: HealthKitSleepSummary?
    ) -> TodaySleepData? {
        guard status == .noSleep else { return nil }

        let sleepDifference = sleepDifferenceText(
            todayMinutes: 0,
            yesterdayMinutes: previousSummary?.totalMinutes
        )

        return TodaySleepData(
            totalSleepText: "0h",
            totalMinutes: 0,
            differenceText: sleepDifference.text,
            differenceDirection: sleepDifference.direction,
            stages: [],
            coreMinutes: 0,
            deepMinutes: 0,
            remMinutes: 0,
            awakeMinutes: 0,
            inBedMinutes: 0,
            bedStartText: "--:--",
            bedEndText: "--:--",
            awakeCount: 0
        )
    }

    private func todaySleepDataStatus(from status: HealthKitSleepDataStatus) -> TodaySleepDataStatus {
        switch status {
        case .available:
            return .available
        case .notConnected:
            return .notConnected
        case .syncing:
            return .syncing
        case .noSleep:
            return .noSleep
        case .noWearableData:
            return .noWearableData
        }
    }

    private func sleepStages(from summary: HealthKitSleepSummary) -> [TodaySleepStage] {
        let timelineStages = summary.stageSegments.map { segment in
            TodaySleepStage(
                kind: todaySleepStageKind(from: segment.kind),
                startRatio: segment.startRatio,
                ratio: segment.durationRatio
            )
        }

        guard !timelineStages.isEmpty else {
            return [TodaySleepStage(kind: .core, startRatio: 0, ratio: 1)]
        }

        return timelineStages
    }

    private func todaySleepStageKind(from kind: HealthKitSleepStageKind) -> TodaySleepStageKind {
        switch kind {
        case .core:
            return .core
        case .deep:
            return .deep
        case .rem:
            return .rem
        case .awake:
            return .awake
        }
    }
}

private extension Calendar {
    static var bltKorea: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }
}
