import SwiftUI
import OSLog

struct CampfireMascotView: View {
    var stage: CampfireStage
    var fireChargeProgress: Double

    private static let logger = Logger(subsystem: "com.ficho.Campfire", category: "CampfireMascot")

    @State private var isBouncing = false

    private var clampedProgress: Double {
        min(max(fireChargeProgress, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let groundingOffset = groundingOffset(for: proxy.size)

            ZStack(alignment: .bottom) {
                glow
                    .offset(y: groundingOffset)

                EmberParticleField(fireChargeProgress: clampedProgress)
                    .frame(width: proxy.size.width * 1.72, height: proxy.size.height * 1.48)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.44 + groundingOffset)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                groundShadow
                    .padding(.bottom, 4)

                Image(stage.assetName)
                    .resizable()
                    .scaledToFit()
                    .offset(y: groundingOffset)
                    .shadow(color: AppTheme.Palette.ember.opacity(0.34 + clampedProgress * 0.28), radius: 18 + clampedProgress * 18, x: 0, y: 8)
                    .accessibilityLabel("Campfire mascot")
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
        .scaleEffect(isBouncing ? 1.045 : 1)
        .animation(.spring(response: 0.42, dampingFraction: 0.7), value: isBouncing)
        .animation(.easeInOut(duration: 0.35), value: clampedProgress)
        .task(id: stage.assetName) {
            Self.logger.debug("Selected campfire image: \(stage.assetName, privacy: .public)")
        }
        .onChange(of: stage) { _, _ in
            bounce()
        }
    }

    private func groundingOffset(for size: CGSize) -> CGFloat {
        min(size.width, size.height) * stage.transparentBottomInsetRatio
    }

    private var groundShadow: some View {
        Ellipse()
            .fill(Color.black.opacity(0.32))
            .frame(width: 188, height: 34)
            .blur(radius: 12)
            .scaleEffect(x: 0.92 + clampedProgress * 0.18, y: 0.82)
    }

    private var glow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        AppTheme.Palette.emberGold.opacity(0.28 + clampedProgress * 0.34),
                        AppTheme.Palette.ember.opacity(0.12 + clampedProgress * 0.24),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 12,
                    endRadius: 128 + clampedProgress * 70
                )
            )
            .blur(radius: 14 + clampedProgress * 12)
            .scaleEffect(x: 1.02 + clampedProgress * 0.16, y: 0.76 + clampedProgress * 0.12)
    }

    private func bounce() {
        isBouncing = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            isBouncing = false
        }
    }
}

private extension CampfireStage {
    var transparentBottomInsetRatio: CGFloat {
        switch self {
        case .stage1:
            0.194
        case .stage2:
            0.193
        case .stage3:
            0.194
        case .stage4:
            0.162
        case .stage5:
            0.116
        }
    }
}

private struct EmberParticleField: View {
    var fireChargeProgress: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clampedProgress: Double {
        min(max(fireChargeProgress, 0), 1)
    }

