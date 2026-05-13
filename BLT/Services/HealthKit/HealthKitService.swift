import Foundation
import HealthKit

enum HealthKitPermissionStatus {
    case unavailable
    case requested
}

enum HealthKitServiceError: LocalizedError {
    case unavailable
    case missingSleepType
    case missingHRVType

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "이 기기에서는 HealthKit을 사용할 수 없습니다."
        case .missingSleepType:
            return "수면 데이터 타입을 찾을 수 없습니다."
        case .missingHRVType:
            return "심박변이도 데이터 타입을 찾을 수 없습니다."
        }
    }
}

final class HealthKitService {
    private let healthStore = HKHealthStore()

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestSleepAndHRVAuthorization() async throws -> HealthKitPermissionStatus {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.unavailable
        }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitServiceError.missingSleepType
        }

        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthKitServiceError.missingHRVType
        }

        try await healthStore.requestAuthorization(
            toShare: [],
            read: [sleepType, hrvType]
        )

        return .requested
    }
}
