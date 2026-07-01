import Foundation

enum PushLog {
    static func debug(_ message: String) {
        #if DEBUG
        NSLog("[Push] %@", message)
        #endif
    }
}
