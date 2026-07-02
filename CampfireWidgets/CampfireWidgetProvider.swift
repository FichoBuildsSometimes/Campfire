import Foundation
import OSLog
import WidgetKit

struct CampfireWidgetProvider: TimelineProvider {
    private static let logger = Logger(subsystem: "com.ficho.Campfire", category: "CampfireWidgetProvider")

    private let dataStore: any SharedWidgetDataStoring
    private let healthKitReader: any WidgetHealthKitReading

    init(
        dataStore: any SharedWidgetDataStoring = SharedWidgetDataStore.shared,
        healthKitReader: any WidgetHealthKitReading = WidgetHealthKitReader()
    ) {
        self.dataStore = dataStore
        self.healthKitReader = healthKitReader
    }

    func placeholder(in context: Context) -> CampfireWidgetEntry {
        .mock()
    }

    func getSnapshot(in context: Context, completion: @escaping (CampfireWidgetEntry) -> Void) {
        let now = Date()

        if context.isPreview {
            completion(.mock(date: now))
        } else {
            completion(entry(date: now, data: fallbackData(relativeTo: now)))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CampfireWidgetEntry>) -> Void) {
        let now = Date()
        let nextRefresh = min(
            now.addingTimeInterval(30 * 60),
            WidgetDayPhase.nextTransition(after: now)
        )

        Task {
            let data = await refreshedData(at: now)
            let timeline = Timeline(
                entries: [entry(date: now, data: data)],
                policy: .after(nextRefresh)
            )
            completion(timeline)
        }
    }

    private func entry(date: Date, data: CampfireWidgetData) -> CampfireWidgetEntry {
        CampfireWidgetEntry(
            date: date,
            data: data,
            dayPhase: WidgetDayPhase(date: date)
        )
    }

    private func refreshedData(at date: Date) async -> CampfireWidgetData {
        do {
            let totals = try await healthKitReader.fetchTodayTotals(at: date)
            let dailyStepGoal = dataStore.load()?.dailyStepGoal ?? WalkingStats.defaultDailyStepGoal
            let data = CampfireWidgetData(
                stats: WalkingStats(
                    stepsToday: totals.steps,
                    dailyStepGoal: dailyStepGoal,
                    activeCalories: totals.activeCalories,
                    lastUpdated: date
                )
            )

            dataStore.save(data)
            Self.logger.debug(
                "Refreshed widget data from HealthKit: steps=\(totals.steps), activeCalories=\(totals.activeCalories)"
            )
            return data
        } catch {
            Self.logger.warning(
                "Unable to refresh widget data from HealthKit; using shared cache: \(error.localizedDescription, privacy: .public)"
            )
            return fallbackData(relativeTo: date)
        }
    }

    private func fallbackData(relativeTo date: Date) -> CampfireWidgetData {
        if let cachedData = dataStore.load() {
            return cachedData.widgetDisplayData(relativeTo: date)
        }

        return CampfireWidgetData(
            stats: WalkingStats(
                dailyStepGoal: WalkingStats.defaultDailyStepGoal,
                lastUpdated: date
            )
        )
    }
}
