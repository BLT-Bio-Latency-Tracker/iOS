import Foundation

struct TermsAPIService {
    private let networkClient: NetworkClient

    init(networkClient: NetworkClient = .shared) {
        self.networkClient = networkClient
    }

    func submitTerms(_ request: TermsAgreementRequest) async throws -> TermsAgreementResponse {
        try await networkClient.post(
            "/api/v1/users/me/terms",
            body: request,
            requiresAuth: true
        )
    }
}
