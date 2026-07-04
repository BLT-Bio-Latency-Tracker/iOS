import Foundation

struct EvaluationService {
    private let networkClient: NetworkClient
    private let healthKitService: HealthKitService

    init(
        networkClient: NetworkClient = .shared,
        healthKitService: HealthKitService = HealthKitService()
    ) {
        self.networkClient = networkClient
        self.healthKitService = healthKitService
    }

    func submit(
        summary: PVTSummary,
        measuredAt: Date = Date(),
        measurementId: UUID = UUID()
    ) async throws -> EvaluationResponse {
        let sleep = try? await healthKitService.fetchDisplaySleepSummary(for: measuredAt)
        return try await submit(
            summary: summary,
            measuredAt: measuredAt,
            measurementId: measurementId,
            resolvedSleep: sleep
        )
    }

    func submit(
        summary: PVTSummary,
        measuredAt: Date,
        measurementId: UUID,
        resolvedSleep: HealthKitResolvedSleepSummary?
    ) async throws -> EvaluationResponse {
        let timezone = TimeZone.current
        let request = EvaluationCreateRequest(
            evaluatedAt: measuredAt,
            timezone: timezone.identifier,
            healthKitData: resolvedSleep.flatMap { HealthKitDataRequest(resolvedSleep: $0, timezone: timezone) },
            pvt: PvtRequest(summary: summary, measuredAt: measuredAt, measurementId: measurementId)
        )

        return try await networkClient.post(
            "/api/v1/evaluations",
            body: request,
            requiresAuth: true
        )
    }

    func fetchToday() async throws -> EvaluationResponse {
        try await networkClient.get(
            "/api/v1/evaluations/today",
            requiresAuth: true
        )
    }

    func fetchSummaries(from: Date, to: Date, size: Int = 1000) async throws -> [EvaluationSummary] {
        let response: EvaluationPageResponse = try await networkClient.get(
            "/api/v1/evaluations",
            queryItems: [
                URLQueryItem(name: "from", value: Self.dateText(from)),
                URLQueryItem(name: "to", value: Self.dateText(to)),
                URLQueryItem(name: "size", value: String(size))
            ],
            requiresAuth: true
        )
        return response.items
    }

    func fetchDetail(id: Int) async throws -> EvaluationDetailResponse {
        try await networkClient.get(
            "/api/v1/evaluations/\(id)",
            requiresAuth: true
        )
    }

    func deleteEvaluation(id: Int) async throws {
        let _: EmptyResponse = try await networkClient.delete(
            "/api/v1/evaluations/\(id)",
            requiresAuth: true
        )
    }

    func fetchLatestPVTMeasurementForMeasurementDay(containing date: Date = Date()) async throws -> EvaluationPVTMeasurement? {
        let interval = Self.measurementDayInterval(containing: date)
        let summaries = try await fetchSummaries(from: interval.start, to: interval.end, size: 100)
        let filteredSummaries = summaries
            .filter { $0.measuredAt >= interval.start && $0.measuredAt < interval.end }
            .sorted { $0.measuredAt > $1.measuredAt }

        for summary in filteredSummaries {
            let detail = try await fetchDetail(id: summary.evaluationId)
            guard detail.pvt.isValid else { continue }

            return EvaluationPVTMeasurement(
                evaluationId: summary.evaluationId,
                measuredAt: detail.evaluation.measuredAt,
                pvt: detail.pvt
            )
        }

        return nil
    }

    func fetchPVTDetailsForMeasurementDay(containing date: Date = Date()) async throws -> [EvaluationPVTMeasurement] {
        let interval = Self.measurementDayInterval(containing: date)
        let summaries = try await fetchSummaries(from: interval.start, to: interval.end, size: 100)
        let filteredSummaries = summaries
            .filter { $0.measuredAt >= interval.start && $0.measuredAt < interval.end }
            .sorted { $0.measuredAt < $1.measuredAt }

        var measurementsByMeasurementId: [UUID: EvaluationPVTMeasurement] = [:]
        for summary in filteredSummaries {
            let detail = try await fetchDetail(id: summary.evaluationId)
            let measurement = EvaluationPVTMeasurement(
                evaluationId: summary.evaluationId,
                measuredAt: detail.evaluation.measuredAt,
                pvt: detail.pvt
            )
            if let previous = measurementsByMeasurementId[detail.pvt.measurementId],
               previous.measuredAt >= measurement.measuredAt {
                continue
            } else {
                measurementsByMeasurementId[detail.pvt.measurementId] = measurement
            }
        }

        return measurementsByMeasurementId.values.sorted { $0.measuredAt < $1.measuredAt }
    }

