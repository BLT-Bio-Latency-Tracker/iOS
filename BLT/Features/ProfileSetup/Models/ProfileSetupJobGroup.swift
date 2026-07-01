import Foundation

enum ProfileSetupJobGroup: String, CaseIterable, Codable, Identifiable {
    case knowledge = "KNOWLEDGE_WORKER"
    case field = "FIELD_WORKER"
    case student = "STUDENT"
    case other = "OTHER"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .knowledge:
            return "지식 노동"
        case .field:
            return "현장 노동"
        case .student:
            return "학생"
        case .other:
            return "기타"
        }
    }
}
