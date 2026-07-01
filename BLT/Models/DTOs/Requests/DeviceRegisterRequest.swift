import Foundation

struct DeviceRegisterRequest: Encodable {
    let fcmToken: String
    let platform: DevicePlatform

    init(fcmToken: String, platform: DevicePlatform = .ios) {
        self.fcmToken = fcmToken
        self.platform = platform
    }
}

enum DevicePlatform: String, Encodable {
    case ios = "IOS"
}
