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

    private enum Key {
        static let name = "local.profile.name"
        static let birthYear = "local.profile.birthYear"
        static let gender = "local.profile.gender"
        static let wakeUpTimeText = "local.profile.wakeUpTimeText"
        static let jobGroup = "local.profile.jobGroup"
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func snapshot(fallback: LocalProfileSnapshot) -> LocalProfileSnapshot {
        LocalProfileSnapshot(
            name: userDefaults.string(forKey: Key.name) ?? fallback.name,
            birthYear: storedBirthYear ?? fallback.birthYear,
            gender: storedGender ?? fallback.gender,
            wakeUpTimeText: userDefaults.string(forKey: Key.wakeUpTimeText) ?? fallback.wakeUpTimeText,
            jobGroup: storedJobGroup ?? fallback.jobGroup
        )
    }

    func save(_ snapshot: LocalProfileSnapshot) {
        userDefaults.set(snapshot.name, forKey: Key.name)
        setOptional(snapshot.birthYear, forKey: Key.birthYear)
        setOptional(snapshot.gender?.rawValue, forKey: Key.gender)
        setOptional(snapshot.wakeUpTimeText, forKey: Key.wakeUpTimeText)
        setOptional(snapshot.jobGroup?.rawValue, forKey: Key.jobGroup)

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

    private var storedBirthYear: Int? {
        guard userDefaults.object(forKey: Key.birthYear) != nil else { return nil }
        return userDefaults.integer(forKey: Key.birthYear)
    }

    private var storedGender: ProfileSetupGender? {
        userDefaults.string(forKey: Key.gender).flatMap(ProfileSetupGender.init(rawValue:))
    }

    private var storedJobGroup: ProfileSetupJobGroup? {
        userDefaults.string(forKey: Key.jobGroup).flatMap(ProfileSetupJobGroup.init(rawValue:))
    }

    private func setOptional(_ value: Any?, forKey key: String) {
        if let value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }
}
