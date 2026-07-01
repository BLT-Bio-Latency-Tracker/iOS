import Foundation

enum PushLog {
    static func debug(_ message: String) {
        NSLog("[Push] %@", message)
    }
}
