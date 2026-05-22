import Foundation

enum ProfileSetupJobGroup: String, CaseIterable, Identifiable {
    case knowledge = "지식 노동"
    case field = "현장 노동"
    case student = "학생"
    case other = "기타"

    var id: String { rawValue }
}

