import Foundation
import SwiftUI

struct HistoryDayDetailState {
    var selectedDate: Date
    var isLoading: Bool
    var errorMessage: String?
    var evaluations: [HistoryDayEvaluation]
    var sleep: HistoryDaySleepSummary?

    var hasData: Bool {
        !evaluations.isEmpty
    }

    var sortedEvaluations: [HistoryDayEvaluation] {
        evaluations.sorted { $0.measuredAt < $1.measuredAt }
    }

    var pvtCount: Int {
        evaluations.count
    }

    var averageROI: Int? {
        roundedAverage(evaluations.map(\.finalScore))
    }

    var totalSleepMinutes: Int? {
        sleep?.totalMinutes ?? evaluations.compactMap(\.serverSleep?.totalMinutes).first
    }

    static func empty(date: Date) -> HistoryDayDetailState {
        HistoryDayDetailState(
            selectedDate: date,
            isLoading: false,
            errorMessage: nil,
            evaluations: [],
            sleep: nil
        )
    }

    private func roundedAverage(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }
}

struct HistoryDayEvaluation: Identifiable, Equatable {
    let id: Int
    let measuredAt: Date
    let finalScore: Int
    let statusLabel: String
    let pvt: HistoryDayPVT
    let serverSleep: HistoryServerSleepSummary?
}

struct HistoryDayPVT: Equatable {
    let measurementId: UUID
    let averageMilliseconds: Int
    let bestMilliseconds: Int?
    let lapseCount: Int
    let falseStartCount: Int
    let totalCount: Int
    let rawReactionTimes: [Int]

    init(detail: PvtDetail) {
        measurementId = detail.measurementId
        averageMilliseconds = Int(detail.avgRtMs.rounded())
        bestMilliseconds = detail.bestRtMs ?? detail.rawRtMs.min()
        lapseCount = detail.lapsesMild + detail.lapsesTimeout
        falseStartCount = detail.falseStarts
        totalCount = detail.totalCount
        rawReactionTimes = detail.rawRtMs
    }
}

struct HistoryServerSleepSummary: Equatable {
    let totalMinutes: Int
    let deepMinutes: Int
    let remMinutes: Int
    let coreMinutes: Int
    let awakeMinutes: Int
    let inBedMinutes: Int

    init(detail: EvaluationSleepDetail) {
        totalMinutes = detail.totalMinutes
        deepMinutes = detail.deepMinutes
        remMinutes = detail.remMinutes
        coreMinutes = detail.coreMinutes
        awakeMinutes = detail.awakeMinutes
        inBedMinutes = detail.inBedMinutes
    }
}

struct HistoryDaySleepSummary: Equatable {
    let totalMinutes: Int
    let coreMinutes: Int
    let deepMinutes: Int
    let remMinutes: Int
    let awakeMinutes: Int
    let bedStartAt: Date?
    let bedEndAt: Date?
    let stageSegments: [HistoryDaySleepStageSegment]

    init(summary: HealthKitSleepSummary) {
        totalMinutes = summary.totalMinutes
        coreMinutes = summary.coreMinutes
        deepMinutes = summary.deepMinutes
        remMinutes = summary.remMinutes
        awakeMinutes = summary.awakeMinutes
        bedStartAt = summary.bedStartAt
        bedEndAt = summary.bedEndAt
        stageSegments = summary.stageSegments.map(HistoryDaySleepStageSegment.init)
    }

    init(serverSleep: HistoryServerSleepSummary) {
        totalMinutes = serverSleep.totalMinutes
        coreMinutes = serverSleep.coreMinutes
        deepMinutes = serverSleep.deepMinutes
        remMinutes = serverSleep.remMinutes
        awakeMinutes = serverSleep.awakeMinutes
        bedStartAt = nil
        bedEndAt = nil
        stageSegments = HistoryDaySleepStageSegment.aggregateSegments(
            coreMinutes: serverSleep.coreMinutes,
            deepMinutes: serverSleep.deepMinutes,
            remMinutes: serverSleep.remMinutes,
            awakeMinutes: serverSleep.awakeMinutes
        )
    }
}

struct HistoryDaySleepStageSegment: Identifiable, Equatable {
    let id = UUID()
    let kind: HistoryDaySleepStageKind
    let startRatio: Double
    let durationRatio: Double
    let durationMinutes: Int

    init(segment: HealthKitSleepStageSegment) {
        kind = HistoryDaySleepStageKind(kind: segment.kind)
        startRatio = segment.startRatio
        durationRatio = segment.durationRatio
        durationMinutes = segment.durationMinutes
    }

    private init(
        kind: HistoryDaySleepStageKind,
        startRatio: Double,
        durationRatio: Double,
        durationMinutes: Int
    ) {
        self.kind = kind
        self.startRatio = startRatio
        self.durationRatio = durationRatio
        self.durationMinutes = durationMinutes
    }

    static func aggregateSegments(
        coreMinutes: Int,
        deepMinutes: Int,
        remMinutes: Int,
        awakeMinutes: Int
    ) -> [HistoryDaySleepStageSegment] {
        let values: [(HistoryDaySleepStageKind, Int)] = [
            (.core, coreMinutes),
            (.deep, deepMinutes),
            (.rem, remMinutes),
            (.awake, awakeMinutes)
        ].filter { $0.1 > 0 }

        let total = max(1, values.map(\.1).reduce(0, +))
        var cursor = 0.0
        return values.map { kind, minutes in
            let ratio = Double(minutes) / Double(total)
            defer { cursor += ratio }
            return HistoryDaySleepStageSegment(
                kind: kind,
                startRatio: cursor,
                durationRatio: ratio,
                durationMinutes: minutes
            )
        }
    }
}

enum HistoryDaySleepStageKind: Equatable {
    case core
    case deep
    case rem
    case awake

    init(kind: HealthKitSleepStageKind) {
        switch kind {
        case .core:
            self = .core
        case .deep:
            self = .deep
        case .rem:
            self = .rem
        case .awake:
            self = .awake
        }
    }

    var title: String {
        switch self {
        case .core:
            return "얕은"
        case .deep:
            return "깊은"
        case .rem:
            return "REM"
        case .awake:
            return "비수면"
        }
    }

    var color: Color {
        switch self {
        case .core:
            return Color(red: 0.133, green: 0.827, blue: 0.933).opacity(0.72)
        case .deep:
            return Color(red: 0.486, green: 0.361, blue: 1)
        case .rem:
            return Color(red: 0.961, green: 0.62, blue: 0.043)
        case .awake:
            return Color(red: 0.937, green: 0.267, blue: 0.267)
        }
    }
}
