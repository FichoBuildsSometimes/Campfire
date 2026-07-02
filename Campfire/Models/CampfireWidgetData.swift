import Foundation

struct CampfireWidgetData: Codable, Equatable {
    var stepsToday: Int
    var dailyStepGoal: Int
    var sticksCollected: Int
    var activeCalories: Int
    var fireCharge: Int
    var lastUpdated: Date

    init(
        stepsToday: Int,
        dailyStepGoal: Int,
        sticksCollected: Int,
        activeCalories: Int,
        fireCharge: Int,
        lastUpdated: Date
    ) {
        self.stepsToday = max(stepsToday, 0)
        self.dailyStepGoal = max(dailyStepGoal, 1)
        self.sticksCollected = min(max(sticksCollected, 0), 100)
        self.activeCalories = max(activeCalories, 0)
        self.fireCharge = min(max(fireCharge, 0), 100)
        self.lastUpdated = lastUpdated
    }

    init(stats: WalkingStats) {
        self.init(
            stepsToday: stats.stepsToday,
            dailyStepGoal: stats.dailyStepGoal,
            sticksCollected: stats.sticksCollected,
            activeCalories: stats.activeCalories,
            fireCharge: stats.fireCharge,
            lastUpdated: stats.lastUpdated
        )
    }

    static var mock: CampfireWidgetData {
        CampfireWidgetData(
            stepsToday: 8_642,
            dailyStepGoal: WalkingStats.defaultDailyStepGoal,
            sticksCollected: 86,
            activeCalories: 412,
            fireCharge: 86,
            lastUpdated: .now
        )
    }

    var stage: CampfireStage {
        CampfireStage(fireCharge: fireCharge)
    }

    var campfireStageImageName: String {
        stage.assetName
    }

    var formattedSteps: String {
        formatted(stepsToday)
    }

    var formattedCalories: String {
        formatted(activeCalories)
    }

    var formattedSticks: String {
        formatted(sticksCollected)
    }

    var formattedFireCharge: String {
        "\(fireCharge)%"
    }

    var stepsTitle: String {
        formattedSteps
    }

    var sticksTitle: String {
        formattedSticks
    }

    var activeCaloriesTitle: String {
        formattedCalories
    }

    var fireChargeTitle: String {
        formattedFireCharge
    }

    var isStale: Bool {
        isStale(relativeTo: .now)
    }

    var zeroedForStaleData: CampfireWidgetData {
        CampfireWidgetData(
            stepsToday: 0,
            dailyStepGoal: dailyStepGoal,
            sticksCollected: 0,
            activeCalories: 0,
            fireCharge: 0,
            lastUpdated: lastUpdated
        )
    }

    func isStale(relativeTo date: Date, calendar: Calendar = .current) -> Bool {
        !calendar.isDate(lastUpdated, inSameDayAs: date)
    }

    func widgetDisplayData(relativeTo date: Date = .now, calendar: Calendar = .current) -> CampfireWidgetData {
        isStale(relativeTo: date, calendar: calendar) ? zeroedForStaleData : self
    }

    private func formatted(_ value: Int) -> String {
        Self.numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        return formatter
    }()
}

enum WidgetDayPhase: Equatable {
    case day
    case night

    var appBackgroundAssetName: String {
        switch self {
        case .day:
            "background_day"
        case .night:
            "background_night"
        }
    }

    init(date: Date, calendar: Calendar = .current) {
        let hour = calendar.component(.hour, from: date)
        self = (6...18).contains(hour) ? .day : .night
    }

    static func nextTransition(after date: Date, calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let dayStart = calendar.date(byAdding: .hour, value: 6, to: startOfDay) ?? date.addingTimeInterval(60 * 60)
        let nightStart = calendar.date(byAdding: .hour, value: 19, to: startOfDay) ?? date.addingTimeInterval(60 * 60)

        if date < dayStart {
            return dayStart
        }

        if date < nightStart {
            return nightStart
        }

        return calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date.addingTimeInterval(60 * 60)
    }
}