    var body: some View {
        if reduceMotion {
            Canvas { context, size in
                drawParticles(context: &context, size: size, time: 0)
            }
        } else {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    drawParticles(
                        context: &context,
                        size: size,
                        time: timeline.date.timeIntervalSinceReferenceDate
                    )
                }
            }
        }
    }

    private func drawParticles(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let charge = clampedProgress
        let visibleCount = max(4, Int((6.0 + charge * 8.0).rounded()))
        let center = CGPoint(x: size.width / 2, y: size.height * 0.54)
        let fieldWidth = min(size.width, size.height) * (0.24 + charge * 0.08)
        let fieldHeight = min(size.width, size.height) * (0.22 + charge * 0.08)

        for particle in Self.particles.prefix(visibleCount) {
            let phase = particle.phase * .pi * 2
            let angle = time * particle.speed * .pi * 2 + phase
            let drift = sin(time * particle.drift + phase * 1.7)
            let lift = (0.5 + 0.5 * sin(time * particle.lift + phase * 0.8)) * Double(particle.rise)
            let x = center.x + cos(angle) * fieldWidth * particle.orbitX + drift * fieldWidth * 0.08
            let y = center.y + sin(angle * 0.78 + phase * 0.25) * fieldHeight * particle.orbitY - fieldHeight * CGFloat(lift)

            let pulse = reduceMotion ? 0.82 : 0.74 + 0.26 * sin(time * particle.pulse + phase)
            let alpha = particle.opacity * (0.28 + charge * 0.72) * pulse
            let radius = particle.size * (0.78 + charge * 0.28)
            let point = CGPoint(x: x, y: y)

            drawGlow(
                context: &context,
                point: point,
                radius: radius,
                alpha: alpha,
                warmShift: particle.warmShift
            )
        }
    }

    private func drawGlow(context: inout GraphicsContext, point: CGPoint, radius: CGFloat, alpha: Double, warmShift: Double) {
        let outerRadius = radius * 2.15
        let middleRadius = radius * 1.36

        context.fill(
            Path(ellipseIn: CGRect(
                x: point.x - outerRadius,
                y: point.y - outerRadius,
                width: outerRadius * 2,
                height: outerRadius * 2
            )),
            with: .color(AppTheme.Palette.ember.opacity(alpha * 0.20))
        )

        context.fill(
            Path(ellipseIn: CGRect(
                x: point.x - middleRadius,
                y: point.y - middleRadius,
                width: middleRadius * 2,
                height: middleRadius * 2
            )),
            with: .color(AppTheme.Palette.emberGold.opacity(alpha * 0.38))
        )

        let coreColor = Color(
            red: 1.0,
            green: 0.70 + warmShift,
            blue: 0.26
        )

        context.fill(
            Path(ellipseIn: CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            )),
            with: .color(coreColor.opacity(alpha))
        )
    }

    private struct Particle {
        var phase: Double
        var speed: Double
        var drift: Double
        var lift: Double
        var pulse: Double
        var size: CGFloat
        var opacity: Double
        var orbitX: CGFloat
        var orbitY: CGFloat
        var rise: CGFloat
        var warmShift: Double
    }

    private static let particles: [Particle] = [
        Particle(phase: 0.04, speed: 0.044, drift: 0.31, lift: 0.42, pulse: 1.20, size: 1.8, opacity: 0.76, orbitX: 0.92, orbitY: 0.54, rise: 0.20, warmShift: 0.04),
        Particle(phase: 0.13, speed: 0.036, drift: 0.26, lift: 0.36, pulse: 1.06, size: 3.4, opacity: 0.62, orbitX: 0.56, orbitY: 0.80, rise: 0.28, warmShift: 0.00),
        Particle(phase: 0.21, speed: 0.041, drift: 0.34, lift: 0.48, pulse: 1.34, size: 2.4, opacity: 0.66, orbitX: 0.74, orbitY: 0.62, rise: 0.18, warmShift: 0.06),
        Particle(phase: 0.29, speed: 0.032, drift: 0.22, lift: 0.32, pulse: 0.94, size: 3.7, opacity: 0.48, orbitX: 0.50, orbitY: 0.84, rise: 0.30, warmShift: 0.02),
        Particle(phase: 0.36, speed: 0.047, drift: 0.37, lift: 0.44, pulse: 1.24, size: 2.0, opacity: 0.72, orbitX: 0.82, orbitY: 0.50, rise: 0.22, warmShift: 0.08),
        Particle(phase: 0.44, speed: 0.038, drift: 0.29, lift: 0.39, pulse: 1.14, size: 2.9, opacity: 0.58, orbitX: 0.64, orbitY: 0.74, rise: 0.21, warmShift: 0.03),
        Particle(phase: 0.51, speed: 0.052, drift: 0.41, lift: 0.51, pulse: 1.48, size: 1.7, opacity: 0.70, orbitX: 1.00, orbitY: 0.42, rise: 0.16, warmShift: 0.05),
        Particle(phase: 0.58, speed: 0.034, drift: 0.24, lift: 0.34, pulse: 0.98, size: 4.0, opacity: 0.42, orbitX: 0.42, orbitY: 0.88, rise: 0.32, warmShift: 0.01),
        Particle(phase: 0.65, speed: 0.043, drift: 0.35, lift: 0.46, pulse: 1.40, size: 2.6, opacity: 0.60, orbitX: 0.70, orbitY: 0.56, rise: 0.19, warmShift: 0.07),
        Particle(phase: 0.73, speed: 0.037, drift: 0.28, lift: 0.37, pulse: 1.10, size: 3.5, opacity: 0.46, orbitX: 0.54, orbitY: 0.78, rise: 0.28, warmShift: 0.02),
        Particle(phase: 0.80, speed: 0.049, drift: 0.39, lift: 0.50, pulse: 1.28, size: 2.1, opacity: 0.64, orbitX: 0.90, orbitY: 0.46, rise: 0.17, warmShift: 0.06),
        Particle(phase: 0.87, speed: 0.040, drift: 0.30, lift: 0.41, pulse: 1.20, size: 3.1, opacity: 0.50, orbitX: 0.72, orbitY: 0.68, rise: 0.24, warmShift: 0.04),
        Particle(phase: 0.93, speed: 0.033, drift: 0.23, lift: 0.33, pulse: 0.96, size: 4.1, opacity: 0.40, orbitX: 0.46, orbitY: 0.84, rise: 0.31, warmShift: 0.01),
        Particle(phase: 0.98, speed: 0.053, drift: 0.43, lift: 0.53, pulse: 1.36, size: 1.9, opacity: 0.70, orbitX: 0.96, orbitY: 0.48, rise: 0.17, warmShift: 0.07)
    ]
}

