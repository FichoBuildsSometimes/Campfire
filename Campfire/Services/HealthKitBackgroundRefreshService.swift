import Foundation
import HealthKit
import OSLog
import UIKit
import WidgetKit

final class HealthKitBackgroundRefreshService {
    static let shared = HealthKitBackgroundRefreshService()

    private static let logger = Logger(
        subsystem: "com.ficho.Campfire",
        category: "HealthKitBackgroundRefreshService"
    )

    private let healthStore: HKHealthStore
    private let healthKitService: any HealthKitServiceProtocol
    private let widgetDataStore: any SharedWidgetDataStoring
    private var observerQueries: [HKObserverQuery] = []
    private var hasStarted = false

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        healthKitService: any HealthKitServiceProtocol = HealthKitService(),
        widgetDataStore: any SharedWidgetDataStoring = SharedWidgetDataStore.shared
    ) {
        self.healthStore = healthStore
        self.healthKitService = healthKitService
        self.widgetDataStore = widgetDataStore
    }

    func start() {
        guard !hasStarted, healthKitService.isHealthDataAvailable else { return }
        hasStarted = true

        for sampleType in observedSampleTypes() {
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completion, error in
                guard let self else {
                    completion()
                    return
                }

                if let error {
                    Self.logger.warning(
                        "HealthKit observer update failed: \(error.localizedDescription, privacy: .public)"
                    )
                    completion()
                    return
                }

                refreshWidgets(completion: completion)
            }

            observerQueries.append(query)
            healthStore.execute(query)
        }

        enableBackgroundDelivery()
    }

    func enableBackgroundDelivery() {
        guard healthKitService.isHealthDataAvailable else { return }

        for sampleType in observedSampleTypes() {
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { success, error in
                if let error {
                    Self.logger.warning(
                        "Unable to enable HealthKit background delivery for \(sampleType.identifier, privacy: .public): \(error.localizedDescription, privacy: .public)"
                    )
                } else {
                    Self.logger.debug(
                        "HealthKit background delivery for \(sampleType.identifier, privacy: .public): \(success)"
                    )
                }
            }
        }
    }

    private func refreshWidgets(completion: @escaping HKObserverQueryCompletionHandler) {
        Task {
            defer { completion() }

            do {
                let totals = try await healthKitService.fetchTodayTotals()
                let dailyStepGoal = widgetDataStore.load()?.dailyStepGoal
                    ?? CampfirePreferences.savedDailyStepGoal()
                let data = CampfireWidgetData(
                    stats: WalkingStats(
                        stepsToday: totals.stepsToday,
                        dailyStepGoal: dailyStepGoal,
                        activeCalories: totals.activeCalories,
                        lastUpdated: .now
                    )
                )

                widgetDataStore.save(data)
                WidgetCenter.shared.reloadAllTimelines()
                Self.logger.debug(
                    "Background widget refresh completed: steps=\(totals.stepsToday), activeCalories=\(totals.activeCalories)"
                )
            } catch {
                Self.logger.warning(
                    "Background widget refresh failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func observedSampleTypes() -> [HKSampleType] {
        [
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
        ].compactMap { $0 }
    }
}

final class CampfireAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        HealthKitBackgroundRefreshService.shared.start()
        return true
    }
}
