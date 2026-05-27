import Foundation

struct TermsAgreementRequest: Encodable {
    let policyVersion: String
    let agreements: [ConsentAgreementRequest]
}

struct ConsentAgreementRequest: Encodable {
    let consentType: ConsentType
    let agreed: Bool
}

enum ConsentType: String, Codable {
    case service = "SERVICE"
    case privacy = "PRIVACY"
    case healthData = "HEALTH_DATA"
    case marketing = "MARKETING"
    case notification = "NOTIFICATION"
    case sms = "SMS"
    case analyze = "ANALYZE"
}
