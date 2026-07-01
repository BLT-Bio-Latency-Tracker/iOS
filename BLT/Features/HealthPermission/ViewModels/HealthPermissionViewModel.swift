import Combine
import Foundation

@MainActor
final class HealthPermissionViewModel: ObservableObject {
    @Published var isRequestingPermission = false
    @Published var errorMessage: String?
    @Published var permissionRequested = false

    private(set) var latestPermissionAgreementRequest: HealthPermissionAgreementRequest?

    private let healthKitService: HealthKitService

    init() {
        self.healthKitService = HealthKitService()
    }

    init(healthKitService: HealthKitService) {
        self.healthKitService = healthKitService
    }

    func requestHealthKitPermission() async -> Bool {
        isRequestingPermission = true
        errorMessage = nil

        defer {
            isRequestingPermission = false
        }

        do {
            _ = try await healthKitService.requestSleepAndHRVAuthorization()
            permissionRequested = true

            let request = HealthPermissionAgreementRequest(
                healthKitPermissionAgreed: true,
                sleepDataRequested: true,
                hrvDataRequested: true,
                pvtOnlyMode: false
            )
            latestPermissionAgreementRequest = request
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func skipHealthKitPermission() async {
        healthKitService.markSleepDataConnectionSkipped()

        let request = HealthPermissionAgreementRequest(
            healthKitPermissionAgreed: false,
            sleepDataRequested: false,
            hrvDataRequested: false,
            pvtOnlyMode: true
        )
        latestPermissionAgreementRequest = request
    }
}
