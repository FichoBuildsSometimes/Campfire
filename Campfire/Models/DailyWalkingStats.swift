import Foundation

struct DailyWalkingStats: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let steps: Int
    let activeCalories: Int
    let sticksCollected: Int
    let fireCharge: Int
    let dailyStepGoal: Int

    init(
        id: UUID = UUID(),
        date: Date,
        steps: Int,
        activeCalories: Int,
        dailyStepGoal: Int = WalkingStats.defaultDailyStepGoal
    ) {
        let normalizedGoal = max(dailyStepGoal, 1)
        let normalizedSteps = max(steps, 0)
        let normalizedCalories = max(activeCalories, 0)
        let stepsPerStick = max(normalizedGoal / 100, 1)

        self.id = id
        self.date = date
        self.steps = normalizedSteps
        self.activeCalories = normalizedCalories
        self.dailyStepGoal = normalizedGoal
        self.sticksCollected = min(max(normalizedSteps / stepsPerStick, 0), 100)
        self.fireCharge = min(max(Int(floor((Double(normalizedSteps) / Double(normalizedGoal)) * 100)), 0), 100)
    }

    var hasActivity: Bool {
        steps > 0 || activeCalories > 0 || sticksCollected > 0 || fireCharge > 0
    }

    var hasCompletedFire: Bool {
        fireCharge >= 100
    }
}
