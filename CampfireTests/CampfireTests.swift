import HealthKit
import XCTest
@testable import Campfire

final class CampfireTests: XCTestCase {
    func testWalkingStatsClampInputsAndProgress() {
        let stats = WalkingStats(
            stepsToday: 10_000,
            dailyStepGoal: 8_000,
            activeCalories: -20
        )

        XCTAssertEqual(stats.stepsToday, 10_000)
        XCTAssertEqual(stats.activeCalories, 0)
        XCTAssertEqual(stats.sticksCollected, 100)
        XCTAssertEqual(stats.fireCharge, 100)
        XCTAssertEqual(stats.stepsPerStick, 80)
    }

    func testCampfireStageBoundaries() {
        XCTAssertEqual(CampfireStage(fireCharge: -1), .stage1)
        XCTAssertEqual(CampfireStage(fireCharge: 19), .stage1)
        XCTAssertEqual(CampfireStage(fireCharge: 20), .stage2)
        XCTAssertEqual(CampfireStage(fireCharge: 40), .stage3)
        XCTAssertEqual(CampfireStage(fireCharge: 60), .stage4)
        XCTAssertEqual(CampfireStage(fireCharge: 80), .stage5)
        XCTAssertEqual(CampfireStage(fireCharge: 101), .stage5)
    }

    func testPreferenceClamping() {
        XCTAssertEqual(
            CampfirePreferences.clampedDailyStepGoal(100),
            CampfirePreferences.minimumDailyStepGoal
        )
        XCTAssertEqual(
            CampfirePreferences.clampedDailyStepGoal(100_000),
            CampfirePreferences.maximumDailyStepGoal
        )
        XCTAssertEqual(CampfirePreferences.clampedReminderHour(-1), 0)
        XCTAssertEqual(CampfirePreferences.clampedReminderHour(24), 23)
        XCTAssertEqual(CampfirePreferences.clampedReminderMinute(60), 59)
    }

    func testDeepLinkAcceptsOnlyHomeRoute() {
        XCTAssertEqual(
            CampfireDeepLink(url: URL(string: "campfire://home")!),
            .home
        )
        XCTAssertEqual(
            CampfireDeepLink(url: URL(string: "CAMPFIRE://HOME/")!),
            .home
        )
        XCTAssertNil(CampfireDeepLink(url: URL(string: "campfire://settings")!))
        XCTAssertNil(CampfireDeepLink(url: URL(string: "https://home")!))
        XCTAssertNil(CampfireDeepLink(url: URL(string: "campfire://home?source=test")!))
    }

