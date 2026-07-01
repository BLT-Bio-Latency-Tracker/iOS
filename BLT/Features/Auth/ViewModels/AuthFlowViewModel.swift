import AuthenticationServices
import Combine
import Foundation

@MainActor
final class AuthFlowViewModel: ObservableObject {
    enum AppleSignInResult {
        case existingUser(onboardingCompleted: Bool)
        case newUserNeedsTerms
    }

    private struct ProfileSyncResult {
        let onboardingCompleted: Bool
        let hasRequiredIdentity: Bool
    }

    @Published var isSigningIn = false
    @Published var errorMessage: String?

    private(set) var latestTermsAgreementRequest: TermsAgreementRequest?
    private(set) var latestVerificationToken: String?

    private let appleAuthService: AppleAuthService
    private let authAPIService: AuthAPIService
    private let termsAPIService: TermsAPIService
    private let authSessionStore: AuthSessionStore
    private let myPageService: MyPageService
    private let localProfileStore: LocalProfileStore
    private var latestAppleDisplayName: String?
    private var latestAppleEmail: String?

    init() {
        self.appleAuthService = AppleAuthService()
        self.authAPIService = AuthAPIService()
        self.termsAPIService = TermsAPIService()
        self.authSessionStore = .shared
        self.myPageService = MyPageService()
        self.localProfileStore = LocalProfileStore()
    }

    init(
        appleAuthService: AppleAuthService,
        authAPIService: AuthAPIService,
        termsAPIService: TermsAPIService,
        authSessionStore: AuthSessionStore = .shared,
        myPageService: MyPageService = MyPageService(),
        localProfileStore: LocalProfileStore = LocalProfileStore()
    ) {
        self.appleAuthService = appleAuthService
        self.authAPIService = authAPIService
        self.termsAPIService = termsAPIService
        self.authSessionStore = authSessionStore
        self.myPageService = myPageService
        self.localProfileStore = localProfileStore
    }

    func authenticateWithApple() async -> AppleSignInResult? {
        isSigningIn = true
        errorMessage = nil

        defer {
            isSigningIn = false
        }

        do {
            let appleResult = try await appleAuthService.signIn()
            latestAppleDisplayName = appleResult.suggestedDisplayName
            latestAppleEmail = appleResult.email
            cacheAppleIdentityIfAvailable(
                name: appleResult.suggestedDisplayName,
                email: appleResult.email
            )

            let response = try await authAPIService.verifyApple(
                AppleVerifyRequest(identityToken: appleResult.identityToken)
            )

            if response.isNewUser {
                guard let verificationToken = response.verificationToken else {
                    errorMessage = "가입 검증 토큰을 받지 못했어요."
                    return nil
                }

                latestVerificationToken = verificationToken
                return .newUserNeedsTerms
            }

            guard let session = response.session else {
                errorMessage = "로그인 세션을 받지 못했어요."
                return nil
            }

            guard authSessionStore.save(session) else {
                errorMessage = "로그인 세션을 저장하지 못했어요. 다시 시도해주세요."
                return nil
            }
            await PushDeviceRegistrationService.shared.registerCurrentDeviceIfPossible(force: true)

            guard let profileSyncResult = await syncAuthenticatedUserProfile(
                fallbackName: appleResult.preferredDisplayName,
                fallbackEmail: appleResult.email
            ) else {
                clearAuthenticatedProfile()
                errorMessage = "사용자 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요."
                return nil
            }

            guard profileSyncResult.hasRequiredIdentity else {
                clearAuthenticatedProfile()
                errorMessage = "서버에서 사용자 이름과 이메일을 받지 못했어요. 백엔드 사용자 정보 응답을 확인해주세요."
                return nil
            }

            return .existingUser(onboardingCompleted: profileSyncResult.onboardingCompleted)
        } catch {
            guard !isAppleLoginCanceled(error) else {
                return nil
            }

            errorMessage = error.localizedDescription
            return nil
        }
    }

