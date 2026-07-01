import Combine
import Foundation

@MainActor
final class EvaluationResultStore: ObservableObject {
    static let shared = EvaluationResultStore()

    @Published private(set) var todayEvaluation: EvaluationResponse?

    private init() {}

    func apply(_ evaluation: EvaluationResponse) {
        todayEvaluation = evaluation
    }
}
