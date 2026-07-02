import SwiftUI
import UserNotifications

struct SettingsView: View {
    var viewModel: HomeViewModel
    var bottomPadding: CGFloat
    var onResetOnboarding: () -> Void

    @AppStorage(CampfirePreferences.dailyStepGoalKey) private var dailyStepGoal = WalkingStats.defaultDailyStepGoal
    @AppStorage(CampfirePreferences.remindersEnabledKey) private var remindersEnabled = false
    @AppStorage(CampfirePreferences.reminderHourKey) private var reminderHour = CampfirePreferences.defaultReminderHour
    @AppStorage(CampfirePreferences.reminderMinuteKey) private var reminderMinute = CampfirePreferences.defaultReminderMinute

    @State private var isUsingCustomGoal = false
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var reminderMessage: String?
    @State private var isUpdatingReminder = false

    private let reminderService = ReminderNotificationService.shared

    init(
        viewModel: HomeViewModel,
        bottomPadding: CGFloat = 116,
        onResetOnboarding: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.bottomPadding = bottomPadding
        self.onResetOnboarding = onResetOnboarding
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = min(max(proxy.size.width - 44, 288), 360)

            ZStack {
                settingsBackground(size: proxy.size)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        dailyGoalCard
                        reminderCard
                        healthCard
                        otherPreferencesCard
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.top, max(proxy.safeAreaInsets.top + 22, 72))
                    .padding(.bottom, bottomPadding)
                    .frame(width: proxy.size.width)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .task {
            normalizeStoredSettings()
            await refreshAuthorizationStatus()
        }
        .onChange(of: dailyStepGoal) { _, newGoal in
            dailyStepGoal = CampfirePreferences.clampedDailyStepGoal(newGoal)
            isUsingCustomGoal = !DailyGoalSelectionView.presetGoals.contains(dailyStepGoal)
            viewModel.updateDailyStepGoal(dailyStepGoal)
        }
        .onChange(of: reminderHour) { _, _ in
            Task { await rescheduleReminderIfNeeded() }
        }
        .onChange(of: reminderMinute) { _, _ in
            Task { await rescheduleReminderIfNeeded() }
        }
    }

    private func settingsBackground(size: CGSize) -> some View {
        ZStack {
            AppTheme.Palette.navyInk

            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                Image(WidgetDayPhase(date: timeline.date).appBackgroundAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .opacity(0.28)
                    .clipped()
            }

            LinearGradient(
                colors: [
                    AppTheme.Palette.navyInk.opacity(0.62),
                    AppTheme.Palette.forestDeep.opacity(0.76),
                    AppTheme.Palette.navyInk
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Palette.cream)
                    .lineLimit(1)

                Text("Tune your campfire routine.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.creamMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 8)

            Image(systemName: "gearshape.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.Palette.emberGold)
                .frame(width: 52, height: 52)
                .background(.ultraThinMaterial, in: Circle())
                .background(AppTheme.Palette.ember.opacity(0.13), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        }
    }

    private var dailyGoalCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "Daily Steps",
                    subtitle: "This goal controls sticks, fire charge, and widgets.",
                    systemImage: "figure.walk"
                )

                DailyGoalSelectionView(
                    dailyStepGoal: $dailyStepGoal,
                    isUsingCustomGoal: $isUsingCustomGoal
                )
            }
        }
    }

