import Combine
import Foundation

@MainActor
final class LatestSleepEvaluationSyncService: ObservableObject {
    private enum SleepBackfillPlan {
        case none
        case submit(replacingEvaluationID: Int?)
    }

    private enum UserDefaultsKey {
        static let lastSyncedSignature = "evaluation.latestSleepSync.lastSignature"
        static let pendingDeletionEvaluationID = "evaluation.latestSleepSync.pendingDeletionEvaluationID"
    }

    private let healthKitService: HealthKitService
    private let pvtResultStore: PVTResultStore
    private let evaluationService: EvaluationService
    private let evaluationResultStore: EvaluationResultStore
    private let userDefaults: UserDefaults

    private var cancellables = Set<AnyCancellable>()
    private var syncTask: Task<Void, Never>?
    private var isStarted = false

    init(
        healthKitService: HealthKitService = HealthKitService(),
        pvtResultStore: PVTResultStore = .shared,
        evaluationService: EvaluationService = EvaluationService(),
        evaluationResultStore: EvaluationResultStore = .shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.healthKitService = healthKitService
        self.pvtResultStore = pvtResultStore
        self.evaluationService = evaluationService
        self.evaluationResultStore = evaluationResultStore
        self.userDefaults = userDefaults
    }

    func start() {
        guard !isStarted else { return }

        isStarted = true
        try? healthKitService.startObservingSleepChanges()

        NotificationCenter.default.publisher(for: HealthKitService.sleepDataDidChangeNotification)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleSync()
            }
            .store(in: &cancellables)

