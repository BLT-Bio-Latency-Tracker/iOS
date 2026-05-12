import Foundation

struct RefreshTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let accessTokenExpiresIn: Int
    let refreshTokenExpiresIn: Int
}
