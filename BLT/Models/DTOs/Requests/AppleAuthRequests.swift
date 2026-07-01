import Foundation

struct AppleVerifyRequest: Encodable {
    let identityToken: String
}

struct AppleSignupRequest: Encodable {
    let verificationToken: String
    let consents: [AppleSignupConsentRequest]
    let nickname: String?
}

struct AppleSignupConsentRequest: Encodable {
    let consentType: AppleConsentType
    let policyVersion: String
    let agreed: Bool
    let options: [String: Bool]?
}

enum AppleConsentType: String, Encodable {
    case termsOfService = "TERMS_OF_SERVICE"
    case privacyPolicy = "PRIVACY_POLICY"
    case healthData = "HEALTH_DATA"
    case marketing = "MARKETING"
}
