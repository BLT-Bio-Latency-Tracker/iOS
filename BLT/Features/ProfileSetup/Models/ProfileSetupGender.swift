import Foundation

enum ProfileSetupGender: String, CaseIterable, Codable, Identifiable {
    case male = "MALE"
    case female = "FEMALE"

    var id: String { rawValue }

    var serverValue: String { rawValue }

    var displayName: String {
        switch self {
        case .male:
            return "남"
        case .female:
            return "여"
        }
    }
}
