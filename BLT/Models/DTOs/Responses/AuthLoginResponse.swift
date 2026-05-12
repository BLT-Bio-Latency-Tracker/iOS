import Foundation

struct AuthLoginResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let accessTokenExpiresIn: Int
    let refreshTokenExpiresIn: Int
    let user: AuthUserResponse
}

struct AuthUserResponse: Decodable {
    let id: Int
    let authType: AuthType
    let isNewUser: Bool
    let isGuest: Bool
    let onboardingCompleted: Bool
    let termsAgreed: Bool
}
