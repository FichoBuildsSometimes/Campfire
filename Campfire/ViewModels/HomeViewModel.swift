import Foundation
import HealthKit
import Observation
import OSLog
import WidgetKit

@Observable
final class HomeViewModel {
    private static let logger = Logger(subsystem: "com.ficho.Campfire", category: "HomeViewModel")

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    enum HealthConnectionState: Equatable {
        case idle
        case loading
        case needsAuthorization
        case unavailable
        case ready
        case failed(String)
    }

    var stats: WalkingStats
    var healthState: HealthConnectionState = .idle

    @ObservationIgnored private let healthKitService: any HealthKitServiceProtocol
    @ObservationIgnored private let widgetDataStore: any SharedWidgetDataStoring
    @ObservationIgnored private let historyStore: any DailyStatsHistoryStoring
    @ObservationIgnored private var isRefreshInFlight = false

    init(
        stats: WalkingStats = .empty,
        healthKitService: any HealthKitServiceProtocol = HealthKitService(),
        widgetDataStore: any SharedWidgetDataStoring = SharedWidgetDataStore.shared,
        historyStore: any DailyStatsHistoryStoring = DailyStatsHistoryStore.shared
    ) {
        self.stats = stats
        self.healthKitService = healthKitService
        self.widgetDataStore = widgetDataStore
        self.historyStore = historyStore
    }

    var stepsTitle: String {
        "\(formatted(stats.stepsToday)) / \(formatted(stats.dailyStepGoal))"
    }

    var stepsProgress: Double {
        guard stats.dailyStepGoal > 0 else { return 0 }
        return clamped(Double(stats.stepsToday) / Double(stats.dailyStepGoal))
    }

    var fireChargeProgress: Double {
        clamped(Double(stats.fireCharge) / 100)
    }

    var fireChargeTitle: String {
        "\(stats.fireCharge)%"
    }

    var currentStage: CampfireStage {
        CampfireStage(fireCharge: stats.fireCharge)
    }

    var sticksTitle: String {
        "\(stats.sticksCollected)"
    }

    var caloriesTitle: String {
        formatted(stats.activeCalories)
    }

    var statusBadgeTitle: String {
        switch healthState {
        case .idle, .needsAuthorization:
            return "Apple Health"
        case .loading:
            return "Loading"
        case .unavailable:
            return "Unavailable"
        case .ready:
            return "Updated"
        case .failed:
            return "Try again"
        }
    }

    var healthStatusMessage: String {
        switch healthState {
        case .idle, .needsAuthorization:
            return "Connect Apple Health to let your steps fuel the fire."
        case .loading:
            return "Gathering today's walking fuel..."
        case .unavailable:
            return "Apple Health is not available here, but your fire is ready."
        case .ready where stats.stepsToday == 0 && stats.activeCalories == 0:
            return "Your fire is ready. Today's steps will warm it soon."
        case .ready:
            return "Your walk is warming today's fire."
        case .failed:
            return "Apple Health needs another try. Your fire will wait here."
        }
    }

    var showsConnectHealthButton: Bool {
        switch healthState {
        case .idle, .needsAuthorization, .failed:
            return true
        case .ready:
            return stats.stepsToday == 0 && stats.activeCalories == 0
        case .loading, .unavailable:
            return false
        }
    }

    var lastUpdatedTitle: String {
        guard healthState == .ready else {
            return "Not yet"
        }

        return Self.timeFormatter.string(from: stats.lastUpdated)
    }

    var lastUpdatedCaption: String {
        switch healthState {
        case .ready:
            return "From Apple Health"
        case .loading:
            return "Refreshing..."
        case .unavailable:
            return "Health unavailable"
        case .failed:
            return "Tap Connect"
        case .idle, .needsAuthorization:
            return "Waiting to connect"
        }
    }

    var stepsPerStick: Int {
        stats.stepsPerStick
    }

