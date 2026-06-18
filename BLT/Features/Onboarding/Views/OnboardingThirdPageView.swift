import SwiftUI

struct OnboardingThirdPageView: View {
    var body: some View {
        OnboardingFeaturePage(
            icon: "🧠",
            accentColor: Color(red: 0.063, green: 0.725, blue: 0.506),
            panelColor: Color(red: 0.01, green: 0.18, blue: 0.13),
            title: "오늘 내 뇌는\n몇 점?",
            description: "수면 + 반응속도 데이터가 합쳐져\nBrain ROI 점수가 나와요. 쌓을수록 정확해져요"
        )
    }
}
