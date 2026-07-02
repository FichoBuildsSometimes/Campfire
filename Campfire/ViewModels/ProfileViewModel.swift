import Foundation
import HealthKit
import Observation
import OSLog

@Observable
final class ProfileViewModel {
    enum HealthConnectionState: Equatable {
        case idle
        case loading
        case needsAuthorization
        case unavailable
        case ready
        case failed(String)
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()

    private static let logger = Logger(subsystem: "com.ficho.Campfire", category: "ProfileViewModel")

    var selectedRange: ProfileChartRange = .week {
        didSet {
            rebuildChartData()
        }
    }

    var healthState: HealthConnectionState = .idle
    var lifetimeStats: ProfileLifetimeStats = .empty
    var chartPoints: [StepChartPoint] = []
    var periodTotalSteps = 0
    var periodAverageSteps = 0

    @ObservationIgnored private let healthKitService: any HealthKitServiceProtocol
    @ObservationIgnored private let historyStore: any DailyStatsHistoryStoring
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let profileStartDate: Date
    @ObservationIgnored private var history: [DailyWalkingStats] = []
    @ObservationIgnored private var isRefreshInFlight = false
    @ObservationIgnored private var hasLoadedOnce = false
    @ObservationIgnored private var refreshedRanges: Set<ProfileChartRange> = []

    init(
        healthKitService: any HealthKitServiceProtocol = HealthKitService(),
        historyStore: any DailyStatsHistoryStoring = DailyStatsHistoryStore.shared,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { Date() }
    ) {
        self.healthKitService = healthKitService
        self.historyStore = historyStore
        self.calendar = calendar
        self.now = now
        self.profileStartDate = calendar.startOfDay(for: historyStore.profileStartDate())
    }

    var hasWalkingData: Bool {
        history.contains { $0.hasActivity }
    }

    var showsEmptyState: Bool {
        healthState != .loading && !hasWalkingData
    }

    var showsHealthCard: Bool {
        switch healthState {
        case .idle, .needsAuthorization, .unavailable, .failed:
            return true
        case .loading, .ready:
            return false
        }
    }

    var showsConnectHealthButton: Bool {
        switch healthState {
        case .idle, .needsAuthorization, .failed:
            return true
        case .loading, .ready, .unavailable:
            return false
        }
    }

    var healthCardTitle: String {
        switch healthState {
        case .unavailable:
            return "Apple Health is unavailable"
        case .failed:
            return "Apple Health needs attention"
        default:
            return "Connect Apple Health"
        }
    }

    var healthCardMessage: String {
        switch healthState {
        case .unavailable:
            return "Apple Health is not available on this device."
        case .failed(let message):
            return message
        default:
            return "Connect Apple Health to see your progress history."
        }
    }

    var loadingTitle: String? {
        healthState == .loading ? "Refreshing Apple Health..." : nil
    }

    var lifetimeSticksTitle: String {
        formatted(lifetimeStats.lifetimeSticks)
    }

    var totalStepsTitle: String {
        formatted(lifetimeStats.totalSteps)
    }

    var totalCaloriesTitle: String {
        formatted(lifetimeStats.totalActiveCalories)
    }

    var firesCompletedTitle: String {
        formatted(lifetimeStats.firesCompleted)
    }

    var bestStreakTitle: String {
        lifetimeStats.bestStreak > 0 ? "\(lifetimeStats.bestStreak)d" : "--"
    }

    var currentStreakTitle: String {
        lifetimeStats.currentStreak > 0 ? "\(lifetimeStats.currentStreak) day streak" : "Streak --"
    }

    var periodTotalTitle: String {
        formatted(periodTotalSteps)
    }

    var periodAverageTitle: String {
        formatted(periodAverageSteps)
    }

