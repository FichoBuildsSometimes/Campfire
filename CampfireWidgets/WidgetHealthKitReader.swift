import Foundation
import HealthKit

struct WidgetHealthKitTotals: Equatable {
    let steps: Int
    let activeCalories: Int
}

enum WidgetHealthKitReaderError: LocalizedError {
    case healthDataUnavailable
    case authorizationRequired
    case missingQuantityType(HKQuantityTypeIdentifier)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Apple Health is not available on this device."
        case .authorizationRequired:
            return "Apple Health authorization must be granted in Campfire."
        case .missingQuantityType(let identifier):
            return "Apple Health data type is unavailable: \(identifier.rawValue)."
        case .queryFailed(let message):
            return message
        }
    }
}

protocol WidgetHealthKitReading {
    func fetchTodayTotals(at date: Date) async throws -> WidgetHealthKitTotals
}

final class WidgetHealthKitReader: WidgetHealthKitReading {
    private let healthStore: HKHealthStore
    private let calendar: Calendar

    init(healthStore: HKHealthStore = HKHealthStore(), calendar: Calendar = .current) {
        self.healthStore = healthStore
        self.calendar = calendar
    }

    func fetchTodayTotals(at date: Date) async throws -> WidgetHealthKitTotals {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw WidgetHealthKitReaderError.healthDataUnavailable
        }

        let readTypes = try requiredReadTypes()
        let status = try await authorizationRequestStatus(for: readTypes)

        guard status == .unnecessary else {
            throw WidgetHealthKitReaderError.authorizationRequired
        }

        let startOfDay = calendar.startOfDay(for: date)

        async let steps = fetchCumulativeQuantity(
            identifier: .stepCount,
            unit: .count(),
            startDate: startOfDay,
            endDate: date
        )
        async let calories = fetchCumulativeQuantity(
            identifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            startDate: startOfDay,
            endDate: date
        )

        return try await WidgetHealthKitTotals(
            steps: max(Int(floor(steps)), 0),
            activeCalories: max(Int(floor(calories)), 0)
        )
    }

    private func authorizationRequestStatus(
        for readTypes: Set<HKObjectType>
    ) async throws -> HKAuthorizationRequestStatus {
        try await withCheckedThrowingContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(
                toShare: Set<HKSampleType>(),
                read: readTypes
            ) { status, error in
                if let error {
                    continuation.resume(
                        throwing: WidgetHealthKitReaderError.queryFailed(error.localizedDescription)
                    )
                    return
                }

                continuation.resume(returning: status)
            }
        }
    }

    private func fetchCumulativeQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        startDate: Date,
        endDate: Date
    ) async throws -> Double {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            throw WidgetHealthKitReaderError.missingQuantityType(identifier)
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: [.strictStartDate]
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error {
                    continuation.resume(
                        throwing: WidgetHealthKitReaderError.queryFailed(error.localizedDescription)
                    )
                    return
                }

                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }

    private func requiredReadTypes() throws -> Set<HKObjectType> {
        guard let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            throw WidgetHealthKitReaderError.missingQuantityType(.stepCount)
        }

        guard let activeEnergyBurned = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw WidgetHealthKitReaderError.missingQuantityType(.activeEnergyBurned)
        }

        return [stepCount, activeEnergyBurned]
    }
}
