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

        return Self.makeSleepSummary(
            from: sleepSamples,
            for: date,
            queryInterval: queryInterval
        )
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
            return HealthKitResolvedSleepSummary(
                date: date,
                status: .available,
                summary: summary
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

        let totalMinutes = minutesAfterMerging(asleepIntervals)
        guard totalMinutes > 0 else { return nil }

        return HealthKitSleepSummary(
            totalMinutes: totalMinutes,
            coreMinutes: minutesAfterMerging(coreIntervals),
            deepMinutes: minutesAfterMerging(deepIntervals),
            remMinutes: minutesAfterMerging(remIntervals),
            awakeMinutes: minutesAfterMerging(awakeIntervals),
            inBedMinutes: Int((sleepSession.duration / 60).rounded()),
            bedStartAt: sleepSession.start,
            bedEndAt: sleepSession.end,
            stageSegments: sleepStageSegments(
                from: samples,
                in: sleepSession,
                queryInterval: queryInterval
            )
        )
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

        return minutesAfterMerging(asleepIntervals)
    }

    private static func minutesAfterMerging(_ intervals: [DateInterval]) -> Int {
        let totalSeconds = mergedIntervals(intervals).reduce(0) { result, interval in
            result + interval.duration
        }

        return Int((totalSeconds / 60).rounded())
    }

    private static func mergedIntervals(_ intervals: [DateInterval]) -> [DateInterval] {
        let sortedIntervals = intervals
            .filter { $0.duration > 0 }
            .sorted { $0.start < $1.start }

        guard var current = sortedIntervals.first else { return [] }

        var merged: [DateInterval] = []

        for interval in sortedIntervals.dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(
                    start: current.start,
                    end: max(current.end, interval.end)
                )
            } else {
                merged.append(current)
                current = interval
            }
        }

        merged.append(current)

        return merged
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
        case .asleepCore, .asleepUnspecified:
            return .core
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
