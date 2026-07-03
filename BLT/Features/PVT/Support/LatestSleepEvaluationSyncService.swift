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
        guard let pvtResult = pvtResultStore.displayResult() else { return }
        let plan = await sleepBackfillPlan(for: pvtResult.measuredAt)
        guard case .submit(let replacingEvaluationID) = plan else { return }
        guard let resolvedSleep = try? await healthKitService.fetchDisplaySleepSummary(for: pvtResult.measuredAt),
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

        do {
            let evaluation = try await evaluationService.submit(
                summary: pvtResult.summary,
                measuredAt: pvtResult.measuredAt,
                measurementId: pvtResult.measurementId,
                resolvedSleep: resolvedSleep
            )

            userDefaults.set(signature, forKey: UserDefaultsKey.lastSyncedSignature)
            evaluationResultStore.apply(evaluation)
            if let replacingEvaluationID,
               replacingEvaluationID != evaluation.evaluationId {
                try? await evaluationService.deleteEvaluation(id: replacingEvaluationID)
            }
        } catch {
            // 다음 HealthKit 변경 또는 앱 재진입 시 다시 시도한다.
        }
    }

    private func sleepBackfillPlan(for pvtMeasuredAt: Date) async -> SleepBackfillPlan {
        let evaluation: EvaluationResponse?
        if let cachedEvaluation = evaluationResultStore.todayEvaluation {
            evaluation = cachedEvaluation
        } else {
            evaluation = try? await evaluationService.fetchToday()
            if let evaluation {
                evaluationResultStore.apply(evaluation)
            }
        }

        guard let evaluation else {
            return .submit(replacingEvaluationID: nil)
        }

        let isSamePVTWindow = abs(evaluation.measuredAt.timeIntervalSince(pvtMeasuredAt)) < 5
        if isSamePVTWindow && evaluation.sleepScore > 0 {
            return .none
        }

        return .submit(replacingEvaluationID: isSamePVTWindow ? evaluation.evaluationId : nil)
    }

    private static func syncSignature(
        pvtMeasuredAt: Date,
        resolvedSleep: HealthKitResolvedSleepSummary
    ) -> String {
        guard let summary = resolvedSleep.summary else {
            return "empty"
        }

        let sleepDate = Int(resolvedSleep.date.timeIntervalSince1970)
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
}
