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

                    withAnimation(.easeInOut(duration: 0.35)) {

                        route = .main

                    }

                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .main:
                Text("Main")
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
    case main
}