    func completeTermsAgreement(_ termsAgreement: TermsAgreementState) async -> Bool {
        guard termsAgreement.isRequiredAgreed else {
            errorMessage = "필수 약관에 모두 동의해주세요."
            return false
        }

        isSigningIn = true
        errorMessage = nil

        defer {
            isSigningIn = false
        }

        latestTermsAgreementRequest = termsAgreement.termsRequest

        guard let verificationToken = latestVerificationToken else {
            errorMessage = "가입 검증 토큰이 만료되었어요. Apple 로그인을 다시 진행해주세요."
            return false
        }

        do {
            let response = try await authAPIService.signupWithApple(
                AppleSignupRequest(
                    verificationToken: verificationToken,
                    consents: termsAgreement.appleSignupConsents,
                    nickname: latestAppleDisplayName
                )
            )
            guard authSessionStore.save(response.session) else {
                errorMessage = "가입 세션을 저장하지 못했어요. 다시 로그인해주세요."
                return false
            }
            await PushDeviceRegistrationService.shared.registerCurrentDeviceIfPossible(force: true)
            await syncInitialNotificationSettings(from: termsAgreement)

            guard let profileSyncResult = await syncAuthenticatedUserProfile(
                fallbackName: latestAppleDisplayName,
                fallbackEmail: latestAppleEmail
            ) else {
                clearAuthenticatedProfile()
                errorMessage = "가입 후 사용자 정보를 불러오지 못했어요."
                return false
            }

            guard profileSyncResult.hasRequiredIdentity else {
                clearAuthenticatedProfile()
                errorMessage = "사용자 이름과 이메일을 확인하지 못했어요. Apple 로그인 정보를 다시 확인해주세요."
                return false
            }

            latestVerificationToken = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func syncInitialNotificationSettings(from termsAgreement: TermsAgreementState) async {
        var channels: Set<MyPageNotificationChannel> = []

        if termsAgreement.notification {
            channels.insert(.appPush)
        }

        if termsAgreement.sms {
            channels.insert(.sms)
        }

        guard !channels.isEmpty else { return }

        try? await myPageService.updateNotificationSettings(
            MyPageNotificationPatchRequest(
                isEnabled: true,
                measurementTimeText: nil,
                bedtimeText: nil,
                channels: channels
            )
        )
    }

    private func isAppleLoginCanceled(_ error: Error) -> Bool {
        guard let authorizationError = error as? ASAuthorizationError else {
            return false
        }

        return authorizationError.code == .canceled
    }

    private func clearAuthenticatedProfile() {
        authSessionStore.clear()
        localProfileStore.clear()
    }

    private func cacheAppleIdentityIfAvailable(name: String?, email: String?) {
        let current = localProfileStore.snapshot(
            fallback: LocalProfileSnapshot(
                name: "Bryki",
                email: nil,
                authProvider: "Apple",
                birthYear: nil,
                gender: nil,
                jobGroup: nil
            )
        )
        let displayName = preferredIdentityName(
            remoteName: "",
            fallbackName: name,
            cachedName: current.name
        )
        let displayEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? email
            : current.email

        guard displayName != current.name || displayEmail != current.email else { return }

        localProfileStore.save(
            LocalProfileSnapshot(
                name: displayName,
                email: displayEmail,
                authProvider: "Apple",
                birthYear: current.birthYear,
                gender: current.gender,
                jobGroup: current.jobGroup
            )
        )
    }

    @discardableResult
    private func syncAuthenticatedUserProfile(
        fallbackName: String?,
        fallbackEmail: String?
    ) async -> ProfileSyncResult? {
        guard let remoteState = try? await myPageService.fetchUser() else {
            return nil
        }

        let fallbackName = fallbackName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackEmail = fallbackEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let remoteName = remoteState.user.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let remoteEmail = remoteState.user.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cachedProfile = localProfileStore.snapshot(
            fallback: LocalProfileSnapshot(
                name: remoteState.user.name,
                email: remoteState.user.email,
                authProvider: remoteState.user.authProvider,
                birthYear: remoteState.profile.birthYear,
                gender: remoteState.profile.gender,
                jobGroup: remoteState.profile.jobGroup
            )
        )
        let displayName: String
        let displayEmail: String?

        displayName = preferredIdentityName(
            remoteName: remoteName,
            fallbackName: fallbackName,
            cachedName: cachedProfile.name
        )

        if remoteEmail.isEmpty {
            displayEmail = fallbackEmail?.isEmpty == false ? fallbackEmail : cachedProfile.email
        } else {
            displayEmail = remoteState.user.email
        }

        let hasRequiredIdentity = !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && displayName != "Bryki"
            && displayEmail?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false

        localProfileStore.save(
            LocalProfileSnapshot(
                name: displayName,
                email: displayEmail,
                authProvider: remoteState.user.authProvider.isEmpty
                    ? cachedProfile.authProvider
                    : remoteState.user.authProvider,
                birthYear: remoteState.profile.birthYear,
                gender: remoteState.profile.gender,
                jobGroup: remoteState.profile.jobGroup
            )
        )

        return ProfileSyncResult(
            onboardingCompleted: remoteState.user.onboardingCompleted,
            hasRequiredIdentity: hasRequiredIdentity
        )
    }

    private func preferredIdentityName(
        remoteName: String,
        fallbackName: String?,
        cachedName: String
    ) -> String {
        let fallbackName = fallbackName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cachedName = cachedName.trimmingCharacters(in: .whitespacesAndNewlines)

        if !isPlaceholderName(remoteName) {
            return remoteName
        }

        if fallbackName?.isEmpty == false {
            return fallbackName!
        }

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
}