    @MainActor
    func loadOnAppearIfNeeded() async {
        guard !hasLoadedOnce else {
            return
        }

        hasLoadedOnce = true
        loadSavedHistory()

        guard healthKitService.isHealthDataAvailable else {
            healthState = .unavailable
            return
        }

        do {
            let status = try await healthKitService.authorizationRequestStatus()

            switch status {
            case .shouldRequest, .unknown:
                healthState = .needsAuthorization
            case .unnecessary:
                await refreshSelectedRangeIfNeeded()
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
            try await refreshHistoryAfterAuthorization()
            healthState = .ready
        } catch {
            applyFailureState(error)
        }

        isRefreshInFlight = false
    }

    @MainActor
    func refreshFromUserGesture() async {
        guard !isRefreshInFlight else { return }

        guard healthKitService.isHealthDataAvailable else {
            healthState = .unavailable
            return
        }

        do {
            let status = try await healthKitService.authorizationRequestStatus()

            switch status {
            case .shouldRequest, .unknown:
                healthState = .needsAuthorization
            case .unnecessary:
                await refreshSelectedRangeIfNeeded(force: true)
            @unknown default:
                healthState = .needsAuthorization
            }
        } catch {
            applyFailureState(error)
        }
    }

    @MainActor
    func refreshSelectedRangeIfNeeded(force: Bool = false) async {
        guard !isRefreshInFlight else { return }
        guard force || !refreshedRanges.contains(selectedRange) else { return }

        isRefreshInFlight = true
        healthState = .loading

        do {
            try await refreshHistoryAfterAuthorization()
            healthState = .ready
        } catch {
            applyFailureState(error)
        }

        isRefreshInFlight = false
    }

    @MainActor
    private func refreshHistoryAfterAuthorization() async throws {
        let range = selectedRange
        let startDate = refreshStartDate(for: range)
        Self.logger.debug("HealthKit profile refresh start: range=\(range.rawValue, privacy: .public)")

        let records = try await healthKitService.fetchDailyTotals(
            startDate: startDate,
            endDate: now()
        )

        if records.contains(where: { $0.hasActivity }) || history.isEmpty {
            historyStore.upsert(records)
        }

        loadSavedHistory()
        refreshedRanges.insert(range)
        Self.logger.debug("HealthKit profile refresh end: range=\(range.rawValue, privacy: .public), records=\(records.count)")
    }

    @MainActor
    private func loadSavedHistory() {
        history = historyStore.loadHistory().filter { $0.date >= profileStartDate }
        recalculate()
    }

    @MainActor
    private func applyFailureState(_ error: Error) {
        if let healthKitError = error as? HealthKitServiceError,
           case .healthDataUnavailable = healthKitError {
            healthState = .unavailable
            return
        }

        healthState = .failed(
            error.localizedDescription.isEmpty
            ? "Connect Apple Health to see your progress history."
            : error.localizedDescription
        )
    }

    private func recalculate() {
        lifetimeStats = historyStore.lifetimeStats(from: history)
        rebuildChartData()
    }

    private func rebuildChartData() {
        switch selectedRange {
        case .week:
            chartPoints = dailyChartPoints(dayCount: 7, formatter: Self.weekdayFormatter)
        case .month:
            chartPoints = dailyChartPoints(dayCount: 30, formatter: Self.dayFormatter)
        case .year:
            chartPoints = monthlyChartPoints()
        }

        periodTotalSteps = chartPoints.reduce(0) { $0 + $1.steps }
        periodAverageSteps = chartPoints.isEmpty ? 0 : periodTotalSteps / chartPoints.count
    }

    private func dailyChartPoints(dayCount: Int, formatter: DateFormatter) -> [StepChartPoint] {
        let recordsByDay = Dictionary(
            uniqueKeysWithValues: history.map { (calendar.startOfDay(for: $0.date), $0) }
        )
        let endDay = calendar.startOfDay(for: now())
        let rangeStartDay = calendar.date(byAdding: .day, value: -(dayCount - 1), to: endDay) ?? endDay
        let startDay = max(rangeStartDay, profileStartDate)

        return days(from: startDay, through: endDay).map { date in
            StepChartPoint(
                label: formatter.string(from: date),
                steps: recordsByDay[date]?.steps ?? 0,
                date: date
            )
        }
    }

    private func monthlyChartPoints() -> [StepChartPoint] {
        let currentMonth = monthStart(for: now())
        let rangeStartMonth = calendar.date(byAdding: .month, value: -11, to: currentMonth) ?? currentMonth
        let startMonth = max(rangeStartMonth, monthStart(for: profileStartDate))

        return months(from: startMonth, through: currentMonth).compactMap { month in
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: month) else { return nil }

            let steps = history
                .filter { $0.date >= month && $0.date < nextMonth }
                .reduce(0) { $0 + $1.steps }

            return StepChartPoint(
                label: Self.monthFormatter.string(from: month),
                steps: steps,
                date: month
            )
        }
    }

