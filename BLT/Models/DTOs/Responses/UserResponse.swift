import Foundation

struct UserResponse: Decodable {
    let userId: Int64
    let nickname: String?
    let email: String?
    let authType: AuthProvider?
    let status: UserStatus
    let birthYear: Int?
    let gender: ProfileSetupGender?
    let occupation: ProfileSetupJobGroup?
    let onboardingCompleted: Bool
}

enum AuthProvider: String, Decodable {
    case apple = "APPLE"
    case guest = "GUEST"

    var displayName: String {
        switch self {
        case .apple:
            return "Apple"
        case .guest:
            return "Guest"
        }
    }
}

enum UserStatus: String, Decodable {
    case active = "ACTIVE"
    case withdrawPending = "WITHDRAW_PENDING"
    case withdrawn = "WITHDRAWN"
}

struct WithdrawResponse: Decodable {
    let status: String
    let withdrawnAt: Date
    let withdrawScheduledAt: Date
}
