import Foundation

struct HealthPermissionAgreementRequest: Encodable {
    let healthKitPermissionAgreed: Bool
    let sleepDataRequested: Bool
    let hrvDataRequested: Bool
    let pvtOnlyMode: Bool
}
