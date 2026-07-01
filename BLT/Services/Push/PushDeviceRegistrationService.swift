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

        store.fcmToken = trimmedToken
        await registerCurrentDeviceIfPossible()
    }

    func registerCurrentDeviceIfPossible() async {
        guard !isRegistering else { return }
        guard AuthSessionStore.shared.currentSession != nil,
              let token = store.fcmToken,
              !token.isEmpty else {
            return
        }

        if store.registeredDeviceId != nil,
           store.registeredFcmToken == token {
            return
        }

        isRegistering = true
        defer {
            isRegistering = false
        }

        do {
            let response = try await apiService.register(
                DeviceRegisterRequest(fcmToken: token)
            )
            store.markRegistered(
                deviceId: response.deviceId,
                fcmToken: token
            )
        } catch {
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
}
