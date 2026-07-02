import SwiftUI

struct ProfileView: View {
    var viewModel: ProfileViewModel

    var bottomPadding: CGFloat

    private let statColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    init(viewModel: ProfileViewModel = ProfileViewModel(), bottomPadding: CGFloat = 116) {
        self.viewModel = viewModel
        self.bottomPadding = bottomPadding
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = min(max(proxy.size.width - 44, 288), 360)

            ZStack {
                profileBackground(size: proxy.size)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header

                        if let loadingTitle = viewModel.loadingTitle {
                            statusCard(
                                title: loadingTitle,
                                message: "Pulling together your latest walking story.",
                                systemImage: "arrow.triangle.2.circlepath",
                                showsButton: false
                            )
                        }

                        if viewModel.showsHealthCard {
                            statusCard(
                                title: viewModel.healthCardTitle,
                                message: viewModel.healthCardMessage,
                                systemImage: "heart.text.square.fill",
                                showsButton: viewModel.showsConnectHealthButton
                            )
                        }

                        if viewModel.showsEmptyState {
                            statusCard(
                                title: "Start walking to build your Campfire history.",
                                message: "Your steps, sticks, and fire progress will appear here.",
                                systemImage: "leaf.fill",
                                showsButton: false
                            )
                        }

                        lifetimeProgressCard
                        stepsHistoryCard
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.top, max(proxy.safeAreaInsets.top + 22, 72))
                    .padding(.bottom, bottomPadding)
                    .frame(width: proxy.size.width)
                }
                .refreshable {
                    await viewModel.refreshFromUserGesture()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .task {
            await viewModel.loadOnAppearIfNeeded()
        }
        .onChange(of: viewModel.selectedRange) { _, _ in
            Task {
                await viewModel.refreshSelectedRangeIfNeeded()
            }
        }
    }

    private func profileBackground(size: CGSize) -> some View {
        ZStack {
            AppTheme.Palette.navyInk

            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                Image(WidgetDayPhase(date: timeline.date).appBackgroundAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .opacity(0.34)
                    .clipped()
            }

            LinearGradient(
                colors: [
                    AppTheme.Palette.navyInk.opacity(0.58),
                    AppTheme.Palette.forestDeep.opacity(0.72),
                    AppTheme.Palette.navyInk
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    AppTheme.Palette.ember.opacity(0.22),
                    .clear,
                    .clear
                ],
                startPoint: .topTrailing,
                endPoint: .center
            )
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Camper Profile")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Palette.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                    .shadow(color: AppTheme.Palette.shadow, radius: 8, x: 0, y: 3)

                Text("Your walking story so far.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.creamMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(viewModel.currentStreakTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Palette.emberGold)
                    .lineLimit(1)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(AppTheme.Palette.ember.opacity(0.15), in: Capsule())
            }

            Spacer(minLength: 8)

            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)

                Circle()
                    .fill(AppTheme.Palette.ember.opacity(0.13))

                Image("campfire_stage_3")
                    .resizable()
                    .scaledToFit()
                    .padding(9)
            }
            .frame(width: 62, height: 62)
            .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            .shadow(color: AppTheme.Palette.ember.opacity(0.32), radius: 18, x: 0, y: 8)
            .accessibilityHidden(true)
        }
    }

    private var lifetimeProgressCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader(title: "Lifetime Progress", subtitle: "Every step in the story.")

                LazyVGrid(columns: statColumns, alignment: .leading, spacing: 14) {
                    ProfileStatCard(
                        title: "Lifetime sticks",
                        value: viewModel.lifetimeSticksTitle,
                        caption: "Collected",
                        systemImage: "tree.fill",
                        accent: AppTheme.Palette.forestMuted
                    )

                    ProfileStatCard(
                        title: "Total steps",
                        value: viewModel.totalStepsTitle,
                        caption: "All-time",
                        systemImage: "figure.walk",
                        accent: Color(red: 0.54, green: 0.70, blue: 0.56)
                    )

                    ProfileStatCard(
                        title: "Active kcal",
                        value: viewModel.totalCaloriesTitle,
                        caption: "Burned",
                        systemImage: "bolt.heart.fill",
                        accent: AppTheme.Palette.emberGold
                    )

                    ProfileStatCard(
                        title: "Fires completed",
                        value: viewModel.firesCompletedTitle,
                        caption: "Full charges",
                        systemImage: "flame.fill",
                        accent: AppTheme.Palette.ember
                    )

                    ProfileStatCard(
                        title: "Best streak",
                        value: viewModel.bestStreakTitle,
                        caption: "Walking days",
                        systemImage: "calendar.badge.clock",
                        accent: AppTheme.Palette.creamMuted
                    )
                }
            }
        }
    }

    private var stepsHistoryCard: some View {
        @Bindable var viewModel = viewModel

        return GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(title: "Steps History", subtitle: "Momentum over time.")

                ProfileRangeSelector(selectedRange: $viewModel.selectedRange)

                HStack(spacing: 10) {
                    summaryPill(title: "Total", value: viewModel.periodTotalTitle)
                    summaryPill(title: viewModel.selectedRange.averageLabel, value: viewModel.periodAverageTitle)
                }

                StepsHistoryChartView(
                    points: viewModel.chartPoints,
                    range: viewModel.selectedRange
                )
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.Palette.cream)
                .lineLimit(1)

            Text(subtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.creamMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.Palette.creamMuted)
                .textCase(.uppercase)
                .lineLimit(1)

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.Palette.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.Palette.navyInk.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.Palette.glassStroke.opacity(0.74), lineWidth: 1)
        )
    }

    private func statusCard(title: String, message: String, systemImage: String, showsButton: Bool) -> some View {
        GlassCard(cornerRadius: 22, contentPadding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.Palette.emberGold)
                        .frame(width: 30, height: 30)
                        .background(AppTheme.Palette.ember.opacity(0.16), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.Palette.cream)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(message)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.creamMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if showsButton {
                    Button {
                        Task {
                            await viewModel.connectHealth()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 14, weight: .bold))

                            Text("Connect Health")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(AppTheme.Palette.navyInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.Palette.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview("Profile") {
    ProfileView(viewModel: .preview())
}
