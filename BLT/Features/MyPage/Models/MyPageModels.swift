import Foundation

struct MyPageState {
    let user: MyPageUser
    let profile: MyPageProfile
    let notificationSettings: MyPageNotificationSettings

    var isProfileComplete: Bool {
        profile.birthYear != nil
            && profile.gender != nil
            && profile.wakeUpTimeText != nil
            && profile.jobGroup != nil
    }

    var missingProfileItemCount: Int {
        [
            profile.birthYear == nil,
            profile.gender == nil,
            profile.wakeUpTimeText == nil,
            profile.jobGroup == nil
        ].filter { $0 }.count
    }
}

struct MyPageUser {
    let name: String
    let email: String
    let authProvider: String

    var profileInitial: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? "B"
    }
}

struct MyPageProfile {
    let birthYear: Int?
    let gender: ProfileSetupGender?
    let wakeUpTimeText: String?
    let jobGroup: ProfileSetupJobGroup?
}

struct MyPageNotificationSettings {
    let isEnabled: Bool
    let measurementTimeText: String?
    let bedtimeText: String?
}

struct MyPageProfilePatchRequest {
    let name: String?
    let birthYear: Int?
    let gender: ProfileSetupGender?
    let wakeUpTimeText: String?
    let jobGroup: ProfileSetupJobGroup?

    var isEmpty: Bool {
        name == nil
            && birthYear == nil
            && gender == nil
            && wakeUpTimeText == nil
            && jobGroup == nil
    }
}

extension MyPageState {
    static let serverPlaceholder = MyPageState(
        user: MyPageUser(
            name: "BLT",
            email: "blt@example.com",
            authProvider: "Apple"
        ),
        profile: MyPageProfile(
            birthYear: nil,
            gender: nil,
            wakeUpTimeText: nil,
            jobGroup: nil
        ),
        notificationSettings: MyPageNotificationSettings(
            isEnabled: false,
            measurementTimeText: nil,
            bedtimeText: nil
        )
    )
}
