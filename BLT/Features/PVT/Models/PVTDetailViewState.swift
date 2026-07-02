import Foundation

struct PVTDetailViewState {
    var isLoading: Bool
    var errorMessage: String?
    var measurements: [PVTDetailMeasurement]

    var hasMeasurements: Bool {
        !measurements.isEmpty
    }

    var measurementCount: Int {
        measurements.count
    }

    var averageMilliseconds: Int {
        roundedAverage(measurements.map(\.averageMilliseconds))
    }

    var bestMilliseconds: Int {
        measurements.map(\.averageMilliseconds).min() ?? 0
    }

    var averageLapseCount: Int {
        roundedAverage(measurements.map(\.lapseCount))
    }

    var averageFalseStartCount: Int {
        roundedAverage(measurements.map(\.falseStartCount))
    }

    static let empty = PVTDetailViewState(
        isLoading: false,
        errorMessage: nil,
        measurements: []
    )

    private func roundedAverage(_ values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        let total = values.reduce(0, +)
        return Int((Double(total) / Double(values.count)).rounded())
    }
}

struct PVTDetailMeasurement: Identifiable, Equatable {
    let id: Int
    let measurementId: UUID
    let measuredAt: Date
    let averageMilliseconds: Int
    let bestMilliseconds: Int?
    let lapseCount: Int
    let falseStartCount: Int
    let totalCount: Int
    let rawReactionTimes: [Int]

    var status: PVTDetailStatus {
        if averageMilliseconds <= 320 {
            return .good
        }

        if averageMilliseconds <= 350 {
            return .caution
        }

        return .poor
    }
}

enum PVTDetailStatus: Equatable {
    case good
    case caution
    case poor

    var title: String {
        switch self {
        case .good:
            return "안정"
        case .caution:
            return "주의"
        case .poor:
            return "하락"
        }
    }
}
