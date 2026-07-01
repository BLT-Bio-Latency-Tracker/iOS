import Foundation

struct ProfileUpdateRequest: Encodable {
    let nickname: String?
    let birthYear: Int?
    let gender: ProfileSetupGender?
    let occupation: ProfileSetupJobGroup?
}

struct OnboardingRequest: Encodable {
    let birthYear: Int?
    let gender: ProfileSetupGender?
    let occupation: ProfileSetupJobGroup?
}

struct OnboardingResponse: Decodable {
    let userId: Int64
    let birthYear: Int?
    let gender: ProfileSetupGender?
    let occupation: ProfileSetupJobGroup?
    let onboardingCompleted: Bool
}
