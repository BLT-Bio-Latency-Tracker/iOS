import Foundation
import Combine

@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var state: TodayViewState
    @Published private(set) var latestPVTSummary: PVTSummary?
    @Published private(set) var isRequestingHealthKitAuthorization = false
    @Published private var comparisonRecords: [EvaluationSummary] = []
    @Published var selectedComparison: TodayComparisonType

    private let healthKitService: HealthKitService
    private let pvtResultStore: PVTResultStore
    private let evaluationResultStore: EvaluationResultStore
    private let evaluationService: EvaluationService
    private let calendar: Calendar
    private let timeFormatter: DateFormatter
    private var cancellables = Set<AnyCancellable>()
    private var comparisonFetchTask: Task<Void, Never>?

    init(
        state: TodayViewState? = nil,
        selectedComparison: TodayComparisonType = .yesterday,
        healthKitService: HealthKitService? = nil,
        pvtResultStore: PVTResultStore? = nil,
        evaluationResultStore: EvaluationResultStore? = nil,
        evaluationService: EvaluationService? = nil
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
        self.evaluationResultStore = evaluationResultStore ?? EvaluationResultStore.shared
        self.evaluationService = evaluationService ?? EvaluationService()

        self.state = state ?? TodayViewState.initial
        self.selectedComparison = selectedComparison

        bindPVTResultStore()
        bindEvaluationResultStore()
        bindHealthKitSleepUpdates()
        startHealthKitSleepObservationIfNeeded()
        applyLatestPVTResultIfNeeded()
        Task {
            await loadTodayEvaluation()
        }
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

    func loadTodayEvaluation() async {
        guard AuthSessionStore.shared.accessToken != nil else {
            evaluationResultStore.clear()
            return
        }

        do {
            let evaluation = try await evaluationService.fetchToday()
            evaluationResultStore.apply(evaluation)
        } catch {
            evaluationResultStore.clear()
        }
    }

    func refreshPVTResult() {
        applyLatestPVTResultIfNeeded()
    }

    func connectHealthKit() async {
        guard !isRequestingHealthKitAuthorization else { return }

        isRequestingHealthKitAuthorization = true

        defer {
            isRequestingHealthKitAuthorization = false
        }

        do {
            _ = try await healthKitService.requestSleepAndHRVAuthorization()
            startHealthKitSleepObservationIfNeeded()
            await loadHealthKitSleepSummary()
        } catch {
            state = state.replacingSleep(
                nil,
                sleepStatus: .notConnected,
                scoreMode: .pvtOnly,
                roiStatusText: "PVT만 반영"
            )
        }
    }

    var measuredTimeText: String {
        timeFormatter.string(from: state.measuredAt)
    }

    var measuredTimeLabel: String {
        measurementTimeLabel(for: state.measuredAt, referenceDate: Date())
    }

    var roiScoreText: String {
        state.score.map(String.init) ?? "-"
    }

    var roiFooterText: String {
        guard state.hasROIResult else {
            switch state.sleepStatus {
            case .available:
                return "오늘 PVT 측정 데이터 없음"
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
        guard state.hasROIResult else {
            return "아직 Brain ROI를 측정하지 않았어요"
        }

        switch state.sleepStatus {
        case .available:
            guard let roiChangePercent = selectedComparisonChangePercent else {
                return "\(selectedComparisonBaselineTitle) 비교 기록이 없어요"
            }

            if roiChangePercent > 0 {
                return String(format: "✨ %@보다 %d%% 향상!", selectedComparisonBaselineTitle, roiChangePercent)
            }

            if roiChangePercent < 0 {
                return String(format: "%@보다 %d%% 낮아요", selectedComparisonBaselineTitle, abs(roiChangePercent))
            }

            return "\(selectedComparisonBaselineTitle)과 비슷한 컨디션이에요"
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
            guard let baselineScore = selectedComparisonBaselineScore else {
                return nil
            }
            return "\(selectedComparisonBaselineTitle) \(baselineScore)점 기준으로 계산했어요"
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

    var roiChangeText: String {
        ROIChangeFormatter.text(
            for: selectedComparisonChangePercent,
            spacing: true,
            nilText: "-",
            zeroText: "0%"
        )
    }

    var roiChangeDirection: TodayROIChangeDirection {
        TodayROIChangeDirection(roiDirection: ROIChangeFormatter.direction(for: selectedComparisonChangePercent))
    }

    private var selectedComparisonBaselineTitle: String {
        switch selectedComparison {
        case .yesterday:
            return "어제"
        case .lastSevenDays:
            return "지난 7일 평균"
        case .myAverage:
            return "내 평균"
        }
    }

    private var selectedComparisonChangePercent: Int? {
        guard let todayScore = state.score,
              let baselineScore = selectedComparisonBaselineScore,
              baselineScore > 0 else {
            return nil
        }

        return Int(((Double(todayScore - baselineScore) / Double(baselineScore)) * 100).rounded())
    }

    private var selectedComparisonBaselineScore: Int? {
        guard state.hasROIResult else { return nil }

        let referenceDate = calendar.startOfDay(for: state.measuredAt)

        switch selectedComparison {
        case .yesterday:
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate) else {
                return nil
            }
            return averageScore(for: Set([dateText(yesterday)]))
        case .lastSevenDays:
            let dateTexts = (1...7).compactMap { offset in
                calendar.date(byAdding: .day, value: -offset, to: referenceDate).map(dateText)
            }
            return averageScore(for: Set(dateTexts))
        case .myAverage:
            let todayText = dateText(referenceDate)
            let scores = comparisonRecords
                .filter { $0.date < todayText }
                .map(\.finalScore)
            return averageScore(from: scores)
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

    private func bindEvaluationResultStore() {
        evaluationResultStore.$todayEvaluation
            .sink { [weak self] evaluation in
                self?.applyEvaluation(evaluation)
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

    private func applyEvaluation(_ evaluation: EvaluationResponse?) {
        guard let evaluation else {
            comparisonFetchTask?.cancel()
            comparisonRecords = []
            state = state.replacingROI(
                score: nil,
                statusText: "PVT 미측정",
                changePercent: nil,
                measuredAt: nil
            )
            return
        }

        scheduleComparisonRecordFetch(referenceDate: evaluation.measuredAt)

        state = state.replacingROI(
            score: evaluation.finalScore,
            statusText: evaluation.statusLabel,
            changePercent: evaluation.trendVsYesterday,
            measuredAt: evaluation.measuredAt
        )
    }

    private func scheduleComparisonRecordFetch(referenceDate: Date) {
        comparisonFetchTask?.cancel()
        comparisonFetchTask = Task { [weak self] in
            await self?.loadComparisonRecords(referenceDate: referenceDate)
        }
    }

    private func loadComparisonRecords(referenceDate: Date) async {
        guard AuthSessionStore.shared.accessToken != nil else {
            comparisonRecords = []
            return
        }

        let todayStart = calendar.startOfDay(for: referenceDate)
        guard let endDate = calendar.date(byAdding: .day, value: -1, to: todayStart),
              let startDate = calendar.date(byAdding: .year, value: -10, to: todayStart) else {
            comparisonRecords = []
            return
        }

        do {
            comparisonRecords = try await evaluationService.fetchSummaries(
                from: startDate,
                to: endDate,
                size: 1000
            )
        } catch {
            comparisonRecords = []
        }
    }

    private func averageScore(for dateTexts: Set<String>) -> Int? {
        let scores = comparisonRecords
            .filter { dateTexts.contains($0.date) }
            .map(\.finalScore)
        return averageScore(from: scores)
    }

    private func averageScore(from scores: [Int]) -> Int? {
        guard !scores.isEmpty else { return nil }
        return Int(round(Double(scores.reduce(0, +)) / Double(scores.count)))
    }

    private func dateText(_ date: Date) -> String {
        EvaluationDateFormatter.dateText(date, timeZone: calendar.timeZone)
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
            return (String(format: "▲ %d%%", changePercent), .positive)
        }

        if changePercent < 0 {
            return (String(format: "▼ %d%%", abs(changePercent)), .negative)
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
