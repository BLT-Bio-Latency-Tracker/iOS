import Foundation

struct NotificationSettingsResponse: Decodable {
    let notificationEnabled: Bool
    let pvtReminderTime: String?
    let sleepReminderTime: String?
    let notificationTimezone: String?
    let customNotificationOptions: [String: Bool]
}

struct NotificationSettingsUpdateRequest: Encodable {
    let notificationEnabled: Bool?
    let pvtReminderTime: String?
    let sleepReminderTime: String?
    let notificationTimezone: String?
    let customNotificationOptions: [String: Bool]?
}