    private var reminderCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "Daily Reminder",
                    subtitle: reminderSummary,
                    systemImage: "bell.badge.fill"
                )

                HStack(spacing: 12) {
                    Text("Reminder time")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.Palette.cream)

                    Spacer()

                    DatePicker("Reminder time", selection: reminderDateBinding, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(AppTheme.Palette.emberGold)
                        .disabled(isUpdatingReminder)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppTheme.Palette.navyInk.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    Task {
                        canDisableReminders ? await disableReminders() : await enableReminders()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: canDisableReminders ? "bell.slash.fill" : "bell.fill")
                            .font(.system(size: 14, weight: .bold))

                        Text(isUpdatingReminder ? "Updating..." : reminderButtonTitle)
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(canDisableReminders ? AppTheme.Palette.cream : AppTheme.Palette.navyInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        canDisableReminders ? AppTheme.Palette.navyInk.opacity(0.34) : AppTheme.Palette.cream,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(AppTheme.Palette.glassStroke, lineWidth: canDisableReminders ? 1 : 0)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isUpdatingReminder)

                if let reminderMessage {
                    Text(reminderMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.creamMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var healthCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "Apple Health",
                    subtitle: viewModel.healthStatusMessage,
                    systemImage: "heart.text.square.fill"
                )

                Button {
                    Task {
                        await viewModel.connectHealth()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14, weight: .bold))

                        Text(viewModel.showsConnectHealthButton ? "Connect Apple Health" : "Refresh Health Access")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(AppTheme.Palette.navyInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.Palette.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.healthState == .loading)
            }
        }
    }

    private var otherPreferencesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "Other Preferences",
                    subtitle: "Small controls for testing and setup.",
                    systemImage: "slider.horizontal.3"
                )

                #if DEBUG
                Button {
                    onResetOnboarding()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .bold))

                        Text("Reset Onboarding")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(AppTheme.Palette.cream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.Palette.navyInk.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(AppTheme.Palette.glassStroke, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                #else
                Text("More campfire preferences will live here as the app grows.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.creamMuted)
                    .fixedSize(horizontal: false, vertical: true)
                #endif
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.Palette.emberGold)
                .frame(width: 32, height: 32)
                .background(AppTheme.Palette.ember.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.Palette.cream)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.creamMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var reminderButtonTitle: String {
        canDisableReminders ? "Disable reminders" : "Enable reminders"
    }

    private var canDisableReminders: Bool {
        remindersEnabled && authorizationStatus.allowsScheduling
    }

    private var reminderSummary: String {
        if remindersEnabled && authorizationStatus.allowsScheduling {
            return "Scheduled daily at \(formattedReminderTime)."
        }

        if remindersEnabled {
            return "Notifications need permission before reminders can run."
        }

        if authorizationStatus == .denied {
            return "Notifications are off in iOS Settings."
        }

        return "Pick a time and enable a cozy nudge."
    }

    private var formattedReminderTime: String {
        Self.timeFormatter.string(from: reminderDate)
    }

    private var reminderDateBinding: Binding<Date> {
        Binding(
            get: { reminderDate },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderHour = CampfirePreferences.clampedReminderHour(components.hour ?? CampfirePreferences.defaultReminderHour)
                reminderMinute = CampfirePreferences.clampedReminderMinute(components.minute ?? CampfirePreferences.defaultReminderMinute)
            }
        )
    }

    private var reminderDate: Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        components.hour = CampfirePreferences.clampedReminderHour(reminderHour)
        components.minute = CampfirePreferences.clampedReminderMinute(reminderMinute)
        return Calendar.current.date(from: components) ?? .now
    }

    private func normalizeStoredSettings() {
        dailyStepGoal = CampfirePreferences.clampedDailyStepGoal(dailyStepGoal)
        reminderHour = CampfirePreferences.clampedReminderHour(reminderHour)
        reminderMinute = CampfirePreferences.clampedReminderMinute(reminderMinute)
        isUsingCustomGoal = !DailyGoalSelectionView.presetGoals.contains(dailyStepGoal)
    }

    private func refreshAuthorizationStatus() async {
        authorizationStatus = await reminderService.authorizationStatus()
        updateReminderMessage()
    }

    private func enableReminders() async {
        isUpdatingReminder = true
        defer { isUpdatingReminder = false }

        let status = await reminderService.authorizationStatus()
        let isAllowed: Bool

        if status == .notDetermined {
            isAllowed = await reminderService.requestAuthorization()
        } else {
            isAllowed = status.allowsScheduling
        }

        authorizationStatus = await reminderService.authorizationStatus()

        guard isAllowed || authorizationStatus.allowsScheduling else {
            remindersEnabled = false
            reminderService.cancelDailyReminder()
            reminderMessage = "Notifications are denied. You can enable them later in iOS Settings."
            return
        }

        do {
            try await reminderService.scheduleDailyReminder(hour: reminderHour, minute: reminderMinute)
            remindersEnabled = true
            reminderMessage = "Reminder scheduled for \(formattedReminderTime)."
        } catch {
            remindersEnabled = false
            reminderMessage = "Could not schedule the reminder. Please try again."
        }
    }

    private func disableReminders() async {
        reminderService.cancelDailyReminder()
        remindersEnabled = false
        authorizationStatus = await reminderService.authorizationStatus()
        reminderMessage = "Daily reminders are off."
    }

    private func rescheduleReminderIfNeeded() async {
        guard remindersEnabled else { return }

        isUpdatingReminder = true
        defer { isUpdatingReminder = false }

        authorizationStatus = await reminderService.authorizationStatus()

        guard authorizationStatus.allowsScheduling else {
            remindersEnabled = false
            reminderService.cancelDailyReminder()
            reminderMessage = "Notifications are denied. You can enable them later in iOS Settings."
            return
        }

        do {
            try await reminderService.scheduleDailyReminder(hour: reminderHour, minute: reminderMinute)
            reminderMessage = "Reminder rescheduled for \(formattedReminderTime)."
        } catch {
            reminderMessage = "Could not reschedule the reminder. Please try again."
        }
    }

    private func updateReminderMessage() {
        if remindersEnabled {
            reminderMessage = authorizationStatus.allowsScheduling
            ? "Reminder scheduled for \(formattedReminderTime)."
            : "Notifications need permission before reminders can run."
        } else if authorizationStatus == .denied {
            reminderMessage = "Notifications are denied. You can enable them later in iOS Settings."
        } else {
            reminderMessage = nil
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

private extension UNAuthorizationStatus {
    var allowsScheduling: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        case .denied, .notDetermined:
            false
        @unknown default:
            false
        }
    }
}

#Preview("Settings") {
    SettingsView(viewModel: HomeViewModel.preview())
}
