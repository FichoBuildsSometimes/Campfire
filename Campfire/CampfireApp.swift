import SwiftUI

@main
struct CampfireApp: App {
    @UIApplicationDelegateAdaptor(CampfireAppDelegate.self) private var appDelegate
    @AppStorage(OnboardingStateStore.completedKey) private var hasCompletedOnboarding = false

    init() {
        OnboardingStateStore.shared.migrateLegacyCompletionIfNeeded()
        CampfirePreferences.migrateLegacyReminderPreferenceIfNeeded()
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
}
