import Foundation

struct HistoryService {
    private let networkClient: NetworkClient

    init(networkClient: NetworkClient = .shared) {
        self.networkClient = networkClient
    }

    func fetchMonth(from: Date, to: Date) async throws -> HistoryServerMonth {
        async let listResponse: EvaluationPageResponse = networkClient.get(
            "/api/v1/evaluations",
            queryItems: [
                URLQueryItem(name: "from", value: Self.dateText(from)),
                URLQueryItem(name: "to", value: Self.dateText(to)),
                URLQueryItem(name: "size", value: "31")
            ],
            requiresAuth: true
        )
        async let statsResponse: EvaluationStatsResponse = networkClient.get(
            "/api/v1/evaluations/stats",
            queryItems: [
                URLQueryItem(name: "period", value: "month"),
                URLQueryItem(name: "from", value: Self.dateText(from)),
                URLQueryItem(name: "to", value: Self.dateText(to))
            ],
            requiresAuth: true
        )

        return try await HistoryServerMonth(
            records: listResponse.items.compactMap(\.historyRecord),
            summary: statsResponse.historySummary
        )
    }

    private static func dateText(_ date: Date) -> String {
        EvaluationDateFormatter.dateText(date)
    }
}

struct HistoryServerMonth {
    let records: [HistoryDailyRecord]
    let summary: HistoryMonthSummary
}

private struct EvaluationPageResponse: Decodable {
    let items: [EvaluationSummaryResponse]
}

private struct EvaluationSummaryResponse: Decodable {
    let evaluationId: Int
    let date: String
    let measuredAt: Date?
    let finalScore: Int

    var historyRecord: HistoryDailyRecord? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: date) else { return nil }
        return HistoryDailyRecord(date: date, roiScore: finalScore, measuredAt: measuredAt)
    }
}

private struct EvaluationStatsResponse: Decodable {
    let measuredDays: Int
    let avgRoi: Int?
    let maxRoi: Int?
    let minRoi: Int?

    var historySummary: HistoryMonthSummary {
        HistoryMonthSummary(
            measuredDays: measuredDays,
            averageROI: avgRoi,
            bestROI: maxRoi,
            lowestROI: minRoi
        )
    }
}