private struct CampfirePlaceholder: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(AppTheme.Palette.ember.opacity(0.24))
                .frame(width: 172, height: 48)
                .blur(radius: 10)
                .offset(y: 78)

            ZStack {
                FlameShape()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.Palette.emberGold, AppTheme.Palette.ember],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 124, height: 162)
                    .shadow(color: AppTheme.Palette.ember.opacity(0.58), radius: 20, x: 0, y: 8)

                FlameShape()
                    .fill(Color(red: 1.0, green: 0.88, blue: 0.45))
                    .frame(width: 58, height: 82)
                    .offset(y: 28)
                    .opacity(0.9)
            }
            .offset(y: -22)

            HStack(spacing: -18) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 0.47, green: 0.25, blue: 0.13))
                    .frame(width: 118, height: 28)
                    .rotationEffect(.degrees(16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(red: 0.72, green: 0.43, blue: 0.22), lineWidth: 2)
                    )

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 0.38, green: 0.19, blue: 0.10))
                    .frame(width: 118, height: 28)
                    .rotationEffect(.degrees(-16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(red: 0.66, green: 0.37, blue: 0.18), lineWidth: 2)
                    )
            }
            .offset(y: 72)
        }
        .frame(width: 230, height: 230)
    }
}

private struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX * 0.86, y: rect.maxY * 0.62),
            control1: CGPoint(x: rect.maxX * 0.82, y: rect.maxY * 0.18),
            control2: CGPoint(x: rect.maxX, y: rect.maxY * 0.38)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX * 0.78, y: rect.maxY * 0.84),
            control2: CGPoint(x: rect.maxX * 0.66, y: rect.maxY)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX * 1.18, y: rect.maxY * 0.62),
            control1: CGPoint(x: rect.maxX * 0.30, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.maxY * 0.82)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.maxX * 0.08, y: rect.maxY * 0.36),
            control2: CGPoint(x: rect.maxX * 0.35, y: rect.maxY * 0.22)
        )
        path.closeSubpath()
        return path
    }
}

#Preview("Mascot Fallback") {
    ZStack {
        AppTheme.Palette.forestDeep.ignoresSafeArea()
        CampfireMascotView(stage: .stage4, fireChargeProgress: 0.72)
            .frame(width: 280, height: 280)
    }
}
