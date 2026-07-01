import Foundation
import UIKit

@MainActor
final class PushDeviceRegistrationService {
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

        await unregisterPendingDeviceIfNeeded()

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
        }
    }

    func requestRegistrationAfterAuthorizationGranted() async {
        UIApplication.shared.registerForRemoteNotifications()
        await registerCurrentDeviceIfPossible(force: true)
    }

    func unregisterCurrentDeviceIfPossible() async {
        guard let deviceId = store.registeredDeviceId else {
            store.clearRegistration()
            return
        }

        do {
            try await apiService.unregister(deviceId: deviceId)
            store.clearRegistration()
            store.clearPendingUnregister()
        } catch {
            PushLog.debug("Unregister device failed: \(error.localizedDescription)")
            store.markPendingUnregister(deviceId: deviceId)
            store.clearRegistration()
        }
    }

    private func unregisterPendingDeviceIfNeeded() async {
        guard let pendingDeviceId = store.pendingUnregisterDeviceId else { return }

        do {
            PushLog.debug("Retry pending device unregister: deviceId=\(pendingDeviceId)")
            try await apiService.unregister(deviceId: pendingDeviceId)
            store.clearPendingUnregister()
        } catch {
            PushLog.debug("Pending device unregister failed: \(error.localizedDescription)")
        }
    }

    private static func maskedToken(_ token: String) -> String {
        guard token.count > 12 else { return "***" }
        return "\(token.prefix(6))...\(token.suffix(6))"
    }
}
