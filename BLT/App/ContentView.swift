import SwiftUI

struct ContentView: View {
    @State private var route: AppRoute = .onboarding

    var body: some View {
        ZStack {
            switch route {
            case .onboarding:
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        route = .login
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal: .move(edge: .leading)
                ))

            case .login:
                LoginView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        route = .termsAgreement
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .termsAgreement:
                TermsAgreementView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        route = .login
                    }
                } onNext: {
                    // TODO: 다음 단계가 확정되면 HealthPermission 또는 Auth flow로 연결합니다.
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            }
        }
    }
}

private enum AppRoute {
    case onboarding
    case login
    case termsAgreement
}