    func testHistoryStoreDropsExpiredRecordsAndReplacesSameDay() {
        let harness = UserDefaultsHarness()
        defer { harness.cleanUp() }

        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let profileStart = calendar.date(byAdding: .day, value: -600, to: today)!
        harness.defaults.set(profileStart, forKey: "campfire_profile_start_date")

        let store = DailyStatsHistoryStore(defaults: harness.defaults, calendar: calendar)
        let expiredDate = calendar.date(byAdding: .day, value: -400, to: today)!
        let recentDate = calendar.date(byAdding: .day, value: -2, to: today)!

        store.upsert([
            DailyWalkingStats(date: expiredDate, steps: 9_000, activeCalories: 300),
            DailyWalkingStats(date: recentDate, steps: 1_000, activeCalories: 50)
        ])
        store.upsert([
            DailyWalkingStats(date: recentDate, steps: 4_000, activeCalories: 125)
        ])

        let records = store.loadHistory()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.steps, 4_000)
        XCTAssertEqual(records.first?.activeCalories, 125)
    }

    func testHistoryStoreCalculatesCurrentAndBestStreaks() {
        let harness = UserDefaultsHarness()
        defer { harness.cleanUp() }

        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        harness.defaults.set(
            calendar.date(byAdding: .day, value: -30, to: today),
            forKey: "campfire_profile_start_date"
        )
        let store = DailyStatsHistoryStore(defaults: harness.defaults, calendar: calendar)

        let records = (0..<3).map { offset in
            DailyWalkingStats(
                date: calendar.date(byAdding: .day, value: -offset, to: today)!,
                steps: 8_000,
                activeCalories: 250,
                dailyStepGoal: 8_000
            )
        }
        let lifetime = store.lifetimeStats(from: records)

        XCTAssertEqual(lifetime.currentStreak, 3)
        XCTAssertEqual(lifetime.bestStreak, 3)
        XCTAssertEqual(lifetime.firesCompleted, 3)
    }

    @MainActor
    func testHomeViewModelLoadsAuthorizedHealthData() async {
        let widgetStore = WidgetStoreSpy()
        let historyStore = HistoryStoreSpy()
        let viewModel = HomeViewModel(
            stats: WalkingStats(dailyStepGoal: 7_500),
            healthKitService: HealthKitServiceStub(
                status: .unnecessary,
                totals: HealthKitDailyTotals(stepsToday: 3_750, activeCalories: 180)
            ),
            widgetDataStore: widgetStore,
            historyStore: historyStore
        )

        await viewModel.loadOnLaunch()

        XCTAssertEqual(viewModel.healthState, .ready)
        XCTAssertEqual(viewModel.stats.stepsToday, 3_750)
        XCTAssertEqual(viewModel.stats.activeCalories, 180)
        XCTAssertEqual(viewModel.stats.fireCharge, 50)
        XCTAssertEqual(widgetStore.savedData?.stepsToday, 3_750)
        XCTAssertEqual(historyStore.records.last?.steps, 3_750)
    }

    @MainActor
    func testHomeViewModelHandlesUnavailableHealthData() async {
        let viewModel = HomeViewModel(
            stats: WalkingStats(stepsToday: 900, dailyStepGoal: 8_000, activeCalories: 20),
            healthKitService: HealthKitServiceStub(isHealthDataAvailable: false),
            widgetDataStore: WidgetStoreSpy(),
            historyStore: HistoryStoreSpy()
        )

        await viewModel.loadOnLaunch()

        XCTAssertEqual(viewModel.healthState, .unavailable)
        XCTAssertEqual(viewModel.stats.stepsToday, 0)
        XCTAssertEqual(viewModel.stats.dailyStepGoal, 8_000)
    }

    @MainActor
    func testHomeViewModelSurfacesHealthErrors() async {
        let viewModel = HomeViewModel(
            healthKitService: HealthKitServiceStub(error: TestError.healthFailure),
            widgetDataStore: WidgetStoreSpy(),
            historyStore: HistoryStoreSpy()
        )

        await viewModel.loadOnLaunch()

        XCTAssertEqual(viewModel.healthState, .failed("Health data could not be loaded."))
    }
}

private final class UserDefaultsHarness {
    let suiteName = "CampfireTests.\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    func cleanUp() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private enum TestError: LocalizedError {
    case healthFailure

    var errorDescription: String? {
        "Health data could not be loaded."
    }
}

private struct HealthKitServiceStub: HealthKitServiceProtocol {
    var isHealthDataAvailable = true
    var status: HKAuthorizationRequestStatus = .shouldRequest
    var totals = HealthKitDailyTotals(stepsToday: 0, activeCalories: 0)
    var error: Error?

    func authorizationRequestStatus() async throws -> HKAuthorizationRequestStatus {
        if let error { throw error }
        return status
    }

    func requestAuthorization() async throws {
        if let error { throw error }
    }

    func fetchTodayTotals() async throws -> HealthKitDailyTotals {
        if let error { throw error }
        return totals
    }

    func fetchDailyTotals(startDate: Date, endDate: Date) async throws -> [DailyWalkingStats] {
        if let error { throw error }
        return []
    }
}

private final class WidgetStoreSpy: SharedWidgetDataStoring {
    var savedData: CampfireWidgetData?

    func load() -> CampfireWidgetData? { savedData }
    func loadOrMock() -> CampfireWidgetData { savedData ?? .mock }
    func save(_ data: CampfireWidgetData) { savedData = data }
}

private final class HistoryStoreSpy: DailyStatsHistoryStoring {
    var records: [DailyWalkingStats] = []

    func profileStartDate() -> Date { .distantPast }
    func loadHistory() -> [DailyWalkingStats] { records }
    func save(_ records: [DailyWalkingStats]) { self.records = records }
    func upsert(_ records: [DailyWalkingStats]) { self.records.append(contentsOf: records) }

    func lifetimeStats(from records: [DailyWalkingStats]) -> ProfileLifetimeStats {
        ProfileLifetimeStats(
            lifetimeSticks: records.reduce(0) { $0 + $1.sticksCollected },
            totalSteps: records.reduce(0) { $0 + $1.steps },
            totalActiveCalories: records.reduce(0) { $0 + $1.activeCalories },
            firesCompleted: records.filter(\.hasCompletedFire).count
        )
    }
}
