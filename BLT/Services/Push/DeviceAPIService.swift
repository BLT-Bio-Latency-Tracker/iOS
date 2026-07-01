import Foundation

struct DeviceAPIService {
    private let networkClient: NetworkClient

    init(networkClient: NetworkClient = .shared) {
        self.networkClient = networkClient
    }

    func register(_ request: DeviceRegisterRequest) async throws -> DeviceResponse {
        try await networkClient.post(
            "/api/v1/devices",
            body: request,
            requiresAuth: true
        )
    }

    func unregister(deviceId: Int64) async throws {
        let _: EmptyResponse = try await networkClient.delete(
            "/api/v1/devices/\(deviceId)",
            requiresAuth: true
        )
    }
}
