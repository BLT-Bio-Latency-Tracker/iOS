import SwiftUI

extension View {
    func brykiTextStyle(size: CGFloat, weight: SwiftUI.Font.Weight) -> some View {
        environment(\.font, SwiftUI.Font.system(size: size, weight: weight))
    }
}
