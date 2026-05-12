import Foundation

enum NetworkError: LocalizedError {
    case baseURLNotConfigured
    case invalidResponse
    case serverError(statusCode: Int, data: Data)
    case missingAccessToken

    var errorDescription: String? {
        switch self {
        case .baseURLNotConfigured:
            return "API baseURL이 아직 설정되지 않았습니다."
        case .invalidResponse:
            return "서버 응답을 확인할 수 없습니다."
        case .serverError(let statusCode, _):
            return "서버 요청에 실패했습니다. statusCode: \(statusCode)"
        case .missingAccessToken:
            return "인증 토큰이 없습니다."
        }
    }
}

final class NetworkClient {
    static let shared = NetworkClient()

    var baseURL: URL?
    var accessTokenProvider: () -> String?

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseURL: URL? = nil,
        accessTokenProvider: @escaping () -> String? = { nil },
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.accessTokenProvider = accessTokenProvider
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    func post<Request: Encodable, Response: Decodable>(
        _ path: String,
        body: Request,
        requiresAuth: Bool
    ) async throws -> Response {
        guard let baseURL else {
            throw NetworkError.baseURLNotConfigured
        }

        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(body)

        if requiresAuth {
            guard let accessToken = accessTokenProvider() else {
                throw NetworkError.missingAccessToken
            }

            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, data: data)
        }

        return try decoder.decode(Response.self, from: data)
    }
}
