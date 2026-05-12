import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

struct AppleAuthResult {
    let identityToken: String
    let nonce: String
    let authorizationCode: String?
    let appleUserIdentifier: String
    let email: String?
    let fullName: String?

    var loginRequest: AuthLoginRequest {
        AuthLoginRequest(
            authType: .apple,
            identifier: identityToken,
            nonce: nonce
        )
    }
}

enum AppleAuthError: LocalizedError {
    case invalidCredential
    case missingIdentityToken
    case invalidIdentityTokenEncoding
    case authorizationFailed

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Apple 인증 정보를 확인할 수 없습니다."
        case .missingIdentityToken:
            return "Apple identity token이 없습니다."
        case .invalidIdentityTokenEncoding:
            return "Apple identity token을 문자열로 변환할 수 없습니다."
        case .authorizationFailed:
            return "Apple 로그인에 실패했습니다."
        }
    }
}

@MainActor
final class AppleAuthService: NSObject {
    private var currentNonce: String?
    private var continuation: CheckedContinuation<AppleAuthResult, Error>?

    func signIn() async throws -> AppleAuthResult {
        let nonce = Self.makeRandomNonce()
        currentNonce = nonce

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = Self.sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private func finish(with result: Result<AppleAuthResult, Error>) {
        switch result {
        case .success(let authResult):
            continuation?.resume(returning: authResult)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }

        continuation = nil
        currentNonce = nil
    }

    private static func makeRandomNonce(length: Int = 32) -> String {
        precondition(length > 0)

        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)

            if status != errSecSuccess {
                continue
            }

            randoms.forEach { random in
                guard remainingLength > 0 else { return }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)

        return hashedData
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

extension AppleAuthService: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(with: .failure(AppleAuthError.invalidCredential))
            return
        }

        guard let identityTokenData = credential.identityToken else {
            finish(with: .failure(AppleAuthError.missingIdentityToken))
            return
        }

        guard let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            finish(with: .failure(AppleAuthError.invalidIdentityTokenEncoding))
            return
        }

        let authorizationCode = credential.authorizationCode
            .flatMap { String(data: $0, encoding: .utf8) }

        let fullName = [credential.fullName?.familyName, credential.fullName?.givenName]
            .compactMap { $0 }
            .joined()

        finish(
            with: .success(
                AppleAuthResult(
                    identityToken: identityToken,
                    nonce: currentNonce ?? "",
                    authorizationCode: authorizationCode,
                    appleUserIdentifier: credential.user,
                    email: credential.email,
                    fullName: fullName.isEmpty ? nil : fullName
                )
            )
        )
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        finish(with: .failure(error))
    }
}

extension AppleAuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            preconditionFailure("Apple 로그인 화면을 표시할 UIWindowScene을 찾을 수 없습니다.")
        }

        return windowScene.windows.first { $0.isKeyWindow } ?? UIWindow(windowScene: windowScene)
    }
}
