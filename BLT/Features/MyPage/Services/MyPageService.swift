import Foundation

struct MyPageService {
    private let networkClient: NetworkClient

    init(networkClient: NetworkClient = .shared) {
        self.networkClient = networkClient
    }

    func fetchMyPage() async throws -> MyPageState {
        let userResponse: UserResponse = try await networkClient.get(
            "/api/v1/users/me",
            requiresAuth: true
        )
        let notificationResponse = try? await fetchNotificationSettings()

        return MyPageState(
            user: userResponse,
            notificationSettings: notificationResponse
        )
    }

    func fetchUser() async throws -> MyPageState {
        let userResponse: UserResponse = try await networkClient.get(
            "/api/v1/users/me",
            requiresAuth: true
        )

        return MyPageState(
            user: userResponse,
            notificationSettings: nil
        )
    }

    private func fetchNotificationSettings() async throws -> NotificationSettingsResponse {
        try await networkClient.get(
            "/api/v1/users/me/notification-settings",
            requiresAuth: true
        )
    }

    func updateProfile(_ request: MyPageProfilePatchRequest) async throws {
        guard !request.isEmpty else { return }

        let serverRequest = ProfileUpdateRequest(
            nickname: request.name,
            birthYear: request.birthYear,
            gender: request.gender,
            occupation: request.jobGroup
        )

        let _: UserResponse = try await networkClient.patch(
            "/api/v1/users/me/profile",
            body: serverRequest,
            requiresAuth: true
        )
    }

    func updateNotificationSettings(_ request: MyPageNotificationPatchRequest) async throws {
        guard !request.isEmpty else { return }

        let serverRequest = NotificationSettingsUpdateRequest(
            notificationEnabled: request.isEnabled,
            pvtReminderTime: request.measurementTimeText.map(Self.serverTimeText),
            sleepReminderTime: request.bedtimeText.map(Self.serverTimeText),
            notificationTimezone: TimeZone.current.identifier,
            customNotificationOptions: request.channels.map { channels in
                [
                    "push": channels.contains(.appPush),
                    "sms": channels.contains(.sms)
                ]
            }
        )

        let _: NotificationSettingsResponse = try await networkClient.patch(
            "/api/v1/users/me/notification-settings",
            body: serverRequest,
            requiresAuth: true
        )
    }

    func completeOnboarding(_ draft: ProfileSetupDraft) async throws {
        let _: OnboardingResponse = try await networkClient.patch(
            "/api/v1/users/me/onboarding",
            body: OnboardingRequest(
                birthYear: draft.birthYear,
                gender: draft.gender,
                occupation: draft.jobGroup
            ),
            requiresAuth: true
        )
    }

    func withdraw() async throws {
        let _: WithdrawResponse = try await networkClient.delete(
            "/api/v1/users/me",
            requiresAuth: true
        )
        AuthSessionStore.shared.clear()
    }

    private static func serverTimeText(from displayText: String) -> String {
        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "en_US_POSIX")
        outputFormatter.dateFormat = "HH:mm:ss"

        for format in ["HH:mm:ss", "HH:mm", "hh:mm a"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format

            if let date = formatter.date(from: displayText) {
                return outputFormatter.string(from: date)
            }
        }

        return displayText
    }
}

private extension MyPageState {
    init(user: UserResponse, notificationSettings: NotificationSettingsResponse?) {
        self.init(
            user: MyPageUser(
                name: user.nickname ?? "",
                email: user.email ?? "",
                authProvider: user.authType?.displayName ?? "Apple",
                onboardingCompleted: user.onboardingCompleted
            ),
            profile: MyPageProfile(
                birthYear: user.birthYear,
                gender: user.gender,
                wakeUpTimeText: nil,
                jobGroup: user.occupation
            ),
            notificationSettings: notificationSettings.map(MyPageNotificationSettings.init(response:))
                ?? .empty
        )
    }
}

private extension MyPageNotificationSettings {
    init(response: NotificationSettingsResponse) {
        var channels: Set<MyPageNotificationChannel> = []
        if response.customNotificationOptions["push"] == true {
            channels.insert(.appPush)
        }
        if response.customNotificationOptions["sms"] == true {
            channels.insert(.sms)
        }

        self.init(
            isEnabled: response.notificationEnabled,
            measurementTimeText: Self.displayTimeText(from: response.pvtReminderTime),
            bedtimeText: Self.displayTimeText(from: response.sleepReminderTime),
            channels: channels
        )
    }

    private static func displayTimeText(from serverText: String?) -> String? {
        guard let serverText, !serverText.isEmpty else {
            return nil
        }

        let inputFormatter = DateFormatter()
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        inputFormatter.dateFormat = "HH:mm:ss"

        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "en_US_POSIX")
        outputFormatter.dateFormat = "HH:mm"

        guard let date = inputFormatter.date(from: serverText) else {
            return serverText
        }

        return outputFormatter.string(from: date)
    }
}
