import Foundation
import Testing
@testable import Bryki

@MainActor
struct HealthKitEvaluationSleepPolicyTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    @Test func usesLatestCompletedSleepBeforePVTWhenWakeIsRecent() {
        let measuredAt = date(2026, 7, 4, 2)
        let previousSleep = sleep(
            start: date(2026, 7, 3, 3),
            end: date(2026, 7, 3, 9)
        )
        let olderSleep = sleep(
            start: date(2026, 7, 2, 1),
            end: date(2026, 7, 2, 7)
        )

        let resolved = HealthKitEvaluationSleepPolicy.resolve(
            measuredAt: measuredAt,
            completedSleepSummaries: [olderSleep, previousSleep],
            calendar: calendar
        )

        #expect(resolved.status == .available)
        #expect(resolved.summary?.bedEndAt == previousSleep.bedEndAt)
        #expect(calendar.isDate(resolved.date, inSameDayAs: date(2026, 7, 3, 0)))
    }

    @Test func ignoresSleepThatEndsAfterPVTMeasurement() {
        let measuredAt = date(2026, 7, 4, 2)
        let futureSleep = sleep(
            start: date(2026, 7, 4, 3),
            end: date(2026, 7, 4, 9)
        )

        let resolved = HealthKitEvaluationSleepPolicy.resolve(
            measuredAt: measuredAt,
            completedSleepSummaries: [futureSleep],
            calendar: calendar
        )

        #expect(resolved.status == .noWearableData)
        #expect(resolved.summary == nil)
    }

    @Test func returnsZeroSleepWhenLastWakeIsAtLeast28HoursAgo() {
        let measuredAt = date(2026, 7, 4, 13)
        let staleSleep = sleep(
            start: date(2026, 7, 3, 1),
            end: date(2026, 7, 3, 9)
        )

        let resolved = HealthKitEvaluationSleepPolicy.resolve(
            measuredAt: measuredAt,
            completedSleepSummaries: [staleSleep],
            calendar: calendar
        )

        #expect(resolved.status == .noSleep)
        #expect(resolved.summary?.totalMinutes == 0)
        #expect(resolved.summary?.bedStartAt == measuredAt)
        #expect(calendar.isDate(resolved.date, inSameDayAs: date(2026, 7, 4, 0)))
    }

    @Test func doesNotInventZeroSleepWhenNoPriorWakeExists() {
        let measuredAt = date(2026, 7, 4, 13)

        let resolved = HealthKitEvaluationSleepPolicy.resolve(
            measuredAt: measuredAt,
            completedSleepSummaries: [],
            calendar: calendar
        )

        #expect(resolved.status == .noWearableData)
        #expect(resolved.summary == nil)
    }

    @Test func sendsZeroSleepAsTotalOnlyHealthKitData() throws {
        let measuredAt = date(2026, 7, 4, 13)
        let staleSleep = sleep(
            start: date(2026, 7, 3, 1),
            end: date(2026, 7, 3, 9)
        )
        let resolved = HealthKitEvaluationSleepPolicy.resolve(
            measuredAt: measuredAt,
            completedSleepSummaries: [staleSleep],
            calendar: calendar
        )

        let request = try #require(HealthKitDataRequest(
            resolvedSleep: resolved,
            timezone: calendar.timeZone
        ))

        #expect(request.totalMinutes == 0)
        #expect(request.inBedMinutes == 0)
        #expect(request.dataCompleteness == "TOTAL_ONLY")
        #expect(request.stages.isEmpty)
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    private func sleep(start: Date, end: Date) -> HealthKitSleepSummary {
        let minutes = Int((end.timeIntervalSince(start) / 60).rounded())
        return HealthKitSleepSummary(
            totalMinutes: minutes,
            coreMinutes: minutes,
            deepMinutes: 0,
            remMinutes: 0,
            awakeMinutes: 0,
            inBedMinutes: minutes,
            bedStartAt: start,
            bedEndAt: end,
            stageSegments: [
                HealthKitSleepStageSegment(
                    kind: .core,
                    startAt: start,
                    endAt: end,
                    startRatio: 0,
                    durationRatio: 1,
                    durationMinutes: minutes
                )
            ],
            nightHrvMs: nil,
            weeklyHrvBaselineMs: nil
        )
    }
}
