import Foundation

enum NetworkError: LocalizedError {
    case baseURLNotConfigured
    case invalidResponse
    case serverError(statusCode: Int, data: Data)
    case missingAccessToken
    case emptyResponse

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
        case .emptyResponse:
            return "서버 응답이 비어 있습니다."
        }
    }
}

struct EmptyResponse: Decodable {}

final class NetworkClient {
    static let shared = NetworkClient()

    var baseURL: URL?
    var accessTokenProvider: () -> String?
    var accessTokenRefreshHandler: (() async -> String?)?

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseURL: URL? = URL(string: "https://api.bryki.site"),
        accessTokenProvider: @escaping () -> String? = { nil },
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.accessTokenProvider = accessTokenProvider
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            if let date = ISO8601DateFormatter.bltFull.date(from: string)
                ?? ISO8601DateFormatter.bltNoFraction.date(from: string) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(string)"
            )
        }
    }

    func get<Response: Decodable>(
        _ path: String,
        queryItems: [URLQueryItem] = [],
        requiresAuth: Bool
    ) async throws -> Response {
        try await request(
            path,
            method: "GET",
            queryItems: queryItems,
            body: Optional<Data>.none,
            requiresAuth: requiresAuth
        )
    }

    func post<Request: Encodable, Response: Decodable>(
        _ path: String,
        body: Request,
        requiresAuth: Bool
    ) async throws -> Response {
        try await request(
            path,
            method: "POST",
            body: body,
            requiresAuth: requiresAuth
        )
    }

    func post<Response: Decodable>(
        _ path: String,
        requiresAuth: Bool
    ) async throws -> Response {
        try await request(
            path,
            method: "POST",
            body: Optional<Data>.none,
            requiresAuth: requiresAuth
        )
    }

    func patch<Request: Encodable, Response: Decodable>(
        _ path: String,
        body: Request,
        requiresAuth: Bool
    ) async throws -> Response {
        try await request(
            path,
            method: "PATCH",
            body: body,
            requiresAuth: requiresAuth
        )
    }

    func delete<Response: Decodable>(
        _ path: String,
        requiresAuth: Bool
    ) async throws -> Response {
        try await request(
            path,
            method: "DELETE",
            body: Optional<Data>.none,
            requiresAuth: requiresAuth
        )
    }

    private func request<Request: Encodable, Response: Decodable>(
        _ path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Request?,
        requiresAuth: Bool
    ) async throws -> Response {
        guard let baseURL else {
            throw NetworkError.baseURLNotConfigured
        }

        var components = URLComponents(
            url: baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try encoder.encode(body)
        }

        if requiresAuth {
            guard let accessToken = accessTokenProvider() else {
                throw NetworkError.missingAccessToken
            }

            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        var (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if httpResponse.statusCode == 401,
           requiresAuth,
           let refreshedToken = await accessTokenRefreshHandler?() {
            request.setValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")
            (data, response) = try await session.data(for: request)

            guard let retryResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            return try decode(data: data, response: retryResponse)
        }

        return try decode(data: data, response: httpResponse)
    }

    private func decode<Response: Decodable>(
        data: Data,
        response: HTTPURLResponse
    ) throws -> Response {
        guard (200..<300).contains(response.statusCode) else {
            throw NetworkError.serverError(statusCode: response.statusCode, data: data)
        }

        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }

        guard !data.isEmpty else {
            throw NetworkError.emptyResponse
        }

        return try decoder.decode(Response.self, from: data)
    }
}

private extension ISO8601DateFormatter {
    static let bltFull: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let bltNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
