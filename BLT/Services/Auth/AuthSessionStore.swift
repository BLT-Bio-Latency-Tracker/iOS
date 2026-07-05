import Foundation
import Security

struct AuthSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresInSeconds: Int64
    let userId: Int64?
    let onboardingCompleted: Bool
}

final class AuthSessionStore {
    static let shared = AuthSessionStore()

    /// 리프레시 토큰 만료 등으로 세션이 강제 종료됐을 때 발행된다.
    /// 명시적 로그아웃/탈퇴는 화면 콜백으로 라우팅되므로 이 알림을 발행하지 않는다.
    static let sessionDidExpireNotification = Notification.Name("AuthSessionStore.sessionDidExpire")

    private let key = "auth.session"

    private init() {}

    var currentSession: AuthSession? {
        guard let data = readData() else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    var accessToken: String? {
        currentSession?.accessToken
    }

    func refreshAccessToken(using service: AuthAPIService = AuthAPIService()) async -> String? {
        guard let refreshToken = currentSession?.refreshToken else {
            expireSession()
            return nil
        }

        do {
            let response = try await service.refreshToken(RefreshTokenRequest(refreshToken: refreshToken))
            guard save(response.session) else {
                expireSession()
                return nil
            }
            return response.accessToken
        } catch {
            if Self.shouldClearSession(after: error) {
                expireSession()
            }
            return nil
        }
    }

    private func expireSession() {
        clearForSignOut()
        NotificationCenter.default.post(name: Self.sessionDidExpireNotification, object: nil)
    }

    @discardableResult
    func save(_ session: AuthSession) -> Bool {
        guard let data = try? JSONEncoder().encode(session) else { return false }
        return saveData(data)
    }

    func clear() {
        deleteSession()
    }

    func clearForSignOut() {
        deleteSession()
        PushDeviceStore().clearAll()
    }

    private func deleteSession() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "bryki",
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    func updateOnboardingCompleted(_ isCompleted: Bool) {
        guard let session = currentSession else { return }

        save(
            AuthSession(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                tokenType: session.tokenType,
                expiresInSeconds: session.expiresInSeconds,
                userId: session.userId,
                onboardingCompleted: isCompleted
            )
        )
    }

    @discardableResult
    private func saveData(_ data: Data) -> Bool {
        deleteSession()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "bryki",
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private func readData() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "bryki",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func shouldClearSession(after error: Error) -> Bool {
        guard case let NetworkError.serverError(statusCode, _) = error else {
            return false
        }

        return statusCode == 400 || statusCode == 401
    }
}
