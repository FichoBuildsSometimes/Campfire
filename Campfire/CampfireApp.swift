import SwiftUI

@main
struct CampfireApp: App {
    @UIApplicationDelegateAdaptor(CampfireAppDelegate.self) private var appDelegate
    @State private var hasCompletedOnboarding: Bool

    init() {
        OnboardingStateStore.shared.migrateLegacyCompletionIfNeeded()
        CampfirePreferences.migrateLegacyReminderPreferenceIfNeeded()
        Self.configureForUITestingIfNeeded()
        _hasCompletedOnboarding = State(initialValue: OnboardingStateStore.shared.isCompleted)
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                HomeView {
                    OnboardingStateStore.shared.resetCompletion()
                    withAnimation(.easeInOut(duration: 0.28)) {
                        hasCompletedOnboarding = false
                    }
                }
            } else {
                OnboardingView {
                    OnboardingStateStore.shared.markCompleted()
                    withAnimation(.easeInOut(duration: 0.28)) {
                        hasCompletedOnboarding = true
                    }
                }
            }
        }
    }

    private static func configureForUITestingIfNeeded() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("--ui-testing-onboarding") {
            OnboardingStateStore.shared.resetCompletion()
            UserDefaults.standard.set(false, forKey: CampfirePreferences.remindersEnabledKey)
        } else if arguments.contains("--ui-testing-home") {
            OnboardingStateStore.shared.markCompleted()
        }
        #endif
    }
}
