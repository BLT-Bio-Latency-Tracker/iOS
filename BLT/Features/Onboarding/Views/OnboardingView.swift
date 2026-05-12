import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            switch currentPage {
            case 0:
                OnboardingFirstPageView(
                    onNext: { currentPage = 1 },
                    onSkip: { }
                )
            case 1:
                OnboardingSecondPageView(
                    onNext: { currentPage = 2 },
                    onSkip: { }
                )
            default:
                OnboardingThirdPageView(
                    onStart: { },
                    onSkip: { }
                )
            }
        }
        .animation(.easeInOut(duration: 0.22), value: currentPage)
    }
}
