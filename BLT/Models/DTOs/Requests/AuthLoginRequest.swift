import Foundation

struct AuthLoginRequest: Encodable {
    let authType: AuthType
    let identifier: String
    let nonce: String?
}

enum AuthType: String, Codable {
    case apple = "APPLE"
    case guest = "GUEST"
}
