import Foundation

struct TermsAgreementResponse: Decodable {
    let termsAgreed: Bool
    let agreedAt: String
    let policyVersion: String
    let agreements: [ConsentAgreementResponse]
}

struct ConsentAgreementResponse: Decodable {
    let consentType: ConsentType
    let agreed: Bool
    let agreedAt: String
}
