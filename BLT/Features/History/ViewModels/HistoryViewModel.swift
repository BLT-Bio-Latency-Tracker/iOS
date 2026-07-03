import Combine
import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var state: HistoryMonthState

    private var selectedMonth: Date
    private var records: [HistoryDailyRecord]
    private let calendar: Calendar
    private let service: HistoryService
    private var fetchTask: Task<Void, Never>?

    init(
        currentDate: Date = Date(),
        records: [HistoryDailyRecord] = [],
        calendar: Calendar = .current,
        service: HistoryService = HistoryService()
    ) {
        var normalizedCalendar = calendar
        normalizedCalendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? calendar.timeZone
        self.calendar = normalizedCalendar
        self.service = service
        self.records = records
        self.selectedMonth = normalizedCalendar.startOfMonth(for: currentDate)
        self.state = HistoryViewModel.makeState(
            month: selectedMonth,
            records: records,
            currentDate: currentDate,
            calendar: normalizedCalendar
        )
    }

    func moveToPreviousMonth() {
        selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        reload()
        scheduleFetchSelectedMonth()
    }

    func moveToNextMonth() {
        guard canMoveToNextMonth else { return }
        selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        reload()
        scheduleFetchSelectedMonth()
    }

    func selectMonth(year: Int, month: Int) {
        guard !isFutureMonth(year: year, month: month) else { return }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        selectedMonth = calendar.date(from: components).map { calendar.startOfMonth(for: $0) } ?? selectedMonth
        reload()
        scheduleFetchSelectedMonth()
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

    func fetchSelectedMonth() async {
        guard AuthSessionStore.shared.accessToken != nil else { return }

        let monthStart = calendar.startOfMonth(for: selectedMonth)
        await fetchMonth(monthStart)
    }

    private func scheduleFetchSelectedMonth() {
        fetchTask?.cancel()
        let requestedMonth = calendar.startOfMonth(for: selectedMonth)
        fetchTask = Task { [weak self] in
            await self?.fetchMonth(requestedMonth)
        }
    }

    private func fetchMonth(_ requestedMonth: Date) async {
        guard AuthSessionStore.shared.accessToken != nil else { return }

        let monthStart = calendar.startOfMonth(for: requestedMonth)
        guard let monthEnd = calendar.date(
            byAdding: DateComponents(month: 1, day: -1),
            to: monthStart
        ) else { return }

        do {
            let serverMonth = try await service.fetchMonth(from: monthStart, to: monthEnd)
            guard !Task.isCancelled,
                  calendar.isDate(selectedMonth, equalTo: requestedMonth, toGranularity: .month) else {
                return
            }
            records = serverMonth.records
            state = Self.makeState(
                month: requestedMonth,
                records: serverMonth.records,
                currentDate: Date(),
                calendar: calendar
            ).replacingSummary(serverMonth.summary)
        } catch {
            // 서버 연동 실패 시 기존 로컬/빈 캘린더 상태를 유지합니다.
        }
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

        let monthlyRecords = records
            .filter { calendar.isDate($0.date, equalTo: monthStart, toGranularity: .month) }
            .sorted { lhs, rhs in
                if calendar.isDate(lhs.date, inSameDayAs: rhs.date) {
                    return (lhs.measuredAt ?? lhs.date) > (rhs.measuredAt ?? rhs.date)
                }
                return lhs.date < rhs.date
            }
        var recordsByDay: [Int: HistoryDailyRecord] = [:]
        for record in monthlyRecords {
            let day = calendar.component(.day, from: record.date)
            if recordsByDay[day] == nil {
                recordsByDay[day] = record
            }
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

        let scores = recordsByDay.values.map(\.roiScore)
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
