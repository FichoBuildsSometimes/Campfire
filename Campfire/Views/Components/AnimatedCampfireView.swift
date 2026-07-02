import SwiftUI

struct AnimatedCampfireView: View {
    private static let maxLiveEmbers = 16
    private static let maxLiveFlyingSticks = 4

    var stage: Int
    var progress: Double
    var isGoalCompleted: Bool
    var isUpgrading: Bool
    var sticksEarned: Int
    var size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isBreathing = false
    @State private var isGlowPulsing = false
    @State private var eventScale: CGFloat = 1
    @State private var glowFlash: Double = 0
    @State private var glowWaveScale: CGFloat = 0.68
    @State private var glowWaveOpacity: Double = 0
    @State private var emberSeeds: [EmberParticleSeed] = []
    @State private var flyingStickSeeds: [FlyingStickSeed] = []

    private var clampedStage: Int {
        min(max(stage, 1), 5)
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var stageStrength: Double {
        Double(clampedStage - 1) / 4
    }

    private var metrics: CampfireStageAnimationMetrics {
        CampfireStageAnimationMetrics(stage: clampedStage)
    }

    private var breathingScale: CGFloat {
        guard !reduceMotion else { return 1 }

        let lowScale = 0.985 - clampedProgress * 0.004
        let highScale = 1.018 + clampedProgress * 0.014
        return CGFloat(isBreathing ? highScale : lowScale)
    }

    private var glowOpacity: Double {
        min(0.28 + stageStrength * 0.12 + clampedProgress * 0.22 + glowFlash, 0.82)
    }

    var body: some View {
        ZStack {
            // Warm glow pulse.
            glowLayer

            // Reward ember bursts.
            ForEach(emberSeeds) { seed in
                EmberParticleView(seed: seed, reduceMotion: reduceMotion)
                    .position(x: size / 2, y: size * metrics.emberStartY)
            }

            // Stick collection flight.
            ForEach(flyingStickSeeds) { seed in
                FlyingStickView(seed: seed, size: size, reduceMotion: reduceMotion)
                    .frame(width: size, height: size)
            }

            // Idle breathing mascot.
            Image("campfire_stage_\(clampedStage)")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .offset(y: size * metrics.transparentBottomInsetRatio)
                .scaleEffect(breathingScale * eventScale)
                .shadow(
                    color: AppTheme.Palette.ember.opacity(0.24 + clampedProgress * 0.34),
                    radius: min(10 + clampedProgress * 10, 20),
                    x: 0,
                    y: 8
                )
                .animation(.easeInOut(duration: idleDuration).repeatForever(autoreverses: true), value: isBreathing)
                .animation(.spring(response: 0.34, dampingFraction: 0.62), value: eventScale)
                .accessibilityLabel("Campfire mascot")
        }
        .frame(width: size, height: size)
        .onAppear(perform: startIdleAnimations)
        .onDisappear(perform: clearTransientAnimations)
        .onChange(of: isUpgrading) { _, newValue in
            guard newValue else { return }
            triggerReward(kind: .upgrade)
        }
        .onChange(of: isGoalCompleted) { oldValue, newValue in
            guard newValue && !oldValue else { return }
            triggerReward(kind: .goalCompleted)
        }
        .onChange(of: sticksEarned) { oldValue, newValue in
            guard newValue > oldValue else { return }
            triggerStickCollection(gained: newValue - oldValue)
        }
    }

    private var idleDuration: Double {
        max(2.15, 2.85 - clampedProgress * 0.35)
    }

    private var glowLayer: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.Palette.emberGold.opacity(glowOpacity),
                            AppTheme.Palette.ember.opacity(glowOpacity * 0.36),
                            AppTheme.Palette.ember.opacity(glowOpacity * 0.12),
                            .clear
                        ],
                        center: .center,
                        startRadius: size * 0.05,
                        endRadius: size * 0.62
                    )
                )
                .frame(
                    width: size * CGFloat(1.15 + stageStrength * 0.10 + clampedProgress * 0.10),
                    height: size * CGFloat(0.78 + stageStrength * 0.08 + clampedProgress * 0.09)
                )
                .blur(radius: min(size * 0.042, 12))
                .scaleEffect(reduceMotion ? 1 : (isGlowPulsing ? 1.08 : 0.94))
                .animation(.easeInOut(duration: 2.45).repeatForever(autoreverses: true), value: isGlowPulsing)

            Ellipse()
                .fill(AppTheme.Palette.emberGold.opacity(glowWaveOpacity))
                .frame(width: size * 1.05, height: size * 0.72)
                .blur(radius: min(size * 0.06, 16))
                .scaleEffect(glowWaveScale)
        }
        .offset(y: size * metrics.glowYOffset)
    }

    private func startIdleAnimations() {
        guard !reduceMotion else {
            isGlowPulsing = true
            return
        }

        withAnimation(.easeInOut(duration: idleDuration).repeatForever(autoreverses: true)) {
            isBreathing = true
        }

        withAnimation(.easeInOut(duration: 2.45).repeatForever(autoreverses: true)) {
            isGlowPulsing = true
        }
    }

    private func clearTransientAnimations() {
        eventScale = 1
        glowFlash = 0
        glowWaveScale = 0.68
        glowWaveOpacity = 0
        emberSeeds.removeAll()
        flyingStickSeeds.removeAll()
    }

    private func triggerReward(kind: CampfireRewardKind) {
        if reduceMotion {
            pulseGlowOnly(strength: kind.flash)
            return
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.56)) {
            eventScale = kind.scale
            glowFlash = kind.flash
            glowWaveScale = 0.66
            glowWaveOpacity = kind.waveOpacity
        }

        withAnimation(.easeOut(duration: 0.72).delay(0.04)) {
            glowWaveScale = kind.waveScale
            glowWaveOpacity = 0
        }

        withAnimation(.spring(response: 0.44, dampingFraction: 0.74).delay(0.16)) {
            eventScale = 1
        }

        withAnimation(.easeOut(duration: 0.55).delay(0.18)) {
            glowFlash = 0
        }

        spawnEmbers(count: kind.emberCount, power: kind.emberPower)
    }

    private func triggerStickCollection(gained: Int) {
        if reduceMotion {
            pulseGlowOnly(strength: 0.12)
            return
        }

        let count = min(max(gained, 1), 3)
        var seeds: [FlyingStickSeed] = []

        for index in 0..<count {
            seeds.append(FlyingStickSeed(
                delay: Double(index) * 0.14,
                startRotation: 24 + Double(index * 7),
                endRotation: -12 + Double(index * 4)
            ))
        }

        flyingStickSeeds.append(contentsOf: seeds)
        flyingStickSeeds = Array(flyingStickSeeds.suffix(Self.maxLiveFlyingSticks))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48 + Double(count - 1) * 0.14) {
            pulseGlowOnly(strength: 0.18)
            spawnEmbers(count: min(3 + count, 5), power: 0.72)
        }

        let ids = Set(seeds.map { $0.id })
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            flyingStickSeeds.removeAll { ids.contains($0.id) }
        }
    }

    private func pulseGlowOnly(strength: Double) {
        withAnimation(.easeOut(duration: 0.18)) {
            glowFlash = strength
        }

        withAnimation(.easeOut(duration: 0.55).delay(0.18)) {
            glowFlash = 0
        }
    }

    private func spawnEmbers(count: Int, power: Double) {
        guard !reduceMotion else { return }

        var particles: [EmberParticleSeed] = []

        for index in 0..<count {
            let direction: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            let spread = CGFloat((index % 5) - 2) * size * 0.014
            let drift = direction * size * (0.035 + CGFloat(index % 4) * 0.012)
            let rise = size * (0.24 + CGFloat(index % 4) * 0.045) * CGFloat(power)
            let particleSize = size * (0.012 + CGFloat(index % 3) * 0.004)

            particles.append(EmberParticleSeed(
                delay: Double(index) * 0.035,
                duration: 0.82 + Double(index % 4) * 0.08,
                startX: spread,
                drift: drift,
                rise: rise,
                size: particleSize,
                color: index.isMultiple(of: 3) ? AppTheme.Palette.emberGold : AppTheme.Palette.ember
            ))
        }

        emberSeeds.append(contentsOf: particles)
        emberSeeds = Array(emberSeeds.suffix(Self.maxLiveEmbers))

        let ids = Set(particles.map { $0.id })
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
            emberSeeds.removeAll { ids.contains($0.id) }
        }
    }
}

