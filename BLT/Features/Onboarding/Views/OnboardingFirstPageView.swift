import SwiftUI

struct OnboardingFirstPageView: View {
    var body: some View {
        OnboardingFeaturePage(
            icon: "🛏️",
            accentColor: Color(red: 0.486, green: 0.361, blue: 1),
            panelColor: Color(red: 0.075, green: 0.061, blue: 0.178),
            title: "자기 전,\n버튼 하나만",
            description: "잠들기 전 수면 시작 → 기상 후 종료\n그게 전부예요"
        )
    }
}