    func updateDailyStepGoal(_ dailyStepGoal: Int) {
        let normalizedGoal = CampfirePreferences.clampedDailyStepGoal(dailyStepGoal)
        guard stats.dailyStepGoal != normalizedGoal else { return }

        stats = WalkingStats(
            stepsToday: stats.stepsToday,
            dailyStepGoal: normalizedGoal,
            activeCalories: stats.activeCalories,
            lastUpdated: stats.lastUpdated
        )
        widgetDataStore.save(CampfireWidgetData(stats: stats))
        WidgetCenter.shared.reloadAllTimelines()
    }

    var currentStreakTitle: String {
        let streak = streakStats.currentStreak
        return streak > 0 ? "\(streak)d" : "--"
    }

    var currentStreakCaption: String {
        streakStats.currentStreak > 0 ? "Keep the fire warm" : "Start today"
    }

    var bestStreakTitle: String {
        let streak = streakStats.bestStreak
        return streak > 0 ? "\(streak)d best" : "Best --"
    }

    @MainActor
    func loadOnLaunch() async {
        guard healthKitService.isHealthDataAvailable else {
            applyUnavailableState()
            return
        }

        do {
            let status = try await healthKitService.authorizationRequestStatus()

            switch status {
            case .shouldRequest:
                healthState = .needsAuthorization
            case .unnecessary:
                await refresh()
            case .unknown:
                healthState = .needsAuthorization
            @unknown default:
                healthState = .needsAuthorization
            }
        } catch {
            applyFailureState(error)
        }
    }

    @MainActor
    func connectHealth() async {
        guard !isRefreshInFlight else { return }

        isRefreshInFlight = true
        healthState = .loading

        do {
            try await healthKitService.requestAuthorization()
            HealthKitBackgroundRefreshService.shared.enableBackgroundDelivery()
            try await refreshAfterAuthorization()
        } catch {
            applyFailureState(error)
        }

        isRefreshInFlight = false
    }

    @MainActor
    func refresh() async {
        guard !isRefreshInFlight else { return }

        isRefreshInFlight = true
        healthState = .loading

        do {
            let status = try await healthKitService.authorizationRequestStatus()

            switch status {
            case .shouldRequest, .unknown:
                healthState = .needsAuthorization
            case .unnecessary:
                try await refreshAfterAuthorization()
            @unknown default:
                healthState = .needsAuthorization
            }
        } catch {
            applyFailureState(error)
        }

        isRefreshInFlight = false
    }

    @MainActor
    private func refreshAfterAuthorization() async throws {
        Self.logger.debug("HealthKit today refresh start")
        let totals = try await healthKitService.fetchTodayTotals()
        let updatedStats = WalkingStats(
            stepsToday: totals.stepsToday,
            dailyStepGoal: stats.dailyStepGoal,
            activeCalories: totals.activeCalories,
            lastUpdated: .now
        )

        stats = updatedStats
        healthState = .ready
        historyStore.upsert([
            DailyWalkingStats(
                date: updatedStats.lastUpdated,
                steps: updatedStats.stepsToday,
                activeCalories: updatedStats.activeCalories,
                dailyStepGoal: updatedStats.dailyStepGoal
            )
        ])
        widgetDataStore.save(CampfireWidgetData(stats: updatedStats))
        WidgetCenter.shared.reloadAllTimelines()
        Self.logger.debug("HealthKit today refresh end: steps=\(totals.stepsToday), activeCalories=\(totals.activeCalories)")
    }

    @MainActor
    private func applyUnavailableState() {
        stats = WalkingStats(dailyStepGoal: stats.dailyStepGoal)
        healthState = .unavailable
    }