    private static func dateText(_ date: Date) -> String {
        EvaluationDateFormatter.dateText(date)
    }

    private static func measurementDayInterval(containing date: Date) -> DateInterval {
        let startOfDay = koreaCalendar.startOfDay(for: date)
        let hour = koreaCalendar.component(.hour, from: date)
        let baseDay = hour < 6
            ? koreaCalendar.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
            : startOfDay
        let start = koreaCalendar.date(byAdding: .hour, value: 6, to: baseDay) ?? baseDay
        let end = koreaCalendar.date(byAdding: .day, value: 1, to: start) ?? date
        return DateInterval(start: start, end: end)
    }

    private static var koreaCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }
}

enum EvaluationDateFormatter {
    static func dateText(_ date: Date, timeZone: TimeZone = TimeZone(identifier: "Asia/Seoul") ?? .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private struct EvaluationPageResponse: Decodable {
    let items: [EvaluationSummary]
}

struct EvaluationCreateRequest: Encodable {
    let evaluatedAt: Date
    let timezone: String
    let healthKitData: HealthKitDataRequest?
    let pvt: PvtRequest
}

struct HealthKitDataRequest: Encodable {
    let sleepDate: String
    let totalMinutes: Int
    let deepMinutes: Int
    let remMinutes: Int
    let coreMinutes: Int
    let awakeMinutes: Int
    let inBedMinutes: Int
    let nightHrvMs: Double?
    let weeklyHrvBaselineMs: Double?
    let dataCompleteness: String
    let stages: [SleepStageSegmentRequest]

    init?(resolvedSleep: HealthKitResolvedSleepSummary, timezone: TimeZone) {
        guard let summary = resolvedSleep.summary else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"

        sleepDate = formatter.string(from: resolvedSleep.date)
        totalMinutes = summary.totalMinutes
        deepMinutes = summary.deepMinutes
        remMinutes = summary.remMinutes
        coreMinutes = summary.coreMinutes
        awakeMinutes = summary.awakeMinutes
        inBedMinutes = summary.inBedMinutes
        nightHrvMs = summary.nightHrvMs
        weeklyHrvBaselineMs = summary.weeklyHrvBaselineMs
        dataCompleteness = "FULL"
        stages = summary.stageSegments.map(SleepStageSegmentRequest.init)
    }
}

struct SleepStageSegmentRequest: Encodable {
    let stage: String
    let startAt: Date
    let endAt: Date

    init(segment: HealthKitSleepStageSegment) {
        stage = Self.stageName(for: segment.kind)
        startAt = segment.startAt
        endAt = segment.endAt
    }

    private static func stageName(for kind: HealthKitSleepStageKind) -> String {
        switch kind {
        case .core:
            return "CORE"
        case .deep:
            return "DEEP"
        case .rem:
            return "REM"
        case .awake:
            return "AWAKE"
        case .unclassified:
            return "UNSPECIFIED"
        }
    }
}

struct PvtRequest: Encodable {
    let measurementId: UUID
    let startedAt: Date
    let endedAt: Date
    let totalDurationMs: Int
    let totalCount: Int
    let rawRtMs: [Int]
    let avgRtMs: Double
    let medianRtMs: Double
    let lapsesMild: Int
    let lapsesTimeout: Int
    let falseStarts: Int
    let isValid: Bool
    let invalidReason: String?
    let trials: [PvtTrialRequest]

    init(summary: PVTSummary, measuredAt: Date, measurementId: UUID) {
        let rawReactionTimes = summary.trials.map(\.reactionTimeMilliseconds)
        let sortedReactionTimes = rawReactionTimes.sorted()
        let median: Double
        if sortedReactionTimes.isEmpty {
            median = 0
        } else if sortedReactionTimes.count.isMultiple(of: 2) {
            let upperIndex = sortedReactionTimes.count / 2
            median = Double(sortedReactionTimes[upperIndex - 1] + sortedReactionTimes[upperIndex]) / 2
        } else {
            median = Double(sortedReactionTimes[sortedReactionTimes.count / 2])
        }

        self.measurementId = measurementId
        endedAt = measuredAt
        startedAt = measuredAt.addingTimeInterval(-30)
        totalDurationMs = 30_000
        totalCount = summary.trials.count
        rawRtMs = rawReactionTimes
        avgRtMs = Double(summary.averageMilliseconds ?? 0)
        medianRtMs = median
        lapsesMild = summary.lapseCount
        lapsesTimeout = 0
        falseStarts = summary.falseStartCount
        isValid = !summary.trials.isEmpty && summary.averageMilliseconds != nil
        if isValid {
            invalidReason = nil
        } else if summary.trials.isEmpty {
            invalidReason = "EMPTY_TRIALS"
        } else {
            invalidReason = "MISSING_AVERAGE_RT"
        }
        trials = summary.trials.map(PvtTrialRequest.init)
    }
}

struct PvtTrialRequest: Encodable {
    let index: Int
    let rtMs: Int
    let isLapse: Bool

    init(trial: PVTTrial) {
        index = trial.index
        rtMs = trial.reactionTimeMilliseconds
        isLapse = trial.isLapse
    }
}

struct EvaluationResponse: Decodable {
    let evaluationId: Int
    let finalScore: Int
    let sleepScore: Int
    let pvtScore: Int
    let statusLabel: String
    let trendVsYesterday: Int?
    let measuredAt: Date
}

struct EvaluationSummary: Decodable {
    let evaluationId: Int
    let date: String
    let measuredAt: Date
    let finalScore: Int
}

struct EvaluationDetailResponse: Decodable {
    let evaluation: EvaluationResponse
    let sleep: EvaluationSleepDetail?
    let pvt: PvtDetail
}

struct EvaluationSleepDetail: Decodable {
    let sleepDate: String
    let totalMinutes: Int
    let deepMinutes: Int
    let remMinutes: Int
    let coreMinutes: Int
    let awakeMinutes: Int
    let inBedMinutes: Int
    let efficiencyPercent: Int?
    let deepRatioPercent: Int?
    let remRatioPercent: Int?
    let lightRatioPercent: Int?
    let nightHrvMs: Double?
    let weeklyHrvBaselineMs: Double?
    let dataCompleteness: String?
    let stages: [SleepStageSegmentResponse]

    private enum CodingKeys: String, CodingKey {
        case sleepDate
        case totalMinutes
        case deepMinutes
        case remMinutes
        case coreMinutes
        case awakeMinutes
        case inBedMinutes
        case efficiencyPercent
        case deepRatioPercent
        case remRatioPercent
        case lightRatioPercent
        case nightHrvMs
        case weeklyHrvBaselineMs
        case dataCompleteness
        case stages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sleepDate = try container.decode(String.self, forKey: .sleepDate)
        totalMinutes = try container.decode(Int.self, forKey: .totalMinutes)
        deepMinutes = try container.decodeIfPresent(Int.self, forKey: .deepMinutes) ?? 0
        remMinutes = try container.decodeIfPresent(Int.self, forKey: .remMinutes) ?? 0
        coreMinutes = try container.decodeIfPresent(Int.self, forKey: .coreMinutes) ?? 0
        awakeMinutes = try container.decodeIfPresent(Int.self, forKey: .awakeMinutes) ?? 0
        inBedMinutes = try container.decodeIfPresent(Int.self, forKey: .inBedMinutes) ?? 0
        efficiencyPercent = try container.decodeIfPresent(Int.self, forKey: .efficiencyPercent)
        deepRatioPercent = try container.decodeIfPresent(Int.self, forKey: .deepRatioPercent)
        remRatioPercent = try container.decodeIfPresent(Int.self, forKey: .remRatioPercent)
        lightRatioPercent = try container.decodeIfPresent(Int.self, forKey: .lightRatioPercent)
        nightHrvMs = try container.decodeIfPresent(Double.self, forKey: .nightHrvMs)
        weeklyHrvBaselineMs = try container.decodeIfPresent(Double.self, forKey: .weeklyHrvBaselineMs)
        dataCompleteness = try container.decodeIfPresent(String.self, forKey: .dataCompleteness)
        stages = try container.decodeIfPresent([SleepStageSegmentResponse].self, forKey: .stages) ?? []
    }
}

struct SleepStageSegmentResponse: Decodable, Equatable {
    let stage: String
    let startAt: Date
    let endAt: Date
}

struct PvtDetail: Decodable {
    let measurementId: UUID
    let avgRtMs: Double
    let bestRtMs: Int?
    let medianRtMs: Double?
    let lapsesMild: Int
    let lapsesTimeout: Int
    let falseStarts: Int
    let totalCount: Int
    let rawRtMs: [Int]
    let isValid: Bool
}

struct EvaluationPVTMeasurement {
    let evaluationId: Int
    let measuredAt: Date
    let pvt: PvtDetail
}
