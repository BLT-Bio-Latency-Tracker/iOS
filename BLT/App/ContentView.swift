import SwiftUI

struct ContentView: View {
    @State private var route: AppRoute = .onboarding
    @StateObject private var authFlowViewModel = AuthFlowViewModel()

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
                TermsAgreementView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            route = .login
                        }
                    },
                    onNext: { termsAgreement in
                        Task {
                            await authFlowViewModel.signInWithApple(termsAgreement: termsAgreement)
                        }
                    },
                    isProcessing: authFlowViewModel.isSigningIn,
                    errorMessage: authFlowViewModel.errorMessage
                )
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
