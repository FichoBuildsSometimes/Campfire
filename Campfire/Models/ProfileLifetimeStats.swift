import Foundation

struct ProfileLifetimeStats: Equatable {
    let lifetimeSticks: Int
    let totalSteps: Int
    let totalActiveCalories: Int
    let firesCompleted: Int
    let currentStreak: Int
    let bestStreak: Int

    static let empty = ProfileLifetimeStats(
        lifetimeSticks: 0,
        totalSteps: 0,
        totalActiveCalories: 0,
        firesCompleted: 0,
        currentStreak: 0,
        bestStreak: 0
    )

    init(
        lifetimeSticks: Int,
        totalSteps: Int,
        totalActiveCalories: Int,
        firesCompleted: Int,
        currentStreak: Int = 0,
        bestStreak: Int = 0
    ) {
        self.lifetimeSticks = max(lifetimeSticks, 0)
        self.totalSteps = max(totalSteps, 0)
        self.totalActiveCalories = max(totalActiveCalories, 0)
        self.firesCompleted = max(firesCompleted, 0)
        self.currentStreak = max(currentStreak, 0)
        self.bestStreak = max(bestStreak, 0)
    }
}
