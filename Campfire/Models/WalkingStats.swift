import Foundation

struct WalkingStats: Codable, Equatable {
    static let defaultDailyStepGoal = 7_500

    var stepsToday: Int
    var dailyStepGoal: Int
    var sticksCollected: Int
    var activeCalories: Int
    var fireCharge: Int
    var lastUpdated: Date

    init(
        stepsToday: Int = 0,
        dailyStepGoal: Int = Self.defaultDailyStepGoal,
        activeCalories: Int = 0,
        lastUpdated: Date = .now
    ) {
        let normalizedGoal = max(dailyStepGoal, 1)
        let normalizedSteps = max(stepsToday, 0)
        let normalizedCalories = max(activeCalories, 0)
        let stepsPerStick = max(normalizedGoal / 100, 1)

        self.stepsToday = normalizedSteps
        self.dailyStepGoal = normalizedGoal
        self.sticksCollected = min(max(normalizedSteps / stepsPerStick, 0), 100)
        self.activeCalories = normalizedCalories
        self.fireCharge = min(max(Int(floor((Double(normalizedSteps) / Double(normalizedGoal)) * 100)), 0), 100)
        self.lastUpdated = lastUpdated
    }

    var stepsPerStick: Int {
        max(dailyStepGoal / 100, 1)
    }

    static let empty = WalkingStats()

    static let mock = WalkingStats(
        stepsToday: 8_642,
        activeCalories: 412,
        lastUpdated: Date(timeIntervalSince1970: 1_717_672_400)
    )
}

enum CampfirePreferences {
    static let dailyStepGoalKey = "dailyStepGoal"
    static let reminderPreferenceKey = "reminderPreference"
    static let remindersEnabledKey = "remindersEnabled"
    static let reminderHourKey = "reminderHour"
    static let reminderMinuteKey = "reminderMinute"
    static let reminderPreferenceMigrationKey = "reminderPreferenceMigrationCompleted"
    static let defaultReminderPreference = "evening"
    static let defaultReminderHour = 19
    static let defaultReminderMinute = 0
    static let minimumDailyStepGoal = 1_000
    static let maximumDailyStepGoal = 50_000

    static func clampedDailyStepGoal(_ value: Int) -> Int {
        min(max(value, minimumDailyStepGoal), maximumDailyStepGoal)
    }

    static func savedDailyStepGoal(defaults: UserDefaults = .standard) -> Int {
        guard defaults.object(forKey: dailyStepGoalKey) != nil else {
            return WalkingStats.defaultDailyStepGoal
        }

        return clampedDailyStepGoal(defaults.integer(forKey: dailyStepGoalKey))
    }

    static func migrateLegacyReminderPreferenceIfNeeded(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: reminderPreferenceMigrationKey) else { return }

        guard let preference = defaults.string(forKey: reminderPreferenceKey) else {
            if defaults.object(forKey: remindersEnabledKey) == nil {
                defaults.set(false, forKey: remindersEnabledKey)
            }

            if defaults.object(forKey: reminderHourKey) == nil {
                defaults.set(defaultReminderHour, forKey: reminderHourKey)
            }

            if defaults.object(forKey: reminderMinuteKey) == nil {
                defaults.set(defaultReminderMinute, forKey: reminderMinuteKey)
            }

            defaults.set(true, forKey: reminderPreferenceMigrationKey)
            return
        }

        let migrated: (enabled: Bool, hour: Int, minute: Int)

        switch preference {
        case "morning":
            migrated = (true, 9, 0)
        case "afternoon":
            migrated = (true, 14, 0)
        case "none":
            migrated = (false, defaultReminderHour, defaultReminderMinute)
        default:
            migrated = (true, defaultReminderHour, defaultReminderMinute)
        }

        if defaults.object(forKey: remindersEnabledKey) == nil {
            defaults.set(migrated.enabled, forKey: remindersEnabledKey)
        }

        if defaults.object(forKey: reminderHourKey) == nil {
            defaults.set(migrated.hour, forKey: reminderHourKey)
        }

        if defaults.object(forKey: reminderMinuteKey) == nil {
            defaults.set(migrated.minute, forKey: reminderMinuteKey)
        }

        defaults.set(true, forKey: reminderPreferenceMigrationKey)
    }

    static func clampedReminderHour(_ value: Int) -> Int {
        min(max(value, 0), 23)
    }

    static func clampedReminderMinute(_ value: Int) -> Int {
        min(max(value, 0), 59)
    }
}
