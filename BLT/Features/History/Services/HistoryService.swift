import Foundation

struct HistoryService {
    private static let detailBatchSize = 8

    private let networkClient: NetworkClient

    init(networkClient: NetworkClient = .shared) {
        self.networkClient = networkClient
    }

    func fetchMonth(from: Date, to: Date) async throws -> HistoryServerMonth {
        let queryTo = HistoryDateUtility.koreaCalendar.date(byAdding: .day, value: 3, to: to) ?? to
        let list: EvaluationPageResponse = try await networkClient.get(
            "/api/v1/evaluations",
            queryItems: [
                URLQueryItem(name: "from", value: Self.dateText(from)),
                URLQueryItem(name: "to", value: Self.dateText(queryTo)),
                URLQueryItem(name: "size", value: "1000")
            ],
            requiresAuth: true
        )

        let records = await historyRecords(from: list.items)

        return HistoryServerMonth(records: records)
    }

    private func historyRecords(from summaries: [EvaluationSummaryResponse]) async -> [HistoryDailyRecord] {
        var records: [HistoryDailyRecord] = []

        for batchStart in stride(from: 0, to: summaries.count, by: Self.detailBatchSize) {
            if Task.isCancelled { break }

            let batchEnd = min(batchStart + Self.detailBatchSize, summaries.count)
            let batch = Array(summaries[batchStart..<batchEnd])
            let batchRecords = await withTaskGroup(of: HistoryDailyRecord?.self) { group in
                for summary in batch {
                    group.addTask {
                        await historyRecord(from: summary)
                    }
                }

                var batchRecords: [HistoryDailyRecord] = []
                for await record in group {
                    if let record {
                        batchRecords.append(record)
                    }
                }
                return batchRecords
            }

            records.append(contentsOf: batchRecords)
        }

        return records
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
}

struct HistoryServerMonth {
    let records: [HistoryDailyRecord]
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
        guard let serverDate = HistoryDateUtility.parseDate(date) else { return nil }
        let historyDate = measuredAt.map {
            HistoryEvaluationDateResolver.recordDate(
                measuredAt: $0,
                sleepDateText: sleepDateText
            )
        } ?? serverDate
        return HistoryDailyRecord(date: historyDate, roiScore: finalScore, measuredAt: measuredAt)
    }
}
