import Foundation

struct PVTDetailViewState {
    let averageMilliseconds: Int
    let bestMilliseconds: Int
    let lapseCount: Int
    let falseStartCount: Int
    let responseStability: PVTDetailStatus
    let arousalLevel: PVTDetailStatus
    let trials: [PVTDetailTrialPoint]

    static let placeholder = PVTDetailViewState(
        averageMilliseconds: 312,
        bestMilliseconds: 280,
        lapseCount: 0,
        falseStartCount: 0,
        responseStability: .good,
        arousalLevel: .good,
        trials: [
            PVTDetailTrialPoint(index: 1, milliseconds: 352),
            PVTDetailTrialPoint(index: 2, milliseconds: 320),
            PVTDetailTrialPoint(index: 3, milliseconds: 420),
            PVTDetailTrialPoint(index: 4, milliseconds: 360),
            PVTDetailTrialPoint(index: 5, milliseconds: 300),
            PVTDetailTrialPoint(index: 6, milliseconds: 450),
            PVTDetailTrialPoint(index: 7, milliseconds: 370)
        ]
    )
}

struct PVTDetailTrialPoint: Identifiable, Equatable {
    let id = UUID()
    let index: Int
    let milliseconds: Int

    var isFasterThanBaseline: Bool {
        milliseconds < 350
    }
}

enum PVTDetailStatus: Equatable {
    case good
    case caution
    case poor

    var title: String {
        switch self {
        case .good:
            return "양호"
        case .caution:
            return "주의"
        case .poor:
            return "저하"
        }
    }
}
