import SwiftUI

struct OnboardingFourthPageView: View {
    var body: some View {
        OnboardingFeaturePage(
            icon: "📋",
            accentColor: Color(red: 0.486, green: 0.361, blue: 1),
            panelColor: Color(red: 0.075, green: 0.061, blue: 0.178),
            title: "뇌 상태에 맞는\n오늘의 할 일",
            description: "뇌 점수에 따라 오늘 해야 할 일을\n최적 순서로 배치해드려요"
        )
    }
}
