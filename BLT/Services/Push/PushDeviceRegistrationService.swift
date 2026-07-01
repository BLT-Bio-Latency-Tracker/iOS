import Foundation

actor PushDeviceRegistrationService {
    static let shared = PushDeviceRegistrationService()

    private let apiService: DeviceAPIService
    private let store: PushDeviceStore
    private var isRegistering = false

    init(
        apiService: DeviceAPIService = DeviceAPIService(),
        store: PushDeviceStore = PushDeviceStore()
    ) {
        self.apiService = apiService
        self.store = store
    }

    func updateFCMToken(_ token: String) async {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { return }

        PushLog.debug("FCM token received: \(Self.maskedToken(trimmedToken))")
        store.fcmToken = trimmedToken
        await registerCurrentDeviceIfPossible()
    }

    func registerCurrentDeviceIfPossible(force: Bool = false) async {
        guard !isRegistering else { return }

        guard AuthSessionStore.shared.currentSession != nil else {
            PushLog.debug("Skip device registration: missing auth session")
            return
        }

        guard let token = store.fcmToken,
              !token.isEmpty else {
            PushLog.debug("Skip device registration: missing FCM token")
            return
        }

        if !force,
           store.registeredDeviceId != nil,
           store.registeredFcmToken == token {
            PushLog.debug("Skip device registration: already registered")
            return
        }

        isRegistering = true
        defer {
            isRegistering = false
        }

        do {
            PushLog.debug("Register device request: \(Self.maskedToken(token)), force=\(force)")
            let response = try await apiService.register(
                DeviceRegisterRequest(fcmToken: token)
            )
            store.markRegistered(
                deviceId: response.deviceId,
                fcmToken: token
            )
            PushLog.debug("Register device succeeded: deviceId=\(response.deviceId)")
        } catch {
            PushLog.debug("Register device failed: \(error.localizedDescription)")
            store.clearRegistration()
        }
    }

    func unregisterCurrentDeviceIfPossible() async {
        guard let deviceId = store.registeredDeviceId else {
            store.clearRegistration()
            return
        }

        do {
            try await apiService.unregister(deviceId: deviceId)
        } catch {
            // 로그아웃/탈퇴 흐름은 막지 않는다. 다음 로그인 때 재등록되도록 로컬 등록 상태만 비운다.
        }

        store.clearRegistration()
    }

    private static func maskedToken(_ token: String) -> String {
        guard token.count > 12 else { return "***" }
        return "\(token.prefix(6))...\(token.suffix(6))"
    }
}
