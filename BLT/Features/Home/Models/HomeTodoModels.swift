import Foundation

enum HomeTodoDifficulty: String, Codable, CaseIterable, Identifiable {
    case high
    case medium
    case low

    var id: String { rawValue }

    var title: String {
        switch self {
        case .high:
            return "상"
        case .medium:
            return "중"
        case .low:
            return "하"
        }
    }

    var subtitle: String {
        switch self {
        case .high:
            return "집중력 집약 업무"
        case .medium:
            return "일반 처리 업무"
        case .low:
            return "루틴·간단 업무"
        }
    }
}

struct HomeTodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var difficulty: HomeTodoDifficulty
    var isCompleted: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        difficulty: HomeTodoDifficulty,
        isCompleted: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.difficulty = difficulty
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

enum HomeTodoFocusStrategy {
    case unmeasured
    case lowOnly
    case mediumAndLow
    case all

    init(brainROI: Int?) {
        guard let brainROI else {
            self = .unmeasured
            return
        }

        if brainROI < 40 {
            self = .lowOnly
        } else if brainROI < 70 {
            self = .mediumAndLow
        } else {
            self = .all
        }
    }

    var focusedDifficulties: Set<HomeTodoDifficulty> {
        switch self {
        case .unmeasured:
            return Set(HomeTodoDifficulty.allCases)
        case .lowOnly:
            return [.low]
        case .mediumAndLow:
            return [.medium, .low]
        case .all:
            return Set(HomeTodoDifficulty.allCases)
        }
    }

    var recommendedDefaultDifficulty: HomeTodoDifficulty {
        recommendedDifficulties[0]
    }

    var recommendedDifficulties: [HomeTodoDifficulty] {
        switch self {
        case .unmeasured:
            return [.high, .medium, .low]
        case .lowOnly:
            return [.low, .medium, .high]
        case .mediumAndLow:
            return [.medium, .low, .high]
        case .all:
            return [.high, .medium, .low]
        }
    }

    func isFocused(_ difficulty: HomeTodoDifficulty) -> Bool {
        focusedDifficulties.contains(difficulty)
    }

    func recommendationMessage(for difficulty: HomeTodoDifficulty) -> String {
        let selectedTitle = "\(difficulty.title) 난이도 선택됨"

        if case .unmeasured = self {
            return "\(selectedTitle) — ROI를 측정하면 더 정확한 난이도를 추천해드려요"
        }

        guard let rank = recommendedDifficulties.firstIndex(of: difficulty) else {
            return "\(selectedTitle) — 현재 뇌 점수에서는 비추천"
        }

        switch rank {
        case 0:
            return "\(selectedTitle) — 현재 뇌 점수에서 최우선 추천"
        case 1:
            return "\(selectedTitle) — 가능하지만 \(recommendedDefaultDifficulty.title) 먼저 추천"
        default:
            let betterOptions = recommendedDifficulties
                .prefix(rank)
                .map(\.title)
                .joined(separator: "·")
            return "\(selectedTitle) — 현재는 \(betterOptions) 순으로 추천"
        }
    }
}
