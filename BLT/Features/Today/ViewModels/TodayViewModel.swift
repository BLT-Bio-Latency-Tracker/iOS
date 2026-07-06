import Foundation
import Combine

private struct TodayComparisonRecord {
    let recordDate: Date
    let score: Int
}

@MainActor
final class TodayViewModel: ObservableObject {
    private static let comparisonDetailBatchSize = 8

    @Published private(set) var state: TodayViewState
    @Published private(set) var latestPVTSummary: PVTSummary?
    @Published private(set) var isRequestingHealthKitAuthorization = false
    @Published private(set) var isRemeasureSuggested = false
    @Published private var comparisonRecords: [TodayComparisonRecord] = []
    @Published var selectedComparison: TodayComparisonType

    private let healthKitService: HealthKitService
    private let pvtResultStore: PVTResultStore
    private let evaluationResultStore: EvaluationResultStore
    private let evaluationService: EvaluationService
    private let storeSyncService: PVTEvaluationStoreSyncService
    private let calendar: Calendar
    private let timeFormatter: DateFormatter
    private var cancellables = Set<AnyCancellable>()
    private var comparisonFetchTask: Task<Void, Never>?
    private var latestDisplaySleepEndAt: Date?
    private var currentEvaluationRecordDate: Date?

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
        self.storeSyncService = PVTEvaluationStoreSyncService(
            evaluationService: evaluationService ?? EvaluationService()
        )
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
                latestDisplaySleepEndAt = nil
                updateRemeasureSuggestion()
                state = state.replacingSleep(
                    placeholderSleepData(for: sleep.status, previousSummary: previousSummary),
                    sleepStatus: todaySleepDataStatus(from: sleep.status),
                    scoreMode: .pvtOnly,
                    roiStatusText: "PVT만 반영"
                )
                return
            }

            latestDisplaySleepEndAt = summary.bedEndAt
            updateRemeasureSuggestion()

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
                    bedStartAt: summary.bedStartAt,
                    bedEndText: timeFormatter.string(from: summary.bedEndAt),
                    awakeCount: summary.stageSegments.filter {
                        $0.kind == .awake && $0.durationMinutes > 2
                    }.count,
                    nightHrvMs: summary.nightHrvMs,
                    weeklyHrvBaselineMs: summary.weeklyHrvBaselineMs
                ),
                sleepStatus: .available,
                scoreMode: .full,
                roiStatusText: state.roiStatusText == "PVT만 반영" ? "안정적인 방전 상태" : state.roiStatusText
            )
        } catch {
            latestDisplaySleepEndAt = nil
            updateRemeasureSuggestion()
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
            let recordDate = await currentRecordDate()
            if let detail = try await fetchLatestEvaluationDetail(forRecordDate: recordDate) {
                currentEvaluationRecordDate = recordDate
                evaluationResultStore.apply(detail.evaluation)
            } else {
                currentEvaluationRecordDate = nil
                evaluationResultStore.clear()
            }
        } catch {
            currentEvaluationRecordDate = nil
            evaluationResultStore.clear()
        }

        await storeSyncService.restoreTodayPVTResultIfNeeded()
        applyLatestPVTResultIfNeeded()
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

        let referenceDate = currentEvaluationRecordDate
            ?? HistoryEvaluationDateResolver.calendarRecordDate(for: state.measuredAt, calendar: calendar)

        switch selectedComparison {
        case .yesterday:
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate) else {
                return nil
            }
            return averageScore(for: [yesterday])
        case .lastSevenDays:
            let dates = (1...7).compactMap { offset in
                calendar.date(byAdding: .day, value: -offset, to: referenceDate)
            }
            return averageScore(for: dates)
        case .myAverage:
            let scores = comparisonRecords
                .filter { $0.recordDate < referenceDate }
                .map(\.score)
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
        defer { updateRemeasureSuggestion() }

        guard let evaluation else {
            comparisonFetchTask?.cancel()
            comparisonRecords = []
            currentEvaluationRecordDate = nil
            state = state.replacingROI(
                score: nil,
                statusText: "PVT 미측정",
                changePercent: nil,
                measuredAt: nil
            )
            return
        }

        let recordDate = currentEvaluationRecordDate
            ?? HistoryEvaluationDateResolver.calendarRecordDate(for: evaluation.measuredAt, calendar: calendar)
        currentEvaluationRecordDate = recordDate
        scheduleComparisonRecordFetch(referenceRecordDate: recordDate)

        state = state.replacingROI(
            score: evaluation.finalScore,
            statusText: evaluation.statusLabel,
            changePercent: evaluation.trendVsYesterday,
            measuredAt: evaluation.measuredAt
        )
    }

    /// 최신 평가가 반영한 수면보다 늦게 끝난 수면이 있으면 재측정을 제안한다.
    /// 측정 이후에 잔 수면을 기존 평가에 소급 반영하지 않는 정책의 보완 흐름.
    private func updateRemeasureSuggestion() {
        guard let measuredAt = evaluationResultStore.todayEvaluation?.measuredAt,
              let sleepEndAt = latestDisplaySleepEndAt else {
            isRemeasureSuggested = false
            return
        }

        isRemeasureSuggested = measuredAt < sleepEndAt
    }

    private func scheduleComparisonRecordFetch(referenceRecordDate: Date) {
        comparisonFetchTask?.cancel()
        comparisonFetchTask = Task { [weak self] in
            await self?.loadComparisonRecords(referenceRecordDate: referenceRecordDate)
        }
    }

    private func loadComparisonRecords(referenceRecordDate: Date) async {
        guard AuthSessionStore.shared.accessToken != nil else {
            comparisonRecords = []
            return
        }

        let recordDate = calendar.startOfDay(for: referenceRecordDate)
        guard let queryEnd = calendar.date(byAdding: .day, value: 3, to: recordDate),
              let startDate = calendar.date(byAdding: .year, value: -10, to: recordDate) else {
            comparisonRecords = []
            return
        }

        do {
            let summaries = try await evaluationService.fetchSummaries(
                from: startDate,
                to: queryEnd,
                size: 1000
            )
            guard !Task.isCancelled else { return }

            let records = await comparisonRecords(from: summaries)
            guard !Task.isCancelled else { return }

            comparisonRecords = records
        } catch {
            guard !Task.isCancelled else { return }
            comparisonRecords = []
        }
    }

    private func currentRecordDate() async -> Date {
        do {
            let resolvedSleep = try await healthKitService.fetchEvaluationSleepSummary(for: Date())
            switch resolvedSleep.status {
            case .available, .noSleep:
                return calendar.startOfDay(for: resolvedSleep.date)
            case .notConnected, .syncing, .noWearableData:
                return HistoryEvaluationDateResolver.calendarRecordDate(for: Date(), calendar: calendar)
            }
        } catch {
            return HistoryEvaluationDateResolver.calendarRecordDate(for: Date(), calendar: calendar)
        }
    }

    private func fetchLatestEvaluationDetail(forRecordDate recordDate: Date) async throws -> EvaluationDetailResponse? {
        let startDate = calendar.startOfDay(for: recordDate)
        let queryEnd = calendar.date(byAdding: .day, value: 3, to: startDate) ?? startDate
        let summaries = try await evaluationService.fetchSummaries(from: startDate, to: queryEnd, size: 100)
            .sorted { $0.measuredAt > $1.measuredAt }

        for summary in summaries {
            let detail = try await evaluationService.fetchDetail(id: summary.evaluationId)
            guard HistoryEvaluationDateResolver.isRecord(
                measuredAt: detail.evaluation.measuredAt,
                sleepDateText: detail.sleep?.sleepDate,
                in: startDate,
                calendar: calendar
            ) else {
                continue
            }
            return detail
        }

        return nil
    }

    private func comparisonRecords(from summaries: [EvaluationSummary]) async -> [TodayComparisonRecord] {
        var records: [TodayComparisonRecord] = []

        for batchStart in stride(from: 0, to: summaries.count, by: Self.comparisonDetailBatchSize) {
            if Task.isCancelled { break }

            let batchEnd = min(batchStart + Self.comparisonDetailBatchSize, summaries.count)
            let batch = Array(summaries[batchStart..<batchEnd])
            let batchRecords = await withTaskGroup(of: TodayComparisonRecord?.self) { group in
                for summary in batch {
                    group.addTask { [self] in
                        await comparisonRecord(from: summary)
                    }
                }

                var batchRecords: [TodayComparisonRecord] = []
                for await record in group {
                    if let record {
                        batchRecords.append(record)
                    }
                }
                return batchRecords
            }

            records.append(contentsOf: batchRecords)
        }
        return records
    }

    private func comparisonRecord(from summary: EvaluationSummary) async -> TodayComparisonRecord? {
        do {
            let detail = try await evaluationService.fetchDetail(id: summary.evaluationId)
            let recordDate = HistoryEvaluationDateResolver.recordDate(
                measuredAt: detail.evaluation.measuredAt,
                sleepDateText: detail.sleep?.sleepDate,
                calendar: calendar
            )
            return TodayComparisonRecord(recordDate: recordDate, score: detail.evaluation.finalScore)
        } catch {
            let recordDate = HistoryEvaluationDateResolver.calendarRecordDate(
                for: summary.measuredAt,
                calendar: calendar
            )
            return TodayComparisonRecord(recordDate: recordDate, score: summary.finalScore)
        }
    }

    private func averageScore(for dates: [Date]) -> Int? {
        let scores = comparisonRecords
            .filter { record in
                dates.contains { date in
                    calendar.isDate(record.recordDate, inSameDayAs: date)
                }
            }
            .map(\.score)
        return averageScore(from: scores)
    }

    private func averageScore(from scores: [Int]) -> Int? {
        guard !scores.isEmpty else { return nil }
        return Int(round(Double(scores.reduce(0, +)) / Double(scores.count)))
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
            bedStartAt: nil,
            bedEndText: "--:--",
            awakeCount: 0,
            nightHrvMs: nil,
            weeklyHrvBaselineMs: nil
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
        case .unclassified:
            return .unclassified
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
