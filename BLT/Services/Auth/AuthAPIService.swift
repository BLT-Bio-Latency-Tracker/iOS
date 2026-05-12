import Foundation

struct AuthAPIService {
    private let networkClient: NetworkClient

    init(networkClient: NetworkClient = .shared) {
        self.networkClient = networkClient
    }

    func login(_ request: AuthLoginRequest) async throws -> AuthLoginResponse {
        try await networkClient.post(
            "/api/v1/auth/login",
            body: request,
            requiresAuth: false
        )
    }

    func refreshToken(_ request: RefreshTokenRequest) async throws -> RefreshTokenResponse {
        try await networkClient.post(
            "/api/v1/auth/refresh",
            body: request,
            requiresAuth: false
        )
    }
}
