import AuthenticationServices
import Combine
import Foundation

@MainActor
final class AuthFlowViewModel: ObservableObject {
    @Published var isSigningIn = false
    @Published var errorMessage: String?

    private(set) var latestAppleLoginRequest: AuthLoginRequest?
    private(set) var latestTermsAgreementRequest: TermsAgreementRequest?

    private let appleAuthService: AppleAuthService
    private let authAPIService: AuthAPIService
    private let termsAPIService: TermsAPIService

    init() {
        self.appleAuthService = AppleAuthService()
        self.authAPIService = AuthAPIService()
        self.termsAPIService = TermsAPIService()
    }

    init(
        appleAuthService: AppleAuthService,
        authAPIService: AuthAPIService,
        termsAPIService: TermsAPIService
    ) {
        self.appleAuthService = appleAuthService
        self.authAPIService = authAPIService
        self.termsAPIService = termsAPIService
    }

    func signInWithApple(termsAgreement: TermsAgreementState) async -> Bool {
        guard termsAgreement.isRequiredAgreed else {
            errorMessage = "필수 약관에 모두 동의해주세요."
            return false
        }

        isSigningIn = true
        errorMessage = nil

        defer {
            isSigningIn = false
        }

        do {
            let appleResult = try await appleAuthService.signIn()
            latestAppleLoginRequest = appleResult.loginRequest
            latestTermsAgreementRequest = termsAgreement.termsRequest

            guard NetworkClient.shared.baseURL != nil else {
                return true
            }

            _ = try await authAPIService.login(appleResult.loginRequest)
            // TODO: 서버 baseURL과 토큰 저장 방식 확정 후 termsAPIService.submitTerms(...)를 연결합니다.
            return true
        } catch {
            guard !isAppleLoginCanceled(error) else {
                return false
            }

            errorMessage = error.localizedDescription
            return false
        }
    }

    private func isAppleLoginCanceled(_ error: Error) -> Bool {
        guard let authorizationError = error as? ASAuthorizationError else {
            return false
        }

        return authorizationError.code == .canceled
    }
}
