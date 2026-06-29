import Foundation

struct LocalProfileSnapshot {
    let name: String
    let birthYear: Int?
    let gender: ProfileSetupGender?
    let wakeUpTimeText: String?
    let jobGroup: ProfileSetupJobGroup?

    var profileInitial: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? "B"
    }
}

struct LocalProfileStore {
    static let didChangeNotification = Notification.Name("LocalProfileStore.didChangeNotification")

    private let userDefaults: UserDefaults
    private let accountIdentifier: String

    private enum Key {
        static let legacyName = "local.profile.name"
        static let legacyBirthYear = "local.profile.birthYear"
        static let legacyGender = "local.profile.gender"
        static let legacyWakeUpTimeText = "local.profile.wakeUpTimeText"
        static let legacyJobGroup = "local.profile.jobGroup"

        static func name(accountIdentifier: String) -> String {
            "local.profile.\(accountIdentifier).name"
        }

        static func birthYear(accountIdentifier: String) -> String {
            "local.profile.\(accountIdentifier).birthYear"
        }

        static func gender(accountIdentifier: String) -> String {
            "local.profile.\(accountIdentifier).gender"
        }

        static func wakeUpTimeText(accountIdentifier: String) -> String {
            "local.profile.\(accountIdentifier).wakeUpTimeText"
        }

        static func jobGroup(accountIdentifier: String) -> String {
            "local.profile.\(accountIdentifier).jobGroup"
        }
    }

    init(userDefaults: UserDefaults = .standard, accountIdentifier: String = "local") {
        self.userDefaults = userDefaults
        self.accountIdentifier = accountIdentifier
    }

    func snapshot(fallback: LocalProfileSnapshot) -> LocalProfileSnapshot {
        LocalProfileSnapshot(
            name: storedName ?? fallback.name,
            birthYear: storedBirthYear ?? fallback.birthYear,
            gender: storedGender ?? fallback.gender,
            wakeUpTimeText: storedWakeUpTimeText ?? fallback.wakeUpTimeText,
            jobGroup: storedJobGroup ?? fallback.jobGroup
        )
    }

    func save(_ snapshot: LocalProfileSnapshot) {
        userDefaults.set(snapshot.name, forKey: Key.name(accountIdentifier: accountIdentifier))
        setOptional(snapshot.birthYear, forKey: Key.birthYear(accountIdentifier: accountIdentifier))
        setOptional(snapshot.gender?.rawValue, forKey: Key.gender(accountIdentifier: accountIdentifier))
        setOptional(snapshot.wakeUpTimeText, forKey: Key.wakeUpTimeText(accountIdentifier: accountIdentifier))
        setOptional(snapshot.jobGroup?.rawValue, forKey: Key.jobGroup(accountIdentifier: accountIdentifier))

        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    func clear() {
        userDefaults.removeObject(forKey: Key.name(accountIdentifier: accountIdentifier))
        userDefaults.removeObject(forKey: Key.birthYear(accountIdentifier: accountIdentifier))
        userDefaults.removeObject(forKey: Key.gender(accountIdentifier: accountIdentifier))
        userDefaults.removeObject(forKey: Key.wakeUpTimeText(accountIdentifier: accountIdentifier))
        userDefaults.removeObject(forKey: Key.jobGroup(accountIdentifier: accountIdentifier))

        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    func apply(_ request: MyPageProfilePatchRequest, to state: MyPageState) -> LocalProfileSnapshot {
        let fallback = LocalProfileSnapshot(
            name: state.user.name,
            birthYear: state.profile.birthYear,
            gender: state.profile.gender,
            wakeUpTimeText: state.profile.wakeUpTimeText,
            jobGroup: state.profile.jobGroup
        )
        let current = snapshot(fallback: fallback)

        let updated = LocalProfileSnapshot(
            name: request.name ?? current.name,
            birthYear: request.birthYear ?? current.birthYear,
            gender: request.gender ?? current.gender,
            wakeUpTimeText: request.wakeUpTimeText ?? current.wakeUpTimeText,
            jobGroup: request.jobGroup ?? current.jobGroup
        )

        save(updated)
        return updated
    }

    private var storedName: String? {
        userDefaults.string(forKey: Key.name(accountIdentifier: accountIdentifier))
            ?? legacyString(forKey: Key.legacyName)
    }

    private var storedBirthYear: Int? {
        let key = Key.birthYear(accountIdentifier: accountIdentifier)

        if userDefaults.object(forKey: key) != nil {
            return userDefaults.integer(forKey: key)
        }

        return legacyInteger(forKey: Key.legacyBirthYear)
    }

    private var storedGender: ProfileSetupGender? {
        (
            userDefaults.string(forKey: Key.gender(accountIdentifier: accountIdentifier))
                ?? legacyString(forKey: Key.legacyGender)
        ).flatMap(ProfileSetupGender.init(rawValue:))
    }

    private var storedWakeUpTimeText: String? {
        userDefaults.string(forKey: Key.wakeUpTimeText(accountIdentifier: accountIdentifier))
            ?? legacyString(forKey: Key.legacyWakeUpTimeText)
    }

    private var storedJobGroup: ProfileSetupJobGroup? {
        (
            userDefaults.string(forKey: Key.jobGroup(accountIdentifier: accountIdentifier))
                ?? legacyString(forKey: Key.legacyJobGroup)
        ).flatMap(ProfileSetupJobGroup.init(rawValue:))
    }

    private func legacyString(forKey key: String) -> String? {
        guard accountIdentifier == "local" else { return nil }
        return userDefaults.string(forKey: key)
    }

    private func legacyInteger(forKey key: String) -> Int? {
        guard accountIdentifier == "local",
              userDefaults.object(forKey: key) != nil else { return nil }
        return userDefaults.integer(forKey: key)
    }

    private func setOptional(_ value: Any?, forKey key: String) {
        if let value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }
}