        scheduleSync()
    }

    func scheduleSync() {
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            await self?.resubmitLatestPVTIfSleepBecameAvailable()
        }
    }

    private func resubmitLatestPVTIfSleepBecameAvailable() async {
        guard AuthSessionStore.shared.accessToken != nil else { return }
        guard await retryPendingDeletionIfNeeded() else { return }
        guard let pvtResult = pvtResultStore.displayResult() else { return }
        guard let resolvedSleep = try? await healthKitService.fetchEvaluationSleepSummary(for: pvtResult.measuredAt),
              resolvedSleep.status == .available,
              resolvedSleep.summary != nil else {
            return
        }

        let signature = Self.syncSignature(
            pvtMeasuredAt: pvtResult.measuredAt,
            resolvedSleep: resolvedSleep
        )

        guard userDefaults.string(forKey: UserDefaultsKey.lastSyncedSignature) != signature else {
            return
        }

        let plan = await sleepBackfillPlan(
            for: pvtResult.measuredAt,
            localSleepSignature: signature
        )
        guard case .submit(let replacingEvaluationID) = plan else { return }

        do {
            let evaluation = try await evaluationService.submit(
                summary: pvtResult.summary,
                measuredAt: pvtResult.measuredAt,
                measurementId: pvtResult.measurementId,
                resolvedSleep: resolvedSleep
            )

            evaluationResultStore.apply(evaluation)
            if let replacingEvaluationID,
               replacingEvaluationID != evaluation.evaluationId {
                userDefaults.set(replacingEvaluationID, forKey: UserDefaultsKey.pendingDeletionEvaluationID)
                do {
                    try await evaluationService.deleteEvaluation(id: replacingEvaluationID)
                    userDefaults.removeObject(forKey: UserDefaultsKey.pendingDeletionEvaluationID)
                } catch {
                    // 삭제 실패 시 pendingDeletionEvaluationID가 남아 다음 동기화에서 재시도된다.
                }
            }
            userDefaults.set(signature, forKey: UserDefaultsKey.lastSyncedSignature)
        } catch {
            // 다음 HealthKit 변경 또는 앱 재진입 시 다시 시도한다.
        }
    }

    private func retryPendingDeletionIfNeeded() async -> Bool {
        let pendingDeletionID = userDefaults.integer(forKey: UserDefaultsKey.pendingDeletionEvaluationID)
        guard pendingDeletionID > 0 else { return true }

        do {
            try await evaluationService.deleteEvaluation(id: pendingDeletionID)
            userDefaults.removeObject(forKey: UserDefaultsKey.pendingDeletionEvaluationID)
            return true
        } catch {
            return false
        }
    }

    private func sleepBackfillPlan(
        for pvtMeasuredAt: Date,
        localSleepSignature: String
    ) async -> SleepBackfillPlan {
        let matchedEvaluationID: Int?
        if let cachedEvaluation = evaluationResultStore.todayEvaluation,
           Self.isSamePVTWindow(cachedEvaluation.measuredAt, pvtMeasuredAt) {
            matchedEvaluationID = cachedEvaluation.evaluationId
        } else {
            do {
                let measurementDayInterval = EvaluationService.measurementDayInterval(containing: pvtMeasuredAt)
                let summaries = try await evaluationService.fetchSummaries(
                    from: measurementDayInterval.start,
                    to: measurementDayInterval.end,
                    size: 50
                )
                matchedEvaluationID = summaries
                    .first { Self.isSamePVTWindow($0.measuredAt, pvtMeasuredAt) }?
                    .evaluationId
            } catch {
                // 서버 상태를 확인하지 못했으면 중복 제출을 피하고 다음 기회에 재시도한다.
                return .none
            }
        }

        guard let matchedEvaluationID else {
            return .submit(replacingEvaluationID: nil)
        }

        let detail: EvaluationDetailResponse
        do {
            detail = try await evaluationService.fetchDetail(id: matchedEvaluationID)
        } catch {
            return .none
        }

        guard let serverSleep = detail.sleep else {
            return .submit(replacingEvaluationID: matchedEvaluationID)
        }

        if Self.serverSleepSignature(
            pvtMeasuredAt: pvtMeasuredAt,
            sleep: serverSleep
        ) == localSleepSignature {
            userDefaults.set(localSleepSignature, forKey: UserDefaultsKey.lastSyncedSignature)
            return .none
        }

        return .submit(replacingEvaluationID: matchedEvaluationID)
    }

    private static func isSamePVTWindow(_ lhs: Date, _ rhs: Date) -> Bool {
        abs(lhs.timeIntervalSince(rhs)) < 5
    }

    private static func syncSignature(
        pvtMeasuredAt: Date,
        resolvedSleep: HealthKitResolvedSleepSummary
    ) -> String {
        guard let summary = resolvedSleep.summary else {
            return "empty"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"

        let sleepDate = formatter.string(from: resolvedSleep.date)
        let pvtTime = Int(pvtMeasuredAt.timeIntervalSince1970)
        let bedStart = Int(summary.bedStartAt.timeIntervalSince1970)
        let bedEnd = Int(summary.bedEndAt.timeIntervalSince1970)

        return [
            "\(pvtTime)",
            "\(sleepDate)",
            "\(summary.totalMinutes)",
            "\(summary.deepMinutes)",
            "\(summary.remMinutes)",
            "\(summary.coreMinutes)",
            "\(summary.awakeMinutes)",
            "\(summary.inBedMinutes)",
            "\(bedStart)",
            "\(bedEnd)"
        ].joined(separator: ":")
    }

    private static func serverSleepSignature(
        pvtMeasuredAt: Date,
        sleep: EvaluationSleepDetail
    ) -> String {
        let pvtTime = Int(pvtMeasuredAt.timeIntervalSince1970)
        let bedStart = sleep.stages.map(\.startAt).min().map { Int($0.timeIntervalSince1970) } ?? 0
        let bedEnd = sleep.stages.map(\.endAt).max().map { Int($0.timeIntervalSince1970) } ?? 0

        return [
            "\(pvtTime)",
            "\(sleep.sleepDate)",
            "\(sleep.totalMinutes)",
            "\(sleep.deepMinutes)",
            "\(sleep.remMinutes)",
            "\(sleep.coreMinutes)",
            "\(sleep.awakeMinutes)",
            "\(sleep.inBedMinutes)",
            "\(bedStart)",
            "\(bedEnd)"
        ].joined(separator: ":")
    }
}
