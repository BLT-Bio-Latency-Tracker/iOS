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
            clear()
            return nil
        }

        do {
            let response = try await service.refreshToken(RefreshTokenRequest(refreshToken: refreshToken))
            guard save(response.session) else {
                clear()
                return nil
            }
            return response.accessToken
        } catch {
            if Self.shouldClearSession(after: error) {
                clear()
            }
            return nil
        }
    }

    @discardableResult
    func save(_ session: AuthSession) -> Bool {
        guard let data = try? JSONEncoder().encode(session) else { return false }
        return saveData(data)
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "bryki",
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
        PushDeviceStore().clearRegistration()
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
        clear()

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
