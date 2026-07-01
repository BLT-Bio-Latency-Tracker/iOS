import Foundation

struct RefreshTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresInSeconds: Int
    let userId: Int
    let onboardingCompleted: Bool
}
