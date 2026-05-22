import Foundation

struct TodaySleepData {
    let totalSleepText: String
    let totalMinutes: Int
    let differenceText: String?
    let differenceDirection: TodaySleepDifferenceDirection?
    let stages: [TodaySleepStage]
    let coreMinutes: Int
    let deepMinutes: Int
    let remMinutes: Int
    let awakeMinutes: Int
    let inBedMinutes: Int
    let bedStartText: String
    let bedEndText: String
    let awakeCount: Int
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

enum TodaySleepStageKind: Hashable {
    case core
    case deep
    case rem
    case awake
}
