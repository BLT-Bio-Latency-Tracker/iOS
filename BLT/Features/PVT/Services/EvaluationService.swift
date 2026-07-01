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

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
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
    let dataCompleteness: String

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
        dataCompleteness = "FULL"
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
        isValid = summary.falseStartCount < 3 && !summary.trials.isEmpty
        invalidReason = isValid ? nil : "FALSE_START_OR_EMPTY_TRIALS"
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
    let finalScore: Int
}
