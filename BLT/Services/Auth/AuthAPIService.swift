import Foundation

struct AuthAPIService {
    private let networkClient: NetworkClient

    init(networkClient: NetworkClient = .shared) {
        self.networkClient = networkClient
    }

    func verifyApple(_ request: AppleVerifyRequest) async throws -> AppleAuthResponse {
        try await networkClient.post(
            "/api/v1/auth/apple/verify",
            body: request,
            requiresAuth: false
        )
    }

    func signupWithApple(_ request: AppleSignupRequest) async throws -> AuthSessionResponse {
        try await networkClient.post(
            "/api/v1/auth/apple/signup",
            body: request,
            requiresAuth: false
        )
    }

    func refreshToken(_ request: RefreshTokenRequest) async throws -> AuthSessionResponse {
        try await networkClient.post(
            "/api/v1/auth/refresh",
            body: request,
            requiresAuth: false
        )
    }

    func logout(_ request: RefreshTokenRequest) async throws {
        let _: EmptyResponse = try await networkClient.post(
            "/api/v1/auth/logout",
            body: request,
            requiresAuth: true
        )
    }
}
