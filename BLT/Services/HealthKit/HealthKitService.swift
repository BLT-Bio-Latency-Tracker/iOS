import Foundation
import HealthKit

enum HealthKitPermissionStatus {
    case unavailable
    case requested
}

enum HealthKitServiceError: LocalizedError {
    case unavailable
    case missingSleepType
    case missingHRVType

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "이 기기에서는 HealthKit을 사용할 수 없습니다."
        case .missingSleepType:
            return "수면 데이터 타입을 찾을 수 없습니다."
        case .missingHRVType:
            return "심박변이도 데이터 타입을 찾을 수 없습니다."
        }
    }
}

struct HealthKitSleepSummary {
    let totalMinutes: Int
    let coreMinutes: Int
    let deepMinutes: Int
    let remMinutes: Int
    let awakeMinutes: Int
    let inBedMinutes: Int
    let bedStartAt: Date
    let bedEndAt: Date
    let stageSegments: [HealthKitSleepStageSegment]
    let nightHrvMs: Double?
    let weeklyHrvBaselineMs: Double?
}

struct HealthKitResolvedSleepSummary {
    let date: Date
    let status: HealthKitSleepDataStatus
    let summary: HealthKitSleepSummary?
}

enum HealthKitSleepDataStatus {
    case available
    case notConnected
    case syncing
    case noSleep
    case noWearableData
}

struct HealthKitSleepStageSegment {
    let kind: HealthKitSleepStageKind
    let startAt: Date
    let endAt: Date
    let startRatio: Double
    let durationRatio: Double
    let durationMinutes: Int
}

enum HealthKitSleepStageKind {
    case core
    case deep
    case rem
    case awake
    case unclassified
}

final class HealthKitService {
    static let sleepDataDidChangeNotification = Notification.Name("HealthKitService.sleepDataDidChange")

    private enum UserDefaultsKey {
        static let hasRequestedSleepDataConnection = "healthKit.hasRequestedSleepDataConnection"
    }

