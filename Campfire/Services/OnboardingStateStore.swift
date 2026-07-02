import Foundation

struct OnboardingStateStore {
    static let shared = OnboardingStateStore()
    static let completedKey = "hasCompletedOnboarding"

    private static let legacyCompletedKey = "campfire_onboarding_completed"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isCompleted: Bool {
        defaults.bool(forKey: Self.completedKey) || defaults.bool(forKey: Self.legacyCompletedKey)
    }

    func migrateLegacyCompletionIfNeeded() {
        guard defaults.bool(forKey: Self.legacyCompletedKey),
              !defaults.bool(forKey: Self.completedKey) else {
            return
        }

        defaults.set(true, forKey: Self.completedKey)
    }

    func markCompleted() {
        defaults.set(true, forKey: Self.completedKey)
    }

    func resetCompletion() {
        defaults.set(false, forKey: Self.completedKey)
        defaults.set(false, forKey: Self.legacyCompletedKey)
    }
}
