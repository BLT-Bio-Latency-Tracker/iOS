import Foundation

struct ProfileSetupDraft {
    var birthYear: Int?
    var gender: ProfileSetupGender?
    var jobGroup: ProfileSetupJobGroup?

    var isComplete: Bool {
        birthYear != nil && gender != nil && jobGroup != nil
    }
}