    private let healthStore = HKHealthStore()
    private let userDefaults: UserDefaults
    private var sleepObserverQuery: HKObserverQuery?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    private static var koreaCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestSleepAndHRVAuthorization() async throws -> HealthKitPermissionStatus {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.unavailable
        }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitServiceError.missingSleepType
        }

        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthKitServiceError.missingHRVType
        }

        try await healthStore.requestAuthorization(
            toShare: [],
            read: [sleepType, hrvType]
        )

        userDefaults.set(true, forKey: UserDefaultsKey.hasRequestedSleepDataConnection)
        return .requested
    }

    func markSleepDataConnectionSkipped() {
        userDefaults.set(false, forKey: UserDefaultsKey.hasRequestedSleepDataConnection)
    }

    func fetchSleepSummary(for date: Date = Date()) async throws -> HealthKitSleepSummary? {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.unavailable
        }

        let queryInterval = Self.sleepQueryInterval(for: date)
        let sleepSamples = try await fetchSleepSamples(in: queryInterval)
        guard let summary = Self.makeSleepSummary(
            from: sleepSamples,
            for: date,
            queryInterval: queryInterval
        ) else {
            return nil
        }

        return await summaryWithHRV(from: summary)
    }

    func fetchLatestSleepSummary(for date: Date = Date()) async throws -> HealthKitSleepSummary? {
        try await fetchSleepSummary(for: date)
    }

    func startObservingSleepChanges() throws {
        guard sleepObserverQuery == nil else { return }

        guard isHealthDataAvailable else {
            throw HealthKitServiceError.unavailable
        }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitServiceError.missingSleepType
        }

        let query = HKObserverQuery(sampleType: sleepType, predicate: nil) { _, completionHandler, error in
            defer { completionHandler() }

            guard error == nil else {
                return
            }

            NotificationCenter.default.post(
                name: Self.sleepDataDidChangeNotification,
                object: nil
            )
        }

        sleepObserverQuery = query
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: sleepType, frequency: .immediate) { _, _ in }
    }

    func fetchDisplaySleepSummary(for date: Date = Date()) async throws -> HealthKitResolvedSleepSummary {
        if sleepDataConnectionPreference == false {
            return HealthKitResolvedSleepSummary(
                date: date,
                status: .notConnected,
                summary: nil
            )
        }

        let queryInterval = Self.sleepQueryInterval(for: date)
        let sleepSamples = try await fetchSleepSamples(in: queryInterval)

        if let summary = Self.makeSleepSummary(
            from: sleepSamples,
            for: date,
            queryInterval: queryInterval
        ) {
            let hrvSummary = await summaryWithHRV(from: summary)
            return HealthKitResolvedSleepSummary(
                date: date,
                status: .available,
                summary: hrvSummary
            )
        }

        if Self.allowsPreviousDayDisplay(for: date),
           let fallbackDate = Self.koreaCalendar.date(byAdding: .day, value: -1, to: date),
           let fallbackSummary = try await fetchSleepSummary(for: fallbackDate) {
            return HealthKitResolvedSleepSummary(
                date: fallbackDate,
                status: .available,
                summary: fallbackSummary
            )
        }

        if Self.allowsSleepDataSyncWait(for: date) {
            return HealthKitResolvedSleepSummary(
                date: date,
                status: .syncing,
                summary: nil
            )
        }

        let status: HealthKitSleepDataStatus = sleepSamples.contains { sample in
            guard let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value) else {
                return false
            }

            return sleepValue.isSleepSessionValue
        } ? .noSleep : .noWearableData

        return HealthKitResolvedSleepSummary(
            date: date,
            status: status,
            summary: nil
        )
    }

    private var sleepDataConnectionPreference: Bool? {
        guard userDefaults.object(forKey: UserDefaultsKey.hasRequestedSleepDataConnection) != nil else {
            return nil
        }

        return userDefaults.bool(forKey: UserDefaultsKey.hasRequestedSleepDataConnection)
    }

    private func fetchSleepSamples(in queryInterval: DateInterval) async throws -> [HKCategorySample] {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.unavailable
        }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitServiceError.missingSleepType
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: queryInterval.start,
            end: queryInterval.end,
            options: [.strictEndDate]
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let sleepSamples = (samples as? [HKCategorySample]) ?? []
                continuation.resume(returning: sleepSamples)
            }

            healthStore.execute(query)
        }
    }

    private func fetchHRVSamples(in queryInterval: DateInterval) async throws -> [HKQuantitySample] {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.unavailable
        }

        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthKitServiceError.missingHRVType
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: queryInterval.start,
            end: queryInterval.end,
            options: [.strictStartDate]
        )

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let hrvSamples = (samples as? [HKQuantitySample]) ?? []
                continuation.resume(returning: hrvSamples)
            }

            healthStore.execute(query)
        }
    }

    private func summaryWithHRV(from summary: HealthKitSleepSummary) async -> HealthKitSleepSummary {
        let hrvSummary = try? await fetchHRVSummary(for: summary)

        return HealthKitSleepSummary(
            totalMinutes: summary.totalMinutes,
            coreMinutes: summary.coreMinutes,
            deepMinutes: summary.deepMinutes,
            remMinutes: summary.remMinutes,
            awakeMinutes: summary.awakeMinutes,
            inBedMinutes: summary.inBedMinutes,
            bedStartAt: summary.bedStartAt,
            bedEndAt: summary.bedEndAt,
            stageSegments: summary.stageSegments,
            nightHrvMs: hrvSummary?.nightHrvMs,
            weeklyHrvBaselineMs: hrvSummary?.weeklyHrvBaselineMs
        )
    }

    private func fetchHRVSummary(for summary: HealthKitSleepSummary) async throws -> (
        nightHrvMs: Double?,
        weeklyHrvBaselineMs: Double?
    ) {
        let session = DateInterval(start: summary.bedStartAt, end: summary.bedEndAt)
        let nightSamples = try await fetchHRVSamples(in: session)
        let nightHrvMs = Self.averageHRVMilliseconds(from: nightSamples, in: session)
        let weeklyHrvBaselineMs = try await fetchWeeklyHRVBaseline(before: session)

        return (nightHrvMs, weeklyHrvBaselineMs)
    }

    private func fetchWeeklyHRVBaseline(before currentSession: DateInterval) async throws -> Double? {
        let lookbackStart = Self.koreaCalendar.date(
            byAdding: .day,
            value: -30,
            to: currentSession.start
        ) ?? currentSession.start.addingTimeInterval(-30 * 24 * 60 * 60)

        let queryInterval = DateInterval(start: lookbackStart, end: currentSession.start)
        let sleepSamples = try await fetchSleepSamples(in: queryInterval)
        let hrvSamples = try await fetchHRVSamples(in: queryInterval)

        let sessionIntervals = sleepSamples.compactMap { sample -> DateInterval? in
            guard let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value),
                  sleepValue.isSleepSessionValue else {
                return nil
            }

            return Self.clippedInterval(
                DateInterval(start: sample.startDate, end: sample.endDate),
                to: queryInterval
            )
        }

        let recentSessions = Self.groupedSleepSessions(from: sessionIntervals)
            .filter { $0.end <= currentSession.start }
            .suffix(7)

        let sessionAverages = recentSessions.compactMap { session in
            Self.averageHRVMilliseconds(from: hrvSamples, in: session)
        }

        guard !sessionAverages.isEmpty else { return nil }
        return sessionAverages.reduce(0, +) / Double(sessionAverages.count)
    }

    private static func sleepQueryInterval(for date: Date) -> DateInterval {
        let sleepDay = sleepDay(for: date)
        let queryStart = koreaCalendar.date(byAdding: .hour, value: -6, to: sleepDay) ?? sleepDay
        let sleepWindowEnd = koreaCalendar.date(byAdding: .hour, value: 18, to: sleepDay) ?? date
        let queryEnd = min(sleepWindowEnd, Date())

        return DateInterval(start: queryStart, end: queryEnd)
    }

    private static func allowsSleepDataSyncWait(for date: Date) -> Bool {
        koreaCalendar.component(.hour, from: date) < 6
    }

    private static func allowsPreviousDayDisplay(for date: Date) -> Bool {
        koreaCalendar.component(.hour, from: date) < 6
    }

    private static func sleepDay(for date: Date) -> Date {
        let hour = koreaCalendar.component(.hour, from: date)
        let baseDate = hour < 6
            ? (koreaCalendar.date(byAdding: .day, value: -1, to: date) ?? date)
            : date

        return koreaCalendar.startOfDay(for: baseDate)
    }

    private static func makeSleepSummary(
        from samples: [HKCategorySample],
        for date: Date,
        queryInterval: DateInterval
    ) -> HealthKitSleepSummary? {
        guard let sleepSession = sleepSession(
            from: samples,
            for: date,
            queryInterval: queryInterval
        ) else {
            return nil
        }

        var asleepIntervals: [DateInterval] = []
        var coreIntervals: [DateInterval] = []
        var deepIntervals: [DateInterval] = []
        var remIntervals: [DateInterval] = []
        var awakeIntervals: [DateInterval] = []

        for sample in samples {
            let sampleInterval = DateInterval(start: sample.startDate, end: sample.endDate)
            guard let queryClippedInterval = clippedInterval(sampleInterval, to: queryInterval),
                  let interval = clippedInterval(queryClippedInterval, to: sleepSession) else {
                continue
            }
            guard interval.duration > 0 else { continue }

            guard let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value) else {
                continue
            }

            switch sleepValue {
            case .asleepCore:
                asleepIntervals.append(interval)
                coreIntervals.append(interval)
            case .asleepDeep:
                asleepIntervals.append(interval)
                deepIntervals.append(interval)
            case .asleepREM:
                asleepIntervals.append(interval)
                remIntervals.append(interval)
            case .asleepUnspecified:
                asleepIntervals.append(interval)
            case .awake:
                awakeIntervals.append(interval)
            default:
                continue
            }
        }

        let totalMinutes = SleepIntervalCalculator.minutesAfterMerging(asleepIntervals)
        guard totalMinutes > 0 else { return nil }

        return HealthKitSleepSummary(
            totalMinutes: totalMinutes,
            coreMinutes: SleepIntervalCalculator.minutesAfterMerging(coreIntervals),
            deepMinutes: SleepIntervalCalculator.minutesAfterMerging(deepIntervals),
            remMinutes: SleepIntervalCalculator.minutesAfterMerging(remIntervals),
            awakeMinutes: SleepIntervalCalculator.minutesAfterMerging(awakeIntervals),
            inBedMinutes: Int((sleepSession.duration / 60).rounded()),
            bedStartAt: sleepSession.start,
            bedEndAt: sleepSession.end,
            stageSegments: sleepStageSegments(
                from: samples,
                in: sleepSession,
                queryInterval: queryInterval
            ),
            nightHrvMs: nil,
            weeklyHrvBaselineMs: nil
        )
    }

    private static func averageHRVMilliseconds(
        from samples: [HKQuantitySample],
        in interval: DateInterval
    ) -> Double? {
        let unit = HKUnit.secondUnit(with: .milli)
        let values = samples.compactMap { sample -> Double? in
            guard interval.contains(sample.startDate) else { return nil }
            return sample.quantity.doubleValue(for: unit)
        }

        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func sleepStageSegments(
        from samples: [HKCategorySample],
        in session: DateInterval,
        queryInterval: DateInterval
    ) -> [HealthKitSleepStageSegment] {
        let timelineIntervals = samples.compactMap { sample -> (kind: HealthKitSleepStageKind, interval: DateInterval)? in
            guard let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value),
                  let kind = sleepValue.timelineKind else {
                return nil
            }

            let sampleInterval = DateInterval(start: sample.startDate, end: sample.endDate)
            guard let queryClippedInterval = clippedInterval(sampleInterval, to: queryInterval),
                  let interval = clippedInterval(queryClippedInterval, to: session),
                  interval.duration > 0 else {
                return nil
            }

            return (kind, interval)
        }
        .sorted { $0.interval.start < $1.interval.start }

        guard let timelineStart = timelineIntervals.first?.interval.start,
              let timelineEnd = timelineIntervals.map(\.interval.end).max(),
              timelineStart < timelineEnd else {
            return []
        }

        let timelineDuration = timelineEnd.timeIntervalSince(timelineStart)

        return timelineIntervals.map { segment in
            let startRatio = segment.interval.start.timeIntervalSince(timelineStart) / timelineDuration
            let durationRatio = segment.interval.duration / timelineDuration

            return HealthKitSleepStageSegment(
                kind: segment.kind,
                startAt: segment.interval.start,
                endAt: segment.interval.end,
                startRatio: min(max(startRatio, 0), 1),
                durationRatio: min(max(durationRatio, 0), 1),
                durationMinutes: Int((segment.interval.duration / 60).rounded())
            )
        }
    }

    private static func sleepSession(
        from samples: [HKCategorySample],
        for date: Date,
        queryInterval: DateInterval
    ) -> DateInterval? {
        let targetDay = sleepDay(for: date)

        let sessionIntervals = samples.compactMap { sample -> DateInterval? in
            guard let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value),
                  sleepValue.isSleepSessionValue else {
                return nil
            }

            let interval = DateInterval(start: sample.startDate, end: sample.endDate)
            return clippedInterval(interval, to: queryInterval)
        }

        let sessions = groupedSleepSessions(from: sessionIntervals)
            .filter { sleepDay(for: $0.end) == targetDay }

        return sessions.max {
            sleepMinutes(in: $0, from: samples, queryInterval: queryInterval) <
                sleepMinutes(in: $1, from: samples, queryInterval: queryInterval)
        }
    }

    private static func groupedSleepSessions(from intervals: [DateInterval]) -> [DateInterval] {
        let sortedIntervals = intervals
            .filter { $0.duration > 0 }
            .sorted { $0.start < $1.start }

        guard var current = sortedIntervals.first else { return [] }

        let maxGapWithinSession: TimeInterval = 30 * 60
        var sessions: [DateInterval] = []

        for interval in sortedIntervals.dropFirst() {
            let gap = interval.start.timeIntervalSince(current.end)

            if gap <= maxGapWithinSession {
                current = DateInterval(
                    start: current.start,
                    end: max(current.end, interval.end)
                )
            } else {
                sessions.append(current)
                current = interval
            }
        }

        sessions.append(current)
        return sessions
    }

    private static func sleepMinutes(
        in session: DateInterval,
        from samples: [HKCategorySample],
        queryInterval: DateInterval
    ) -> Int {
        let asleepIntervals = samples.compactMap { sample -> DateInterval? in
            guard let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value),
                  sleepValue.isAsleepValue else {
                return nil
            }

            let interval = DateInterval(start: sample.startDate, end: sample.endDate)
            guard let queryClippedInterval = clippedInterval(interval, to: queryInterval) else {
                return nil
            }

            return clippedInterval(queryClippedInterval, to: session)
        }

        return SleepIntervalCalculator.minutesAfterMerging(asleepIntervals)
    }

    private static func clippedInterval(
        _ interval: DateInterval,
        to bounds: DateInterval
    ) -> DateInterval? {
        let start = max(interval.start, bounds.start)
        let end = min(interval.end, bounds.end)

        guard start < end else { return nil }
        return DateInterval(start: start, end: end)
    }
}

private extension HKCategoryValueSleepAnalysis {
    var isSleepSessionValue: Bool {
        switch self {
        case .asleepCore, .asleepDeep, .asleepREM, .asleepUnspecified, .awake:
            return true
        default:
            return false
        }
    }

    var isAsleepValue: Bool {
        switch self {
        case .asleepCore, .asleepDeep, .asleepREM, .asleepUnspecified:
            return true
        default:
            return false
        }
    }

    var timelineKind: HealthKitSleepStageKind? {
        switch self {
        case .asleepCore:
            return .core
        case .asleepUnspecified:
            return .unclassified
        case .asleepDeep:
            return .deep
        case .asleepREM:
            return .rem
        case .awake:
            return .awake
        default:
            return nil
        }
    }
}
