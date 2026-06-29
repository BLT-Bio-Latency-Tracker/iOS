import Foundation
import Combine

@MainActor
final class HomeTodoStore: ObservableObject {
    @Published private(set) var items: [HomeTodoItem] = []

    private let userDefaults: UserDefaults
    private let calendar: Calendar
    private let accountIdentifier: String
    private var workdayKey: String

    private enum Key {
        static let legacyItems = "home.todos.items"
        static let legacyWorkday = "home.todos.workdayKey"

        static func items(accountIdentifier: String) -> String {
            "home.todos.\(accountIdentifier).items"
        }

        static func workday(accountIdentifier: String) -> String {
            "home.todos.\(accountIdentifier).workdayKey"
        }
    }

    init(
        userDefaults: UserDefaults = .standard,
        accountIdentifier: String = "local",
        now: Date = Date()
    ) {
        self.userDefaults = userDefaults
        self.accountIdentifier = accountIdentifier

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        self.calendar = calendar
        self.workdayKey = Self.makeWorkdayKey(for: now, calendar: calendar)

        loadOrResetIfNeeded(now: now)
    }

    func clear() {
        items = []
        userDefaults.removeObject(forKey: Key.items(accountIdentifier: accountIdentifier))
        userDefaults.removeObject(forKey: Key.workday(accountIdentifier: accountIdentifier))
    }

    func refreshForCurrentPeriod(now: Date = Date()) {
        let currentKey = Self.makeWorkdayKey(for: now, calendar: calendar)
        guard currentKey != workdayKey else { return }

        workdayKey = currentKey
        items = []
        persist()
    }

    func add(title: String, difficulty: HomeTodoDifficulty) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        items.append(HomeTodoItem(title: String(trimmedTitle.prefix(15)), difficulty: difficulty))
        persist()
    }

    func toggleCompletion(for item: HomeTodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isCompleted.toggle()
        persist()
    }

    func delete(_ item: HomeTodoItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    private func loadOrResetIfNeeded(now: Date) {
        let currentKey = Self.makeWorkdayKey(for: now, calendar: calendar)
        let storedKey = userDefaults.string(forKey: Key.workday(accountIdentifier: accountIdentifier))
            ?? legacyString(forKey: Key.legacyWorkday)

        guard storedKey == currentKey else {
            workdayKey = currentKey
            items = []
            persist()
            return
        }

        guard let data = userDefaults.data(forKey: Key.items(accountIdentifier: accountIdentifier))
            ?? legacyData(forKey: Key.legacyItems),
              let decodedItems = try? JSONDecoder().decode([HomeTodoItem].self, from: data) else {
            items = []
            return
        }

        workdayKey = currentKey
        items = decodedItems
    }

    private func persist() {
        userDefaults.set(workdayKey, forKey: Key.workday(accountIdentifier: accountIdentifier))

        guard let data = try? JSONEncoder().encode(items) else { return }
        userDefaults.set(data, forKey: Key.items(accountIdentifier: accountIdentifier))
    }

    private static func makeWorkdayKey(for date: Date, calendar: Calendar) -> String {
        let hour = calendar.component(.hour, from: date)
        let baseDate: Date

        if hour < 6 {
            baseDate = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        } else {
            baseDate = date
        }

        let components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func legacyString(forKey key: String) -> String? {
        guard accountIdentifier == "local" else { return nil }
        return userDefaults.string(forKey: key)
    }

    private func legacyData(forKey key: String) -> Data? {
        guard accountIdentifier == "local" else { return nil }
        return userDefaults.data(forKey: key)
    }
}
