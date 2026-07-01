import Foundation

struct DeviceResponse: Decodable {
    let deviceId: Int64
    let platform: DevicePlatformResponse
    let lastActiveAt: Date
}

enum DevicePlatformResponse: String, Decodable {
    case ios = "IOS"
}
