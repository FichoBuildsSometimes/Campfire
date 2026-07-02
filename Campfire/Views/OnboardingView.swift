import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @AppStorage(CampfirePreferences.dailyStepGoalKey) private var dailyStepGoal = WalkingStats.defaultDailyStepGoal
    @AppStorage(CampfirePreferences.remindersEnabledKey) private var remindersEnabled = false
    @AppStorage(CampfirePreferences.reminderHourKey) private var reminderHour = CampfirePreferences.defaultReminderHour
    @AppStorage(CampfirePreferences.reminderMinuteKey) private var reminderMinute = CampfirePreferences.defaultReminderMinute

    @State private var viewModel: HomeViewModel
    @State private var currentStep: OnboardingStep = .welcome
    @State private var isUsingCustomGoal = false
    @State private var hasAttemptedHealthConnection = false
    @State private var reminderAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var reminderMessage: String?
    @State private var isUpdatingReminder = false

    private let reminderService = ReminderNotificationService.shared

    var onComplete: () -> Void

    init(
        viewModel: HomeViewModel = HomeViewModel(),
        onComplete: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onComplete = onComplete
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = min(max(proxy.size.width - 44, 288), 360)
            let topPadding = contentTopPadding(for: proxy.safeAreaInsets)
            let bottomPadding = controlsBottomPadding(for: proxy.safeAreaInsets)
            let contentBottomPadding = scrollContentBottomPadding
            let contentMinHeight = centeredContentHeight(
                in: proxy.size,
                topPadding: topPadding,
                bottomPadding: bottomPadding,
                scrollBottomPadding: contentBottomPadding
            )

            ZStack {
                background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: currentStep.isDense ? 14 : 22) {
                            if currentStep.showsMascot {
                                mascot(width: contentWidth)
                            }

                            stepContent
                                .frame(width: contentWidth)
                                .id(currentStep)
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                                        removal: .opacity.combined(with: .move(edge: .leading))
                                    )
                                )
                        }
                        .frame(width: contentWidth)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: contentMinHeight, alignment: .center)
                        .padding(.top, topPadding)
                        .padding(.bottom, contentBottomPadding)
                    }

                    VStack(spacing: 14) {
                        progressDots
                        controls
                    }
                    .frame(width: contentWidth)
                    .padding(.top, 10)
                    .padding(.bottom, bottomPadding)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(AppTheme.Palette.navyInk.ignoresSafeArea())
        }
        .onAppear {
            dailyStepGoal = CampfirePreferences.clampedDailyStepGoal(dailyStepGoal)
            reminderHour = CampfirePreferences.clampedReminderHour(reminderHour)
            reminderMinute = CampfirePreferences.clampedReminderMinute(reminderMinute)
            isUsingCustomGoal = !DailyGoalSelectionView.presetGoals.contains(dailyStepGoal)
        }
        .task {
            reminderAuthorizationStatus = await reminderService.authorizationStatus()
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: currentStep)
    }

    private func contentTopPadding(for safeAreaInsets: EdgeInsets) -> CGFloat {
        if currentStep.isDense {
            return max(safeAreaInsets.top + 12, 68)
        }

        return max(safeAreaInsets.top + 22, 82)
    }

    private func controlsBottomPadding(for safeAreaInsets: EdgeInsets) -> CGFloat {
        max(safeAreaInsets.bottom + 18, 30)
    }

    private func centeredContentHeight(
        in size: CGSize,
        topPadding: CGFloat,
        bottomPadding: CGFloat,
        scrollBottomPadding: CGFloat
    ) -> CGFloat {
        let availableHeight = size.height - topPadding - bottomPadding - controlsReservedHeight - scrollBottomPadding
        return max(availableHeight, currentStep.isDense ? 330 : 400)
    }

    private var controlsReservedHeight: CGFloat {
        switch currentStep {
        case .welcome:
            96
        case .goal, .sticks, .reminder:
            156
        case .health, .final:
            128
        }
    }

    private var scrollContentBottomPadding: CGFloat {
        currentStep.isDense ? 22 : 12
    }

    private var background: some View {
        ZStack {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                Image(WidgetDayPhase(date: timeline.date).appBackgroundAssetName)
                    .resizable()
                    .scaledToFill()
            }

            LinearGradient(
                colors: [
                    AppTheme.Palette.navyInk.opacity(0.72),
                    AppTheme.Palette.forestDeep.opacity(0.54),
                    AppTheme.Palette.navyInk.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func mascot(width: CGFloat) -> some View {
        AnimatedCampfireView(
            stage: mascotStage,
            progress: mascotProgress,
            isGoalCompleted: currentStep == .final,
            isUpgrading: false,
            sticksEarned: 0,
            size: currentStep.isDense ? min(width * 0.34, 118) : min(width * 0.50, 184)
        )
        .frame(width: width, height: currentStep.isDense ? 104 : 178)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            OnboardingPageView(
                systemImage: "flame.fill",
                title: "Welcome to Campfire",
                message: "Every walk fuels your campfire. Reach your daily goal, collect sticks, and keep the flame alive."
            )
        case .goal:
            VStack(spacing: 18) {
                OnboardingPageView(
                    systemImage: "figure.walk.circle.fill",
                    title: "Choose your daily goal",
                    message: "Pick a step goal that feels realistic. You can change this later."
                )

                DailyGoalSelectionView(
                    dailyStepGoal: $dailyStepGoal,
                    isUsingCustomGoal: $isUsingCustomGoal
                )
            }
        case .sticks:
            VStack(spacing: 18) {
                OnboardingPageView(
                    systemImage: "tree.fill",
                    title: "Collect sticks as you walk",
                    message: "Every 1% of your daily goal gives you 1 stick. Reach your goal to earn 100 sticks and fully fuel your campfire.",
                    accent: AppTheme.Palette.forestMuted
                )

                VStack(spacing: 10) {
                    OnboardingStatRow(title: "1% progress", value: "+1 stick", systemImage: "plus.circle.fill")
                    OnboardingStatRow(title: "100% progress", value: "100 sticks", systemImage: "flame.fill")
                    OnboardingStatRow(title: "More sticks", value: "stronger fire", systemImage: "sparkles")
                }
            }
        case .health:
            healthStep
        case .reminder:
            VStack(spacing: 18) {
                OnboardingPageView(
                    systemImage: "bell.badge.fill",
                    title: "When should Campfire remind you?",
                    message: "Pick a time for a cozy daily nudge. You can change this later in Settings.",
                    accent: AppTheme.Palette.ember
                )

                reminderStepControls
            }
        case .final:
            OnboardingPageView(
                systemImage: "checkmark.seal.fill",
                title: "Your campfire is ready",
                message: "Walk today to make it grow."
            )
        }
    }

    private var healthStep: some View {
        VStack(spacing: 18) {
            OnboardingPageView(
                systemImage: "heart.text.square.fill",
                title: "Connect Apple Health",
                message: "Campfire uses Apple Health to read your steps and walking activity. Your data stays private and is only used to fuel your campfire.",
                accent: AppTheme.Palette.forestMuted
            )

            Button {
                hasAttemptedHealthConnection = true

                Task {
                    await viewModel.connectHealth()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14, weight: .bold))

                    Text(connectButtonTitle)
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(AppTheme.Palette.navyInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(AppTheme.Palette.cream, in: RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.healthState == .loading)

            if hasAttemptedHealthConnection || viewModel.healthState == .unavailable {
                Text(healthFootnote)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(healthFootnoteColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }
        }
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases) { step in
                Capsule()
                    .fill(step == currentStep ? AppTheme.Palette.emberGold : AppTheme.Palette.cream.opacity(0.28))
                    .frame(width: step == currentStep ? 22 : 7, height: 7)
            }
        }
        .accessibilityLabel("Onboarding step \(currentStep.rawValue + 1) of \(OnboardingStep.allCases.count)")
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Button {
                advance()
            } label: {
                Text(primaryButtonTitle)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.Palette.navyInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.Palette.emberGold, AppTheme.Palette.ember],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                    )
                    .shadow(color: AppTheme.Palette.ember.opacity(0.20), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)

            if currentStep != .welcome {
                Button {
                    moveBack()
                } label: {
                    Text("Back")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.Palette.creamMuted)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var primaryButtonTitle: String {
        switch currentStep {
        case .welcome:
            "Start my fire"
        case .sticks:
            "Got it"
        case .final:
            "Go to Campfire"
        default:
            "Continue"
        }
    }

    private var connectButtonTitle: String {
        viewModel.healthState == .loading ? "Connecting..." : "Connect Apple Health"
    }

    private var healthFootnote: String {
        switch viewModel.healthState {
        case .loading:
            "Opening Apple Health permissions..."
        case .ready:
            "Apple Health is connected. Your walks can now fuel Campfire automatically."
        case .unavailable:
            "Apple Health is not available here. You can still enter Campfire."
        case .failed:
            "If Health access was denied, you can enable it later in Settings."
        case .idle, .needsAuthorization:
            "You can skip for now and connect Apple Health later from Campfire."
        }
    }

    private var healthFootnoteColor: Color {
        viewModel.healthState == .ready ? AppTheme.Palette.emberGold : AppTheme.Palette.creamMuted
    }

    private var reminderStepControls: some View {
        VStack(spacing: 12) {
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
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppTheme.Palette.glassStroke, lineWidth: 1)
            )

            HStack(spacing: 10) {
                reminderActionButton(
                    title: isUpdatingReminder ? "Updating..." : "Enable reminders",
                    systemImage: "bell.fill",
                    isPrimary: true
                ) {
                    Task { await enableOnboardingReminder() }
                }

                reminderActionButton(
                    title: "Not now",
                    systemImage: "bell.slash.fill",
                    isPrimary: false
                ) {
                    reminderService.cancelDailyReminder()
                    remindersEnabled = false
                    reminderMessage = "No problem. You can enable reminders later in Settings."
                }
            }

            if let reminderMessage {
                Text(reminderMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.creamMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func reminderActionButton(
        title: String,
        systemImage: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))

                Text(title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(isPrimary ? AppTheme.Palette.navyInk : AppTheme.Palette.cream)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isPrimary ? AppTheme.Palette.cream : AppTheme.Palette.navyInk.opacity(0.34),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppTheme.Palette.glassStroke, lineWidth: isPrimary ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isUpdatingReminder)
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

    private var formattedReminderTime: String {
        Self.reminderTimeFormatter.string(from: reminderDate)
    }

    private func enableOnboardingReminder() async {
        isUpdatingReminder = true
        defer { isUpdatingReminder = false }

        let status = await reminderService.authorizationStatus()
        let isAllowed = status == .notDetermined
            ? await reminderService.requestAuthorization()
            : status.allowsReminderScheduling

        reminderAuthorizationStatus = await reminderService.authorizationStatus()

        guard isAllowed || reminderAuthorizationStatus.allowsReminderScheduling else {
            remindersEnabled = false
            reminderService.cancelDailyReminder()
            reminderMessage = "Notifications were not enabled. You can turn them on later in Settings."
            return
        }

        do {
            try await reminderService.scheduleDailyReminder(hour: reminderHour, minute: reminderMinute)
            remindersEnabled = true
            reminderMessage = "Reminder scheduled for \(formattedReminderTime)."
        } catch {
            remindersEnabled = false
            reminderMessage = "Could not schedule the reminder. You can try again later in Settings."
        }
    }

    private var mascotStage: Int {
        min(currentStep.rawValue + 1, 5)
    }

    private var mascotProgress: Double {
        Double(currentStep.rawValue + 1) / Double(OnboardingStep.allCases.count)
    }

    private func advance() {
        normalizeGoal()

        guard let nextStep = currentStep.next else {
            persistOnboardingChoices()
            onComplete()
            return
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            currentStep = nextStep
        }
    }

    private func moveBack() {
        guard let previousStep = currentStep.previous else { return }

        normalizeGoal()

        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            currentStep = previousStep
        }
    }

    private func normalizeGoal() {
        dailyStepGoal = CampfirePreferences.clampedDailyStepGoal(dailyStepGoal)
    }

    private func persistOnboardingChoices() {
        normalizeGoal()
        UserDefaults.standard.set(dailyStepGoal, forKey: CampfirePreferences.dailyStepGoalKey)
        UserDefaults.standard.set(remindersEnabled, forKey: CampfirePreferences.remindersEnabledKey)
        UserDefaults.standard.set(reminderHour, forKey: CampfirePreferences.reminderHourKey)
        UserDefaults.standard.set(reminderMinute, forKey: CampfirePreferences.reminderMinuteKey)
    }

    private static let reminderTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

private enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case goal
    case sticks
    case health
    case reminder
    case final

    var id: Int { rawValue }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }

    var isDense: Bool {
        switch self {
        case .goal, .sticks, .reminder:
            true
        case .welcome, .health, .final:
            false
        }
    }

    var showsMascot: Bool {
        switch self {
        case .welcome, .health, .final:
            true
        case .goal, .sticks, .reminder:
            false
        }
    }
}

private struct OnboardingStatRow: View {
    var title: String
    var value: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.Palette.emberGold)
                .frame(width: 34, height: 34)
                .background(AppTheme.Palette.ember.opacity(0.16), in: Circle())

            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.Palette.cream)

            Spacer(minLength: 10)

            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(AppTheme.Palette.emberGold)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.Palette.glassFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppTheme.Palette.glassStroke, lineWidth: 1)
        )
    }
}

private extension UNAuthorizationStatus {
    var allowsReminderScheduling: Bool {
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

#Preview("Onboarding") {
    OnboardingView {}
}
