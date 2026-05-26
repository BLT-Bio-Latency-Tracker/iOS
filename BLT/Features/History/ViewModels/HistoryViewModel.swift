import Combine
import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var state: HistoryMonthState

    private var selectedMonth: Date
    private var records: [HistoryDailyRecord]
    private let calendar: Calendar

    init(
        currentDate: Date = Date(),
        records: [HistoryDailyRecord] = [],
        calendar: Calendar = .current
    ) {
        self.calendar = calendar
        self.records = records
        self.selectedMonth = calendar.startOfMonth(for: currentDate)
        self.state = HistoryViewModel.makeState(
            month: selectedMonth,
            records: records,
            currentDate: currentDate,
            calendar: calendar
        )
    }

    func moveToPreviousMonth() {
        selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        reload()
    }

    func moveToNextMonth() {
        guard canMoveToNextMonth else { return }
        selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        reload()
    }

    func selectMonth(year: Int, month: Int) {
        guard !isFutureMonth(year: year, month: month) else { return }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        selectedMonth = calendar.date(from: components).map { calendar.startOfMonth(for: $0) } ?? selectedMonth
        reload()
    }

    func applyServerRecords(_ records: [HistoryDailyRecord]) {
        self.records = records
        state = Self.makeState(
            month: selectedMonth,
            records: records,
            currentDate: Date(),
            calendar: calendar
        )
    }

    var monthTitle: String {
        let components = calendar.dateComponents([.year, .month], from: selectedMonth)
        return String(format: "%d년 %d월", components.year ?? 0, components.month ?? 1)
    }

    var selectedYear: Int {
        calendar.component(.year, from: selectedMonth)
    }

    var selectedMonthNumber: Int {
        calendar.component(.month, from: selectedMonth)
    }

    var selectableYears: [Int] {
        let currentYear = calendar.component(.year, from: Date())
        let startYear = currentYear - 10
        return Array(startYear...currentYear)
    }

    var canMoveToNextMonth: Bool {
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        return calendar.startOfMonth(for: nextMonth) <= calendar.startOfMonth(for: Date())
    }

    func isFutureMonth(year: Int, month: Int) -> Bool {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let targetMonth = calendar.date(from: components) else { return true }
        return calendar.startOfMonth(for: targetMonth) > calendar.startOfMonth(for: Date())
    }

    private func reload() {
        state = Self.makeState(
            month: selectedMonth,
            records: records,
            currentDate: Date(),
            calendar: calendar
        )
    }

    private static func makeState(
        month: Date,
        records: [HistoryDailyRecord],
        currentDate: Date,
        calendar: Calendar
    ) -> HistoryMonthState {
        let monthStart = calendar.startOfMonth(for: month)
        let numberOfDays = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 0
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingEmptyDays = max(0, firstWeekday - 1)
        let today = calendar.startOfDay(for: currentDate)

        let monthlyRecords = records.filter { calendar.isDate($0.date, equalTo: monthStart, toGranularity: .month) }
        var recordsByDay: [Int: HistoryDailyRecord] = [:]
        for record in monthlyRecords {
            let day = calendar.component(.day, from: record.date)
            recordsByDay[day] = record
        }

        var days: [HistoryCalendarDay] = []
        for index in 0..<leadingEmptyDays {
            days.append(HistoryCalendarDay(id: "leading-\(index)", date: nil, day: nil, roiScore: nil, isToday: false))
        }

        for day in 1...numberOfDays {
            let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart
            days.append(
                HistoryCalendarDay(
                    id: "day-\(day)",
                    date: date,
                    day: day,
                    roiScore: recordsByDay[day]?.roiScore,
                    isToday: calendar.isDate(calendar.startOfDay(for: date), inSameDayAs: today)
                )
            )
        }

        while days.count < 42 {
            days.append(HistoryCalendarDay(id: "trailing-\(days.count)", date: nil, day: nil, roiScore: nil, isToday: false))
        }

        let scores = monthlyRecords.map(\.roiScore)
        let summary = HistoryMonthSummary(
            measuredDays: scores.count,
            averageROI: scores.isEmpty ? nil : Int(round(Double(scores.reduce(0, +)) / Double(scores.count))),
            bestROI: scores.max(),
            lowestROI: scores.min()
        )

        return HistoryMonthState(month: monthStart, days: days, summary: summary)
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
}