    @MainActor
    private func applyFailureState(_ error: Error) {
        if let healthKitError = error as? HealthKitServiceError,
           case .healthDataUnavailable = healthKitError {
            applyUnavailableState()
            return
        }

        let message = error.localizedDescription.isEmpty
            ? "Connect Apple Health to start fueling your fire."
            : error.localizedDescription
        healthState = .failed(message)
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private func formatted(_ value: Int) -> String {
        Self.numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private var streakStats: ProfileLifetimeStats {
        var records = historyStore.loadHistory()
        records.append(
            DailyWalkingStats(
                date: stats.lastUpdated,
                steps: stats.stepsToday,
                activeCalories: stats.activeCalories,
                dailyStepGoal: stats.dailyStepGoal
            )
        )
        return historyStore.lifetimeStats(from: records)
    }
}

private struct PreviewHealthKitService: HealthKitServiceProtocol {
    var totals: HealthKitDailyTotals

    var isHealthDataAvailable: Bool {
        true
    }

    func authorizationRequestStatus() async throws -> HKAuthorizationRequestStatus {
        .unnecessary
    }

    func requestAuthorization() async throws {}

    func fetchTodayTotals() async throws -> HealthKitDailyTotals {
        totals
    }

    func fetchDailyTotals(startDate: Date, endDate: Date) async throws -> [DailyWalkingStats] {
        [
            DailyWalkingStats(
                date: Date(),
                steps: totals.stepsToday,
                activeCalories: totals.activeCalories
            )
        ]
    }
}

private struct PreviewWidgetDataStore: SharedWidgetDataStoring {
    func load() -> CampfireWidgetData? {
        nil
    }

    func loadOrMock() -> CampfireWidgetData {
        .mock
    }

    func save(_ data: CampfireWidgetData) {}
}

private struct PreviewDailyStatsHistoryStore: DailyStatsHistoryStoring {
    var records: [DailyWalkingStats] = [
        DailyWalkingStats(date: Date().addingTimeInterval(-2 * 86_400), steps: 7_600, activeCalories: 280),
        DailyWalkingStats(date: Date().addingTimeInterval(-86_400), steps: 8_600, activeCalories: 330)
    ]

    func profileStartDate() -> Date {
        Date().addingTimeInterval(-14 * 86_400)
    }

    func loadHistory() -> [DailyWalkingStats] {
        records
    }

    func save(_ records: [DailyWalkingStats]) {}

    func upsert(_ records: [DailyWalkingStats]) {}

    func lifetimeStats(from records: [DailyWalkingStats]) -> ProfileLifetimeStats {
        let completedFireDays = Set(records.filter(\.hasCompletedFire).map { dayKey(for: $0.date) })

        return ProfileLifetimeStats(
            lifetimeSticks: records.reduce(0) { $0 + $1.sticksCollected },
            totalSteps: records.reduce(0) { $0 + $1.steps },
            totalActiveCalories: records.reduce(0) { $0 + $1.activeCalories },
            firesCompleted: records.filter(\.hasCompletedFire).count,
            currentStreak: currentStreak(in: completedFireDays),
            bestStreak: bestStreak(in: completedFireDays)
        )
    }

    private func currentStreak(in completedFireDays: Set<Date>) -> Int {
        let today = dayKey(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let anchorDay: Date

        if completedFireDays.contains(today) {
            anchorDay = today
        } else if completedFireDays.contains(yesterday) {
            anchorDay = yesterday
        } else {
            return 0
        }

        var streak = 0
        var currentDay = anchorDay

        while completedFireDays.contains(currentDay) {
            streak += 1
            currentDay = calendar.date(byAdding: .day, value: -1, to: currentDay) ?? currentDay
        }

        return streak
    }

    private func bestStreak(in completedFireDays: Set<Date>) -> Int {
        let sortedCompletedFireDays = completedFireDays.sorted()
        guard !sortedCompletedFireDays.isEmpty else { return 0 }

        var best = 1
        var current = 1

        for index in sortedCompletedFireDays.indices.dropFirst() {
            let previousDay = sortedCompletedFireDays[sortedCompletedFireDays.index(before: index)]
            let day = sortedCompletedFireDays[index]

            if calendar.isDate(day, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: previousDay) ?? previousDay) {
                current += 1
            } else {
                best = max(best, current)
                current = 1
            }
        }

        return max(best, current)
    }

    private var calendar: Calendar {
        .current
    }

    private func dayKey(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
}

extension HomeViewModel {
    static func preview(stats: WalkingStats = .mock) -> HomeViewModel {
        HomeViewModel(
            stats: stats,
            healthKitService: PreviewHealthKitService(
                totals: HealthKitDailyTotals(
                    stepsToday: stats.stepsToday,
                    activeCalories: stats.activeCalories
                )
            ),
            widgetDataStore: PreviewWidgetDataStore(),
            historyStore: PreviewDailyStatsHistoryStore()
        )
    }
}
