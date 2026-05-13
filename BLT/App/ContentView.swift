import SwiftUI

struct ContentView: View {
    @AppStorage(AppStorageKey.hasCompletedOnboarding)
    private var hasCompletedOnboarding = false

    @State private var route: AppRoute = .splash
    @State private var profileSetupDraft = ProfileSetupDraft()
    @StateObject private var authFlowViewModel = AuthFlowViewModel()

    private let routeAfterSplash: AppRoute

    init() {
        routeAfterSplash = UserDefaults.standard.bool(
            forKey: AppStorageKey.hasCompletedOnboarding
        ) ? .login : .onboarding
    }

    var body: some View {
        ZStack {
            switch route {
            case .splash:
                SplashView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        route = routeAfterSplash
                    }
                }
                .transition(.opacity)

            case .onboarding:
                OnboardingView(onFinish: completeOnboarding)
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
                            let isSignedIn = await authFlowViewModel.signInWithApple(
                                termsAgreement: termsAgreement
                            )

                            guard isSignedIn else { return }

                            withAnimation(.easeInOut(duration: 0.35)) {
                                route = .healthPermission
                            }
                        }
                    },
                    isProcessing: authFlowViewModel.isSigningIn,
                    errorMessage: authFlowViewModel.errorMessage
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .healthPermission:
                HealthPermissionView { _ in
                    withAnimation(.easeInOut(duration: 0.35)) {
                        route = .profileSetup
                    }
                }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))

            case .profileSetup:
                ProfileSetupView(
                    setupDraft: $profileSetupDraft,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            route = .healthPermission
                        }
                    },
                    onNext: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            route = .startReady
                        }
                    },
                    onSkip: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            route = .startReady
                        }
                    }
                )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))

            case .startReady:
                StartReadyView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            route = .profileSetup
                        }
                    }
                )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            }
        }
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true

        withAnimation(.easeInOut(duration: 0.35)) {
            route = .login
        }
    }
}

private enum AppRoute {
    case splash
    case onboarding
    case login
    case termsAgreement
    case healthPermission
    case profileSetup
    case startReady
}

private enum AppStorageKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
}
