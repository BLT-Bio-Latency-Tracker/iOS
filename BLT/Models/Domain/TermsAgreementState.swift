import Foundation

struct TermsAgreementState {
    let serviceTerms: Bool
    let privacyPolicy: Bool
    let ageOver14: Bool
    let healthDataAnalytics: Bool
    let marketing: Bool
    let notification: Bool
    let sms: Bool

    var isRequiredAgreed: Bool {
        serviceTerms && privacyPolicy && ageOver14
    }

    var termsRequest: TermsAgreementRequest {
        TermsAgreementRequest(
            policyVersion: "v1.0",
            agreements: [
                .init(consentType: .service, agreed: serviceTerms),
                .init(consentType: .privacy, agreed: privacyPolicy),
                .init(consentType: .healthData, agreed: true),
                .init(consentType: .analyze, agreed: healthDataAnalytics),
                .init(consentType: .marketing, agreed: marketing),
                .init(consentType: .notification, agreed: notification),
                .init(consentType: .sms, agreed: sms)
            ]
        )
    }

    var appleSignupConsents: [AppleSignupConsentRequest] {
        [
            AppleSignupConsentRequest(
                consentType: .termsOfService,
                policyVersion: "1.0",
                agreed: serviceTerms,
                options: ["ageOver14": ageOver14]
            ),
            AppleSignupConsentRequest(
                consentType: .privacyPolicy,
                policyVersion: "1.0",
                agreed: privacyPolicy,
                options: nil
            ),
            AppleSignupConsentRequest(
                consentType: .healthData,
                policyVersion: "1.0",
                agreed: true,
                options: ["anonymousAnalytics": healthDataAnalytics]
            ),
            AppleSignupConsentRequest(
                consentType: .marketing,
                policyVersion: "1.0",
                agreed: marketing,
                options: [
                    "push": notification,
                    "sms": sms
                ]
            )
        ]
    }
}
