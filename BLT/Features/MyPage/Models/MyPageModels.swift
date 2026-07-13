import Foundation

struct MyPageState {
    let user: MyPageUser
    let profile: MyPageProfile
    let notificationSettings: MyPageNotificationSettings

    var isProfileComplete: Bool {
        profile.birthYear != nil
            && profile.gender != nil
            && profile.jobGroup != nil
    }

    var missingProfileItemCount: Int {
        [
            profile.birthYear == nil,
            profile.gender == nil,
            profile.jobGroup == nil
        ].filter { $0 }.count
    }
}

struct MyPageUser {
    let name: String
    let email: String
    let authProvider: String
    let onboardingCompleted: Bool

    var profileInitial: String {
        MyPageStringNormalizer.trimmed(name).first.map(String.init) ?? "B"
    }
}

struct MyPageProfile {
    let birthYear: Int?
    let gender: ProfileSetupGender?
    let jobGroup: ProfileSetupJobGroup?
}

struct MyPageNotificationSettings {
    let isEnabled: Bool
    let measurementTimeText: String?
    let bedtimeText: String?
    let channels: Set<MyPageNotificationChannel>
}

enum MyPageNotificationChannel: String, CaseIterable, Identifiable {
    case appPush = "APP_PUSH"
    case sms = "SMS"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appPush:
            return "앱 푸시"
        case .sms:
            return "SMS"
        }
    }

    var icon: String {
        switch self {
        case .appPush:
            return "🔔"
        case .sms:
            return "✉️"
        }
    }
}

struct MyPageProfilePatchRequest {
    let name: String?
    let birthYear: Int?
    let gender: ProfileSetupGender?
    let jobGroup: ProfileSetupJobGroup?

    var isEmpty: Bool {
        name == nil
            && birthYear == nil
            && gender == nil
            && jobGroup == nil
    }
}

struct MyPageNotificationPatchRequest {
    let isEnabled: Bool?
    let measurementTimeText: String?
    let bedtimeText: String?
    let channels: Set<MyPageNotificationChannel>?

    var isEmpty: Bool {
        isEnabled == nil
            && measurementTimeText == nil
            && bedtimeText == nil
            && channels == nil
    }
}

enum MyPageStringNormalizer {
    static func trimmed(_ value: String) -> String {
        guard let firstIndex = value.firstIndex(where: { !isTrimTarget($0) }) else {
            return ""
        }
        let lastIndex = value[firstIndex...].lastIndex(where: { !isTrimTarget($0) }) ?? firstIndex
        return String(value[firstIndex...lastIndex])
    }

    private static func isTrimTarget(_ character: Character) -> Bool {
        character == " "
            || character == "\n"
            || character == "\r"
            || character == "\t"
    }
}

extension MyPageNotificationSettings {
    static let empty = MyPageNotificationSettings(
        isEnabled: false,
        measurementTimeText: nil,
        bedtimeText: nil,
        channels: []
    )
}
