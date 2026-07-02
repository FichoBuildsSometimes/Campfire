import SwiftUI

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(CampfirePreferences.dailyStepGoalKey) private var dailyStepGoal = WalkingStats.defaultDailyStepGoal
    @State private var viewModel: HomeViewModel
    @State private var profileViewModel: ProfileViewModel
    @State private var selectedTab: CampfireTab = .home
    @State private var isCampfireUpgrading = false
    private var onResetOnboarding: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    init(
        viewModel: HomeViewModel = HomeViewModel(),
        profileViewModel: ProfileViewModel = ProfileViewModel(),
        onResetOnboarding: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: viewModel)
        _profileViewModel = State(initialValue: profileViewModel)
        self.onResetOnboarding = onResetOnboarding
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = min(max(proxy.size.width - 44, 288), 340)
            let tabBarWidth = min(max(proxy.size.width - 36, 288), 340)
            let heroHeight = firstViewportHeight(for: proxy.size, safeAreaInsets: proxy.safeAreaInsets)

            ZStack(alignment: .bottom) {
                AppTheme.Palette.navyInk
                    .ignoresSafeArea()

                if selectedTab == .profile {
                    ProfileView(viewModel: profileViewModel, bottomPadding: proxy.safeAreaInsets.bottom + 116)
                        .transition(.opacity)
                } else if selectedTab == .settings {
                    SettingsView(
                        viewModel: viewModel,
                        bottomPadding: proxy.safeAreaInsets.bottom + 116,
                        onResetOnboarding: onResetOnboarding
                    )
                    .transition(.opacity)
                } else {
                    homeContent(
                        size: proxy.size,
                        safeAreaInsets: proxy.safeAreaInsets,
                        contentWidth: contentWidth,
                        heroHeight: heroHeight
                    )
                }

                BottomTabBar(selectedTab: $selectedTab)
                    .frame(width: tabBarWidth)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 12))
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .task {
            viewModel.updateDailyStepGoal(dailyStepGoal)
            await viewModel.loadOnLaunch()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }

            Task {
                viewModel.updateDailyStepGoal(dailyStepGoal)
                await viewModel.refresh()
            }
        }
        .onChange(of: dailyStepGoal) { _, newGoal in
            viewModel.updateDailyStepGoal(newGoal)
        }
        .onChange(of: viewModel.currentStage.rawValue) { oldStage, newStage in
            guard newStage > oldStage else { return }
            triggerCampfireUpgrade()
        }
    }

    private func homeContent(
        size: CGSize,
        safeAreaInsets: EdgeInsets,
        contentWidth: CGFloat,
        heroHeight: CGFloat
    ) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroSection(
                    size: size,
                    safeAreaInsets: safeAreaInsets,
                    contentWidth: contentWidth,
                    heroHeight: heroHeight
                )
                .frame(width: size.width, height: heroHeight)

                VStack(alignment: .leading, spacing: 14) {
                    dashboardHeader
                        .frame(width: contentWidth)

                    statGrid
                        .frame(width: contentWidth)
                }
                .frame(width: size.width, alignment: .center)
                .padding(.top, 8)
                .padding(.bottom, safeAreaInsets.bottom + 116)
                .background(AppTheme.Palette.navyInk)
            }
            .frame(width: size.width, alignment: .center)
            .background(AppTheme.Palette.navyInk)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    @ViewBuilder
    private func heroBackground(size: CGSize, heroHeight: CGFloat) -> some View {
        ZStack {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                Image(WidgetDayPhase(date: timeline.date).appBackgroundAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: heroHeight)
                    .clipped()
            }

            LinearGradient(
                colors: [
                    AppTheme.Palette.navyInk.opacity(0.76),
                    AppTheme.Palette.forestDeep.opacity(0.34),
                    AppTheme.Palette.navyInk.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.Palette.ember.opacity(0.34),
                            AppTheme.Palette.ember.opacity(0.08 + viewModel.fireChargeProgress * 0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 18,
                        endRadius: 260
                    )
                )
                .frame(width: min(size.width * 1.24, 480), height: min(size.width * 1.24, 480))
                .blur(radius: 14 + viewModel.fireChargeProgress * 10)
                .position(x: size.width / 2, y: heroHeight * 0.58)
                .animation(.easeInOut(duration: 0.35), value: viewModel.fireChargeProgress)

            bottomBackgroundBlend
        }
    }

    private var bottomBackgroundBlend: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: 132)
                    .mask(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.55), .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(0.32)

                LinearGradient(
                    colors: [
                        .clear,
                        AppTheme.Palette.navyInk.opacity(0.48),
                        AppTheme.Palette.navyInk
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
            }
            .blur(radius: 0.8)
        }
    }

    private func heroSection(size: CGSize, safeAreaInsets: EdgeInsets, contentWidth: CGFloat, heroHeight: CGFloat) -> some View {
        let topPadding = topContentPadding(for: safeAreaInsets)
        let mascotSize = min(contentWidth * 0.70, mascotHeight(for: size), 250)

        return ZStack(alignment: .top) {
            heroBackground(size: size, heroHeight: heroHeight)

            VStack(alignment: .leading, spacing: 0) {
                header
                    .frame(width: contentWidth, alignment: .leading)

                Spacer(minLength: 18)

                AnimatedCampfireView(
                    stage: viewModel.currentStage.rawValue,
                    progress: viewModel.fireChargeProgress,
                    isGoalCompleted: viewModel.stepsProgress >= 1,
                    isUpgrading: isCampfireUpgrading,
                    sticksEarned: viewModel.stats.sticksCollected,
                    size: mascotSize
                )
                .frame(width: mascotSize, height: mascotSize)
                .frame(width: contentWidth, alignment: .center)
                .padding(.bottom, 8)

                stepsCard
                    .frame(width: contentWidth)
            }
            .padding(.top, topPadding)
            .padding(.bottom, 10)
            .frame(width: contentWidth, height: heroHeight, alignment: .top)
        }
        .frame(width: size.width, height: heroHeight)
        .clipped()
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Campfire")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Palette.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .shadow(color: AppTheme.Palette.shadow, radius: 8, x: 0, y: 3)

                Text("Today’s glow")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Palette.creamMuted)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .lineLimit(1)
                    .shadow(color: AppTheme.Palette.shadow, radius: 6, x: 0, y: 2)
            }

            Spacer(minLength: 10)

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                    selectedTab = .home
                }
            } label: {
                Image(systemName: "flame.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.Palette.emberGold)
                    .frame(width: 50, height: 50)
                    .background(.ultraThinMaterial, in: Circle())
                    .background(AppTheme.Palette.ember.opacity(0.16), in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                    .shadow(color: AppTheme.Palette.ember.opacity(0.34), radius: 18, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fire status")
            .padding(.trailing, 4)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var stepsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Today’s Steps")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.creamMuted)
                        .lineLimit(1)

                    Spacer()

                    Text(viewModel.statusBadgeTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Palette.emberGold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(AppTheme.Palette.ember.opacity(0.16), in: Capsule())
                }

                Text(viewModel.stepsTitle)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Palette.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .allowsTightening(true)

                ProgressBar(value: viewModel.stepsProgress, height: 12)

                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Palette.forestMuted)

                    Text(viewModel.healthStatusMessage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.cream.opacity(0.85))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }

                if viewModel.showsConnectHealthButton {
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
                    .accessibilityHint("Requests permission to read steps and active energy from Apple Health.")
                }
            }
        }
    }

    private var statGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            StatCard(
                title: "Fire Charge",
                value: viewModel.fireChargeTitle,
                caption: "Warm and steady",
                systemImage: "flame.fill",
                accent: AppTheme.Palette.ember,
                progress: viewModel.fireChargeProgress
            )

            StatCard(
                title: "Current Streak",
                value: viewModel.currentStreakTitle,
                caption: viewModel.currentStreakCaption,
                systemImage: "calendar.badge.clock",
                accent: AppTheme.Palette.emberGold
            )

            StatCard(
                title: "Sticks Collected",
                value: viewModel.sticksTitle,
                caption: "\(viewModel.stepsPerStick) steps each",
                systemImage: "tree.fill",
                accent: AppTheme.Palette.forestMuted,
                showsChevron: true
            )

            StatCard(
                title: "Active Calories",
                value: viewModel.caloriesTitle,
                caption: "Great burn!",
                systemImage: "bolt.heart.fill",
                accent: AppTheme.Palette.emberGold
            )
        }
    }

    private var dashboardHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Today’s Fire")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.Palette.cream)
                    .lineLimit(1)

                Text("Steps, streak, and fuel at a glance.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.creamMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 8)

            Text(viewModel.bestStreakTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Palette.emberGold)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(AppTheme.Palette.ember.opacity(0.14), in: Capsule())
        }
    }

    private func mascotHeight(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.26, 204), 252)
    }

    private func triggerCampfireUpgrade() {
        isCampfireUpgrading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            isCampfireUpgrading = false
        }
    }

    private func firstViewportHeight(for size: CGSize, safeAreaInsets: EdgeInsets) -> CGFloat {
        max(size.height - safeAreaInsets.bottom - 8, 720)
    }

    private func topContentPadding(for safeAreaInsets: EdgeInsets) -> CGFloat {
        max(safeAreaInsets.top + 14, 76)
    }
}

private struct FallbackForestBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.Palette.navyInk,
                    AppTheme.Palette.forestDeep,
                    AppTheme.Palette.forestMid
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack {
                Spacer()

                ForEach(0..<3) { layer in
                    TreeLine(layer: layer)
                        .fill(
                            layer == 0
                            ? AppTheme.Palette.forestDeep.opacity(0.72)
                            : AppTheme.Palette.navyInk.opacity(0.46)
                        )
                        .frame(height: CGFloat(150 + layer * 44))
                        .offset(y: CGFloat(layer * 26))
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct TreeLine: Shape {
    var layer: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))

        let treeWidth = rect.width / 7
        for index in 0...8 {
            let x = CGFloat(index) * treeWidth - treeWidth * 0.5
            let variance = CGFloat((index + layer) % 3) * 18
            let peakY = rect.minY + 16 + variance
            path.addLine(to: CGPoint(x: x + treeWidth * 0.5, y: peakY))
            path.addLine(to: CGPoint(x: x + treeWidth, y: rect.maxY))
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview("Home") {
    HomeView(viewModel: .preview())
}
