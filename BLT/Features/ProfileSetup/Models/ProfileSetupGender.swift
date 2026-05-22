import Foundation

enum ProfileSetupGender: String, CaseIterable, Identifiable {
    case male = "남"
    case female = "여"
    case other = "기타"
    case preferNotToSay = "응답 안함"

    var id: String { rawValue }
}

