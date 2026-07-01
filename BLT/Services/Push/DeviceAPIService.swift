import Foundation

struct DeviceAPIService {
    private let networkClient: NetworkClient

    init(networkClient: NetworkClient = .shared) {
        self.networkClient = networkClient
    }

    func register(_ request: DeviceRegisterRequest) async throws -> DeviceResponse {
        PushLog.debug("POST /api/v1/devices start")
        let response: DeviceResponse = try await networkClient.post(
            "/api/v1/devices",
            body: request,
            requiresAuth: true
        )
        PushLog.debug("POST /api/v1/devices completed")
        return response
    }

    func unregister(deviceId: Int64) async throws {
        PushLog.debug("DELETE /api/v1/devices/\(deviceId) start")
        let _: EmptyResponse = try await networkClient.delete(
            "/api/v1/devices/\(deviceId)",
            requiresAuth: true
        )
        PushLog.debug("DELETE /api/v1/devices/\(deviceId) completed")
    }
}
