import Combine
import Foundation

@MainActor
final class MyPageViewModel: ObservableObject {
    @Published private(set) var state: MyPageState?
    @Published private(set) var isLoading = false
    @Published private(set) var isSavingProfile = false
    @Published private(set) var isSavingNotificationSettings = false
    @Published private(set) var errorMessage: String?

    private let service: MyPageService

    init(service: MyPageService? = nil) {
        self.service = service ?? MyPageService()
    }

    func fetchMyPage() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            state = try await service.fetchMyPage()
        } catch {
            errorMessage = "마이페이지 정보를 불러오지 못했어요."
            state = MyPageState.serverPlaceholder
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

    func applyProfile(_ draft: MyPageProfileEditDraft) {
        guard let state else { return }

        self.state = MyPageState(
            user: MyPageUser(
                name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                email: state.user.email,
                authProvider: state.user.authProvider
            ),
            profile: MyPageProfile(
                birthYear: draft.birthYear,
                gender: draft.gender,
                wakeUpTimeText: draft.wakeUpTimeText,
                jobGroup: draft.jobGroup
            ),
            notificationSettings: state.notificationSettings
        )
    }

    func applyNotificationSettings(_ settings: MyPageNotificationSettings) {
        guard let state else { return }

        self.state = MyPageState(
            user: state.user,
            profile: state.profile,
            notificationSettings: settings
        )
    }
}
