import Foundation

struct TodayPVTData {
    let averageMs: Int
    let changeText: String?
    let highlightText: String?
    let trials: [Int]
}

enum TodayPVTDataStatus {
    case available
    case noMeasurement
}
