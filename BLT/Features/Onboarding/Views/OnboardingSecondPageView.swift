import SwiftUI

struct OnboardingSecondPageView: View {
    var body: some View {
        OnboardingFeaturePage(
            icon: "⚡",
            accentColor: Color(red: 0.961, green: 0.62, blue: 0.043),
            panelColor: Color(red: 0.18, green: 0.10, blue: 0.01),
            title: "기상 후 30초,\n반응속도 측정",
            description: "빛이 나타나면 탭!\n반응속도로 뇌 피로도를 계산해요"
        )
    }
}
