import SwiftUI
import UIKit

enum PVTTheme {
    static let inkNavy = UIColor(hex: 0x0A0E27)
    static let brandViolet = UIColor(hex: 0x7C5CFF)
    static let dataCyan = UIColor(hex: 0x22D3EE)
    static let activeMint = UIColor(hex: 0x10B981)
    static let stimulus = UIColor(hex: 0xF59E0B)
    static let surfaceLight = UIColor(hex: 0xF5F6FA)
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    var swiftUIColor: Color {
        Color(self)
    }
}
