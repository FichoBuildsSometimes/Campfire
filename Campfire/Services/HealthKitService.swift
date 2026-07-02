import Foundation
import HealthKit

struct HealthKitDailyTotals: Equatable {
    var stepsToday: Int
    var activeCalories: Int
}

protocol HealthKitServiceProtocol {
    var isHealthDataAvailable: Bool { get }

    func authorizationRequestStatus() async throws -> HKAuthorizationRequestStatus
    func requestAuthorization() async throws
    func fetchTodayTotals() async throws -> HealthKitDailyTotals
    func fetchDailyTotals(startDate: Date, endDate: Date) async throws -> [DailyWalkingStats]
}

enum HealthKitServiceError: LocalizedError {
    case healthDataUnavailable
    case missingQuantityType(HKQuantityTypeIdentifier)
    case authorizationRequestFailed
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Apple Health is not available on this device."
        case .missingQuantityType(let identifier):
            return "Apple Health data type is unavailable: \(identifier.rawValue)."
        case .authorizationRequestFailed:
            return "Apple Health authorization was not completed."
        case .queryFailed(let message):
            return message
        }
    }
}

final class HealthKitService: HealthKitServiceProtocol {
    private let healthStore: HKHealthStore
    private let calendar: Calendar

    init(healthStore: HKHealthStore = HKHealthStore(), calendar: Calendar = .current) {
        self.healthStore = healthStore
        self.calendar = calendar
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func authorizationRequestStatus() async throws -> HKAuthorizationRequestStatus {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.healthDataUnavailable
        }

        let readTypes = try Self.requiredReadTypes()

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(
                toShare: Set<HKSampleType>(),
                read: readTypes
            ) { status, error in
                if let error {
                    continuation.resume(throwing: HealthKitServiceError.queryFailed(error.localizedDescription))
                    return
                }

                continuation.resume(returning: status)
            }
        }
    }

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.healthDataUnavailable
        }

        let readTypes = try Self.requiredReadTypes()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(
                toShare: Set<HKSampleType>(),
                read: readTypes
            ) { success, error in
                if let error {
                    continuation.resume(throwing: HealthKitServiceError.queryFailed(error.localizedDescription))
                    return
                }

                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitServiceError.authorizationRequestFailed)
                }
            }
        }
    }

    func fetchTodayTotals() async throws -> HealthKitDailyTotals {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.healthDataUnavailable
        }

        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        let steps = try await fetchCumulativeQuantity(
            identifier: .stepCount,
            unit: .count(),
            startDate: startOfDay,
            endDate: now
        )

        let calories = try await fetchCumulativeQuantity(
            identifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            startDate: startOfDay,
            endDate: now
        )

        return HealthKitDailyTotals(
            stepsToday: max(Int(floor(steps)), 0),
            activeCalories: max(Int(floor(calories)), 0)
        )
    }

    func fetchDailyTotals(startDate: Date, endDate: Date) async throws -> [DailyWalkingStats] {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.healthDataUnavailable
        }

        let firstDay = calendar.startOfDay(for: startDate)
        let lastDay = calendar.startOfDay(for: endDate)

        guard firstDay <= endDate else {
            return []
        }

        let stepsByDay = try await fetchDailyCumulativeQuantities(
            identifier: .stepCount,
            unit: .count(),
            startDate: firstDay,
            endDate: endDate
        )

        let caloriesByDay = try await fetchDailyCumulativeQuantities(
            identifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            startDate: firstDay,
            endDate: endDate
        )

        var records: [DailyWalkingStats] = []
        var currentDay = firstDay

        while currentDay <= lastDay {
            records.append(
                DailyWalkingStats(
                    date: currentDay,
                    steps: stepsByDay[currentDay] ?? 0,
                    activeCalories: caloriesByDay[currentDay] ?? 0,
                    dailyStepGoal: CampfirePreferences.savedDailyStepGoal()
                )
            )

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else {
                break
            }
            currentDay = nextDay
        }

        return records
    }

    private func fetchCumulativeQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        startDate: Date,
        endDate: Date
    ) async throws -> Double {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            throw HealthKitServiceError.missingQuantityType(identifier)
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
                    continuation.resume(throwing: HealthKitServiceError.queryFailed(error.localizedDescription))
                    return
                }

                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }

    private func fetchDailyCumulativeQuantities(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        startDate: Date,
        endDate: Date
    ) async throws -> [Date: Int] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            throw HealthKitServiceError.missingQuantityType(identifier)
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: [.strictStartDate]
        )

        var interval = DateComponents()
        interval.day = 1

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { [calendar] _, collection, error in
                if let error {
                    continuation.resume(throwing: HealthKitServiceError.queryFailed(error.localizedDescription))
                    return
                }

                guard let collection else {
                    continuation.resume(returning: [:])
                    return
                }

                var totalsByDay: [Date: Int] = [:]

                collection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let day = calendar.startOfDay(for: statistics.startDate)
                    let value = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    totalsByDay[day] = max(Int(floor(value)), 0)
                }

                continuation.resume(returning: totalsByDay)
            }

            healthStore.execute(query)
        }
    }

    private static func requiredReadTypes() throws -> Set<HKObjectType> {
        guard let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitServiceError.missingQuantityType(.stepCount)
        }

        guard let activeEnergyBurned = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthKitServiceError.missingQuantityType(.activeEnergyBurned)
        }

        return [stepCount, activeEnergyBurned]
    }
}
