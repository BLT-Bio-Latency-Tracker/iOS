import Foundation

final class PushDeviceStore {
    private enum Key {
        static let fcmToken = "push.fcmToken"
        static let registeredDeviceId = "push.registeredDeviceId"
        static let registeredFcmToken = "push.registeredFcmToken"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var fcmToken: String? {
        get {
            userDefaults.string(forKey: Key.fcmToken)
        }
        set {
            userDefaults.set(newValue, forKey: Key.fcmToken)
        }
    }

    var registeredDeviceId: Int64? {
        get {
            guard userDefaults.object(forKey: Key.registeredDeviceId) != nil else {
                return nil
            }

            return Int64(userDefaults.integer(forKey: Key.registeredDeviceId))
        }
        set {
            if let newValue {
                userDefaults.set(Int(newValue), forKey: Key.registeredDeviceId)
            } else {
                userDefaults.removeObject(forKey: Key.registeredDeviceId)
            }
        }
    }

    var registeredFcmToken: String? {
        get {
            userDefaults.string(forKey: Key.registeredFcmToken)
        }
        set {
            userDefaults.set(newValue, forKey: Key.registeredFcmToken)
        }
    }

    func markRegistered(deviceId: Int64, fcmToken: String) {
        registeredDeviceId = deviceId
        registeredFcmToken = fcmToken
    }

    func clearRegistration() {
        registeredDeviceId = nil
        registeredFcmToken = nil
    }
}
