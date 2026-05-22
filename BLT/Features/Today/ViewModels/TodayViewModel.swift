import Foundation
import Combine

@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var state: TodayViewState
    @Published var selectedComparison: TodayComparisonType

    private let healthKitService: HealthKitService
    private let timeFormatter: DateFormatter

    init(
        state: TodayViewState? = nil,
        selectedComparison: TodayComparisonType = .yesterday,
        healthKitService: HealthKitService? = nil
    ) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        formatter.dateFormat = "HH:mm"
        self.timeFormatter = formatter
        self.healthKitService = healthKitService ?? HealthKitService()

        self.state = state ?? TodayViewState.sleepConnectedPlaceholder
        self.selectedComparison = selectedComparison
    }

    func loadHealthKitSleepSummary() async {
        do {
            guard let sleep = try await latestAvailableSleepSummary(from: Date()) else {
                state = TodayViewState.sleepDisconnectedPlaceholder
                return
            }

            let previousDate = Calendar.bltKorea.date(byAdding: .day, value: -1, to: sleep.date) ?? sleep.date
            let previousSummary = try? await healthKitService.fetchSleepSummary(for: previousDate)
            let sleepDifference = sleepDifferenceText(
                todayMinutes: sleep.summary.totalMinutes,
                yesterdayMinutes: previousSummary?.totalMinutes
            )

            state = state.replacingSleep(
                TodaySleepData(
                    totalSleepText: totalSleepText(from: sleep.summary.totalMinutes),
                    totalMinutes: sleep.summary.totalMinutes,
                    differenceText: sleepDifference.text,
                    differenceDirection: sleepDifference.direction,
                    stages: sleepStages(from: sleep.summary),
                    coreMinutes: sleep.summary.coreMinutes,
                    deepMinutes: sleep.summary.deepMinutes,
                    remMinutes: sleep.summary.remMinutes,
                    awakeMinutes: sleep.summary.awakeMinutes,
                    inBedMinutes: sleep.summary.inBedMinutes,
                    bedStartText: timeFormatter.string(from: sleep.summary.bedStartAt),
                    bedEndText: timeFormatter.string(from: sleep.summary.bedEndAt),
                    awakeCount: sleep.summary.stageSegments.filter {
                        $0.kind == .awake && $0.durationMinutes > 2
                    }.count
                ),
                scoreMode: .full,
                roiStatusText: state.roiStatusText == "PVT만 반영" ? "안정적인 방전 상태" : state.roiStatusText
            )
        } catch {
            state = TodayViewState.sleepDisconnectedPlaceholder
        }
    }

    var measuredTimeText: String {
        timeFormatter.string(from: state.measuredAt)
    }

    var roiFooterText: String {
        if state.isSleepDataConnected {
            return "\(state.roiStatusText) · \(measuredTimeText) 측정"
        }
        return "오늘 \(measuredTimeText) 측정 · PVT만 반영"
    }

    var roiIndexTitle: String {
        state.isSleepDataConnected ? "BRAIN ROI INDEX" : "BRAIN ROI INDEX · PVT 단독"
    }

    var comparisonSummaryTitle: String {
        guard state.isSleepDataConnected else {
            return "수면 데이터가 없어 종합 점수 산출 불가 · 연동 시 +35%"
        }
        return "✨ 어제보다 \(state.roiChangePercent)% 향상!"
    }

    var comparisonSummarySubtitle: String? {
        state.isSleepDataConnected ? state.comparisonSummary : nil
    }

    private func totalSleepText(from totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(minutes)m"
    }

    private func latestAvailableSleepSummary(
        from date: Date
    ) async throws -> (date: Date, summary: HealthKitSleepSummary)? {
        if let summary = try await healthKitService.fetchSleepSummary(for: date) {
            return (date, summary)
        }

        guard let fallbackDate = Calendar.bltKorea.date(byAdding: .day, value: -1, to: date) else {
            return nil
        }

        guard let fallbackSummary = try await healthKitService.fetchSleepSummary(for: fallbackDate) else {
            return nil
        }

        return (fallbackDate, fallbackSummary)
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
