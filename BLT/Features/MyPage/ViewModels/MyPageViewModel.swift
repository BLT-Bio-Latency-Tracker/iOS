import Combine
import Foundation

@MainActor
final class MyPageViewModel: ObservableObject {
    @Published private(set) var state: MyPageState?
    @Published private(set) var isLoading = false
    @Published private(set) var isSavingProfile = false
    @Published private(set) var isSavingNotificationSettings = false
    @Published private(set) var isWithdrawing = false
    @Published private(set) var isLoggingOut = false
    @Published private(set) var errorMessage: String?

    private let service: MyPageService
    private let localProfileStore: LocalProfileStore

    init(service: MyPageService? = nil, localProfileStore: LocalProfileStore? = nil) {
        self.service = service ?? MyPageService()
        self.localProfileStore = localProfileStore ?? LocalProfileStore()
    }

    func fetchMyPage() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let remoteState = try await service.fetchMyPage()
            let displayState = applyingCachedNameIfNeeded(to: remoteState)
            cacheLocalProfile(displayState)
            state = displayState
        } catch {
            errorMessage = "마이페이지 정보를 불러오지 못했어요."
        }
    }

    func updateProfile(_ request: MyPageProfilePatchRequest) async -> Bool {
        guard !isSavingProfile else { return false }
        guard !request.isEmpty else { return true }

        isSavingProfile = true
        errorMessage = nil

        defer {
            isSavingProfile = false
        }

        do {
            try await service.updateProfile(request)
            return true
        } catch {
            errorMessage = "내 정보를 저장하지 못했어요."
            return false
        }
    }

    func updateNotificationSettings(_ request: MyPageNotificationPatchRequest) async -> Bool {
        guard !isSavingNotificationSettings else { return false }
        guard !request.isEmpty else { return true }

        isSavingNotificationSettings = true
        errorMessage = nil

        defer {
            isSavingNotificationSettings = false
        }

        do {
            try await service.updateNotificationSettings(request)
            return true
        } catch {
            errorMessage = "알림 설정을 저장하지 못했어요."
            return false
        }
    }

    func withdraw() async -> Bool {
        guard !isWithdrawing else { return false }

        isWithdrawing = true
        errorMessage = nil

        defer {
            isWithdrawing = false
        }

        do {
            try await service.withdraw()
            localProfileStore.clear()
            return true
        } catch {
            errorMessage = "회원 탈퇴를 처리하지 못했어요."
            return false
        }
    }

    func logout() async -> Bool {
        guard !isLoggingOut else { return false }

        isLoggingOut = true
        errorMessage = nil

        defer {
            isLoggingOut = false
        }

        do {
            try await service.logout()
            localProfileStore.clear()
            return true
        } catch {
            AuthSessionStore.shared.clear()
            localProfileStore.clear()
            return true
        }
    }

    func applyProfile(_ profile: MyPageProfileEditValue) {
        guard let state else { return }

        let updatedState = MyPageState(
            user: MyPageUser(
                name: profile.name,
                email: state.user.email,
                authProvider: state.user.authProvider,
                onboardingCompleted: state.user.onboardingCompleted
            ),
            profile: MyPageProfile(
                birthYear: profile.birthYear,
                gender: profile.gender,
                jobGroup: profile.jobGroup
            ),
            notificationSettings: state.notificationSettings
        )

        localProfileStore.save(
            LocalProfileSnapshot(
                name: updatedState.user.name,
                email: updatedState.user.email,
                authProvider: updatedState.user.authProvider,
                birthYear: updatedState.profile.birthYear,
                gender: updatedState.profile.gender,
                jobGroup: updatedState.profile.jobGroup
            )
        )

        self.state = updatedState
    }

    func applyNotificationSettings(_ settings: MyPageNotificationSettings) {
        guard let state else { return }

        self.state = MyPageState(
            user: state.user,
            profile: state.profile,
            notificationSettings: settings
        )
    }

    private func cacheLocalProfile(_ state: MyPageState) {
        localProfileStore.save(
            LocalProfileSnapshot(
                name: state.user.name,
                email: state.user.email,
                authProvider: state.user.authProvider,
                birthYear: state.profile.birthYear,
                gender: state.profile.gender,
                jobGroup: state.profile.jobGroup
            )
        )
    }

    private func applyingCachedNameIfNeeded(to state: MyPageState) -> MyPageState {
        let cachedProfile = localProfileStore.snapshot(
            fallback: LocalProfileSnapshot(
                name: state.user.name,
                email: state.user.email,
                authProvider: state.user.authProvider,
                birthYear: state.profile.birthYear,
                gender: state.profile.gender,
                jobGroup: state.profile.jobGroup
            )
        )
        let serverName = MyPageStringNormalizer.trimmed(state.user.name)
        let serverEmail = MyPageStringNormalizer.trimmed(state.user.email)

        let displayName = isPlaceholderName(serverName)
            ? cachedProfile.name
            : state.user.name
        let displayEmail = serverEmail.isEmpty
            ? (cachedProfile.email ?? state.user.email)
            : state.user.email

        return MyPageState(
            user: MyPageUser(
                name: displayName,
                email: displayEmail,
                authProvider: cachedProfile.authProvider ?? state.user.authProvider,
                onboardingCompleted: state.user.onboardingCompleted
            ),
            profile: MyPageProfile(
                birthYear: state.profile.birthYear ?? cachedProfile.birthYear,
                gender: state.profile.gender ?? cachedProfile.gender,
                jobGroup: state.profile.jobGroup ?? cachedProfile.jobGroup
            ),
            notificationSettings: state.notificationSettings
        )
    }

    private func isPlaceholderName(_ name: String) -> Bool {
        let trimmedName = MyPageStringNormalizer.trimmed(name)
        let lowercasedName = trimmedName.lowercased()

        return trimmedName.isEmpty
            || trimmedName == "Bryki"
            || trimmedName == "Apple"
            || lowercasedName.hasPrefix("user")
            || trimmedName.hasPrefix("사용자")
            || trimmedName.hasPrefix("게스트")
    }

}
