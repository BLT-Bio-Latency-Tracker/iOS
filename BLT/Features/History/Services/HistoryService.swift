import Foundation

struct HistoryService {
    private let networkClient: NetworkClient

    init(networkClient: NetworkClient = .shared) {
        self.networkClient = networkClient
    }

    func fetchMonth(from: Date, to: Date) async throws -> HistoryServerMonth {
        let queryTo = Self.koreaCalendar.date(byAdding: .day, value: 3, to: to) ?? to
        async let listResponse: EvaluationPageResponse = networkClient.get(
            "/api/v1/evaluations",
            queryItems: [
                URLQueryItem(name: "from", value: Self.dateText(from)),
                URLQueryItem(name: "to", value: Self.dateText(queryTo)),
                URLQueryItem(name: "size", value: "1000")
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

        let (list, stats) = try await (listResponse, statsResponse)
        let records = await historyRecords(from: list.items)

        return HistoryServerMonth(
            records: records,
            summary: stats.historySummary
        )
    }

    private func historyRecords(from summaries: [EvaluationSummaryResponse]) async -> [HistoryDailyRecord] {
        await withTaskGroup(of: HistoryDailyRecord?.self) { group in
            for summary in summaries {
                group.addTask {
                    await historyRecord(from: summary)
                }
            }

            var records: [HistoryDailyRecord] = []
            for await record in group {
                if let record {
                    records.append(record)
                }
            }
            return records
        }
    }

    private func historyRecord(from summary: EvaluationSummaryResponse) async -> HistoryDailyRecord? {
        do {
            let detail: EvaluationDetailResponse = try await networkClient.get(
                "/api/v1/evaluations/\(summary.evaluationId)",
                requiresAuth: true
            )
            return summary.historyRecord(sleepDateText: detail.sleep?.sleepDate)
        } catch {
            return summary.historyRecord(sleepDateText: nil)
        }
    }

    private static func dateText(_ date: Date) -> String {
        EvaluationDateFormatter.dateText(date)
    }

    private static var koreaCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
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

    func historyRecord(sleepDateText: String?) -> HistoryDailyRecord? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"

        guard let serverDate = formatter.date(from: date) else { return nil }
        let historyDate = measuredAt.map {
            HistoryEvaluationDateResolver.recordDate(
                measuredAt: $0,
                sleepDateText: sleepDateText
            )
        } ?? serverDate
        return HistoryDailyRecord(date: historyDate, roiScore: finalScore, measuredAt: measuredAt)
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
