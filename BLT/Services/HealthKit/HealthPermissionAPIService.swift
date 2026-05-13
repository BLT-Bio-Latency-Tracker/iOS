import Foundation

struct HealthPermissionAPIService {
    private let networkClient: NetworkClient

    init(networkClient: NetworkClient = .shared) {
        self.networkClient = networkClient
    }

    func submitHealthPermissionAgreement(
        _ request: HealthPermissionAgreementRequest
    ) async throws -> HealthPermissionAgreementResponse {
        try await networkClient.post(
            "/api/v1/users/me/health-permission",
            body: request,
            requiresAuth: true
        )
    }
}
