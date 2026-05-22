import Foundation

struct TodaySleepData {
    let totalSleepText: String
    let differenceText: String?
    let differenceDirection: TodaySleepDifferenceDirection?
    let stages: [TodaySleepStage]
}

enum TodaySleepDifferenceDirection {
    case positive
    case negative
    case neutral
}

struct TodaySleepStage: Identifiable {
    let id = UUID()
    let kind: TodaySleepStageKind
    let startRatio: Double
    let ratio: Double
}

enum TodaySleepStageKind {
    case core
    case deep
    case rem
    case awake
}
