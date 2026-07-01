import SwiftUI

struct ContentView: View {
    @AppStorage(AppStorageKey.hasCompletedOnboarding)
    private var hasCompletedOnboarding = false

    @State private var route: AppRoute = .splash
    @State private var profileSetupDraft = ProfileSetupDraft()
    @StateObject private var authFlowViewModel = AuthFlowViewModel()

    private let profileService = MyPageService()
    private let localProfileStore = LocalProfileStore()

    var body: some View {
        ZStack {
            switch route {
            case .splash:
                SplashView {
                    Task {
                        let restoredRoute = await initialRouteAfterSplash()

                        withAnimation(.easeInOut(duration: 0.35)) {
                            route = restoredRoute
                        }
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
                LoginView(
                    onAppleButtonTapped: {
                        Task {
                        let result = await authFlowViewModel.authenticateWithApple()

                        guard let result else { return }
                        await PushDeviceRegistrationService.shared.registerCurrentDeviceIfPossible(force: true)

                        withAnimation(.easeInOut(duration: 0.35)) {
                            switch result {
                                case .existingUser(let onboardingCompleted):
                                    hasCompletedOnboarding = true
                                    route = onboardingCompleted ? .home : .healthPermission
                                case .newUserNeedsTerms:
                                    route = .termsAgreement
                                }
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

            case .termsAgreement:
                TermsAgreementView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            route = .login
                        }
                    },
                    onNext: { termsAgreement in
                        Task {
                            let isCompleted = await authFlowViewModel.completeTermsAgreement(
                                termsAgreement
                            )

                            guard isCompleted else { return }
                            await PushDeviceRegistrationService.shared.registerCurrentDeviceIfPossible(force: true)

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
                        Task {
                            await completeProfileSetup(profileSetupDraft)
                        }
                    },
                    onSkip: {
                        Task {
                            await completeProfileSetup(ProfileSetupDraft())
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
                    },
                    onStart: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            route = .home
                        }
                    }
                )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))

            case .home:
                MainTabView(
                    onWithdraw: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            route = .login
                        }
                    },
                    onLogout: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            route = .login
                        }
                    }
                )
                    .transition(.opacity)
            }
        }
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true

        withAnimation(.easeInOut(duration: 0.35)) {
            route = .login
        }
    }

    private func completeProfileSetup(_ draft: ProfileSetupDraft) async {
        let cachedProfile = currentCachedProfileSnapshot()

        do {
            try await profileService.completeOnboarding(draft)
        } catch {
            authFlowViewModel.errorMessage = "프로필 저장에 실패했어요. 잠시 후 다시 시도해주세요."
            return
        }

        await syncAuthenticatedUserProfile(
            fallback: LocalProfileSnapshot(
                name: cachedProfile.name,
                email: cachedProfile.email,
                authProvider: cachedProfile.authProvider,
                birthYear: draft.birthYear,
                gender: draft.gender,
                jobGroup: draft.jobGroup
            )
        )
        hasCompletedOnboarding = true
        AuthSessionStore.shared.updateOnboardingCompleted(true)

        withAnimation(.easeInOut(duration: 0.35)) {
            route = .startReady
        }
    }

    private func initialRouteAfterSplash() async -> AppRoute {
        guard let session = AuthSessionStore.shared.currentSession else {
            return hasCompletedOnboarding ? .login : .onboarding
        }

        hasCompletedOnboarding = true
        let remoteOnboardingCompleted = await syncAuthenticatedUserProfile(
            fallback: LocalProfileSnapshot(
                name: currentCachedProfileSnapshot().name,
                email: currentCachedProfileSnapshot().email,
                authProvider: currentCachedProfileSnapshot().authProvider,
                birthYear: nil,
                gender: nil,
                jobGroup: nil
            )
        )
        guard AuthSessionStore.shared.currentSession != nil else {
            return .login
        }

        let onboardingCompleted = remoteOnboardingCompleted ?? session.onboardingCompleted
        AuthSessionStore.shared.updateOnboardingCompleted(onboardingCompleted)
        await PushDeviceRegistrationService.shared.registerCurrentDeviceIfPossible(force: true)

        return onboardingCompleted ? .home : .healthPermission
    }

    @discardableResult
    private func syncAuthenticatedUserProfile(fallback: LocalProfileSnapshot) async -> Bool? {
        guard let remoteState = try? await profileService.fetchUser() else {
            localProfileStore.save(fallback)
            return nil
        }

        let remoteName = remoteState.user.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let remoteEmail = remoteState.user.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = fallback.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = preferredIdentityName(
            remoteName: remoteName,
            fallbackName: fallbackName,
            cachedName: fallback.name
        )
        let displayEmail = remoteEmail.isEmpty ? fallback.email : remoteState.user.email

        localProfileStore.save(
            LocalProfileSnapshot(
                name: displayName,
                email: displayEmail,
                authProvider: remoteState.user.authProvider.isEmpty ? fallback.authProvider : remoteState.user.authProvider,
                birthYear: remoteState.profile.birthYear ?? fallback.birthYear,
                gender: remoteState.profile.gender ?? fallback.gender,
                jobGroup: remoteState.profile.jobGroup ?? fallback.jobGroup
            )
        )

        return remoteState.user.onboardingCompleted
    }

    private func preferredIdentityName(
        remoteName: String,
        fallbackName: String,
        cachedName: String
    ) -> String {
        if !isPlaceholderName(remoteName) {
            return remoteName
        }

        if !fallbackName.isEmpty {
            return fallbackName
        }

        let cachedName = cachedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isPlaceholderName(cachedName) {
            return cachedName
        }

        return remoteName.isEmpty ? "Bryki" : remoteName
    }

    private func isPlaceholderName(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedName = trimmedName.lowercased()

        return trimmedName.isEmpty
            || trimmedName == "Bryki"
            || trimmedName == "Apple"
            || lowercasedName.hasPrefix("user")
            || trimmedName.hasPrefix("사용자")
            || trimmedName.hasPrefix("게스트")
    }

    private func currentCachedProfileSnapshot() -> LocalProfileSnapshot {
        localProfileStore.snapshot(
            fallback: LocalProfileSnapshot(
                name: "Bryki",
                email: nil,
                authProvider: nil,
                birthYear: nil,
                gender: nil,
                jobGroup: nil
            )
        )
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
    case home
}

private enum AppStorageKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
}