    private func months(from startDate: Date, through endDate: Date) -> [Date] {
        var dates: [Date] = []
        var currentDate = startDate

        while currentDate <= endDate {
            dates.append(currentDate)

            guard let nextDate = calendar.date(byAdding: .month, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return dates
    }

    private func days(from startDate: Date, through endDate: Date) -> [Date] {
        var dates: [Date] = []
        var currentDate = startDate

        while currentDate <= endDate {
            dates.append(currentDate)

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return dates
    }

    private func refreshStartDate(for range: ProfileChartRange) -> Date {
        let today = calendar.startOfDay(for: now())
        let rangeStartDate: Date

        switch range {
        case .week:
            rangeStartDate = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        case .month:
            rangeStartDate = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        case .year:
            rangeStartDate = historicalStartDate()
        }

        return max(rangeStartDate, profileStartDate)
    }

    private func historicalStartDate() -> Date {
        calendar.date(byAdding: .month, value: -11, to: monthStart(for: now())) ?? calendar.startOfDay(for: now())
    }

    private func monthStart(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private func formatted(_ value: Int) -> String {
        Self.numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private final class PreviewDailyStatsHistoryStore: DailyStatsHistoryStoring {
    private var records: [DailyWalkingStats]
    private let calendar: Calendar
    private let startDate: Date

    init(records: [DailyWalkingStats], calendar: Calendar = .current) {
        self.records = records
        self.calendar = calendar
        self.startDate = records.map(\.date).min().map { calendar.startOfDay(for: $0) } ?? calendar.startOfDay(for: Date())
    }

    func profileStartDate() -> Date {
        startDate
    }

    func loadHistory() -> [DailyWalkingStats] {
        records.filter { $0.date >= startDate }
    }

    func save(_ records: [DailyWalkingStats]) {
        self.records = records.filter { $0.date >= startDate }
    }

    func upsert(_ records: [DailyWalkingStats]) {
        var recordsByDay = Dictionary(
            uniqueKeysWithValues: self.records.map { (calendar.startOfDay(for: $0.date), $0) }
        )

        for record in records {
            recordsByDay[calendar.startOfDay(for: record.date)] = record
        }

        self.records = recordsByDay.values
            .filter { $0.date >= startDate }
            .sorted { $0.date < $1.date }
    }

    func lifetimeStats(from records: [DailyWalkingStats]) -> ProfileLifetimeStats {
        ProfileLifetimeStats(
            lifetimeSticks: records.reduce(0) { $0 + $1.sticksCollected },
            totalSteps: records.reduce(0) { $0 + $1.steps },
            totalActiveCalories: records.reduce(0) { $0 + $1.activeCalories },
            firesCompleted: records.filter(\.hasCompletedFire).count,
            bestStreak: 0
        )
    }
}

private struct PreviewProfileHealthKitService: HealthKitServiceProtocol {
    var records: [DailyWalkingStats]

    var isHealthDataAvailable: Bool {
        true
    }

    func authorizationRequestStatus() async throws -> HKAuthorizationRequestStatus {
        .unnecessary
    }

    func requestAuthorization() async throws {}

    func fetchTodayTotals() async throws -> HealthKitDailyTotals {
        let latest = records.last
        return HealthKitDailyTotals(
            stepsToday: latest?.steps ?? 0,
            activeCalories: latest?.activeCalories ?? 0
        )
    }

    func fetchDailyTotals(startDate: Date, endDate: Date) async throws -> [DailyWalkingStats] {
        records.filter { $0.date >= startDate && $0.date <= endDate }
    }
}

extension ProfileViewModel {
    static func preview() -> ProfileViewModel {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let records = (0..<60).compactMap { offset -> DailyWalkingStats? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }

            let steps = 2_400 + ((offset * 1_137) % 10_800)
            let calories = 110 + ((offset * 37) % 420)

            return DailyWalkingStats(
                date: date,
                steps: steps,
                activeCalories: calories
            )
        }

        let viewModel = ProfileViewModel(
            healthKitService: PreviewProfileHealthKitService(records: records),
            historyStore: PreviewDailyStatsHistoryStore(records: records),
            calendar: calendar,
            now: { Date() }
        )
        viewModel.history = records
        viewModel.healthState = .ready
        viewModel.recalculate()
        return viewModel
    }
}