private struct CampfireStageAnimationMetrics {
    var stage: Int

    var transparentBottomInsetRatio: CGFloat {
        switch stage {
        case 1:
            0.194
        case 2:
            0.193
        case 3:
            0.194
        case 4:
            0.162
        default:
            0.116
        }
    }

    var glowYOffset: CGFloat {
        switch stage {
        case 1:
            0.36
        case 2:
            0.35
        case 3:
            0.29
        case 4:
            0.22
        default:
            0.18
        }
    }

    var emberStartY: CGFloat {
        switch stage {
        case 1, 2:
            0.72
        case 3:
            0.66
        case 4:
            0.58
        default:
            0.54
        }
    }
}

private enum CampfireRewardKind {
    case upgrade
    case goalCompleted

    var scale: CGFloat {
        switch self {
        case .upgrade:
            1.105
        case .goalCompleted:
            1.085
        }
    }

    var flash: Double {
        switch self {
        case .upgrade:
            0.22
        case .goalCompleted:
            0.28
        }
    }

    var waveOpacity: Double {
        switch self {
        case .upgrade:
            0.32
        case .goalCompleted:
            0.38
        }
    }

    var waveScale: CGFloat {
        switch self {
        case .upgrade:
            1.32
        case .goalCompleted:
            1.42
        }
    }

    var emberCount: Int {
        switch self {
        case .upgrade:
            6
        case .goalCompleted:
            8
        }
    }

    var emberPower: Double {
        switch self {
        case .upgrade:
            0.92
        case .goalCompleted:
            1.08
        }
    }
}

#Preview("Animated Campfire") {
    ZStack {
        AppTheme.Palette.forestDeep.ignoresSafeArea()
        AnimatedCampfireView(
            stage: 4,
            progress: 0.78,
            isGoalCompleted: false,
            isUpgrading: false,
            sticksEarned: 42,
            size: 260
        )
    }
}
