import Foundation

struct AuthSessionResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresInSeconds: Int64
    let userId: Int64
    let onboardingCompleted: Bool

    var session: AuthSession {
        AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
            expiresInSeconds: expiresInSeconds,
            userId: userId,
            onboardingCompleted: onboardingCompleted
        )
    }
}

struct AppleAuthResponse: Decodable {
    let isNewUser: Bool
    let accessToken: String?
    let refreshToken: String?
    let verificationToken: String?
    let tokenType: String?
    let expiresInSeconds: Int64?
    let verificationExpiresInSeconds: Int64?
    let userId: Int64?
    let onboardingCompleted: Bool?

    var session: AuthSession? {
        guard let accessToken,
              let refreshToken,
              let tokenType,
              let expiresInSeconds else {
            return nil
        }

        return AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
            expiresInSeconds: expiresInSeconds,
            userId: userId,
            onboardingCompleted: onboardingCompleted ?? false
        )
    }
}
