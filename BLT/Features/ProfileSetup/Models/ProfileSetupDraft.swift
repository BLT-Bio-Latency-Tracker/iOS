import Foundation

struct ProfileSetupDraft {
    var birthYear: Int?
    var gender: ProfileSetupGender?
    var wakeUpTime: Date?
    var jobGroup: ProfileSetupJobGroup?

    var isComplete: Bool {
        birthYear != nil && gender != nil && wakeUpTime != nil && jobGroup != nil
    }
}

