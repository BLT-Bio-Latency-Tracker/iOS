import Combine
import Foundation

@MainActor
final class HealthPermissionViewModel: ObservableObject {
    @Published var isRequestingPermission = false
    @Published var errorMessage: String?
    @Published var permissionRequested = false

    private(set) var latestPermissionAgreementRequest: HealthPermissionAgreementRequest?

    private let healthKitService: HealthKitService
    private let healthPermissionAPIService: HealthPermissionAPIService

    init() {
        self.healthKitService = HealthKitService()
        self.healthPermissionAPIService = HealthPermissionAPIService()
    }

    init(
        healthKitService: HealthKitService,
        healthPermissionAPIService: HealthPermissionAPIService
    ) {
        self.healthKitService = healthKitService
        self.healthPermissionAPIService = healthPermissionAPIService
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
            try await submitIfNeeded(request)
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

        do {
            try await submitIfNeeded(request)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitIfNeeded(_ request: HealthPermissionAgreementRequest) async throws {
        // OpenAPI 기준으로 HealthKit 권한 동의 저장 엔드포인트가 아직 없습니다.
        // 서버 API가 추가되기 전까지는 로컬 플로우만 유지합니다.
        _ = request
    }
}
