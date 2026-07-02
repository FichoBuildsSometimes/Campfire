import SwiftUI

struct EmberParticleSeed: Identifiable {
    let id = UUID()
    var delay: Double
    var duration: Double
    var startX: CGFloat
    var drift: CGFloat
    var rise: CGFloat
    var size: CGFloat
    var color: Color
}

struct EmberParticleView: View {
    var seed: EmberParticleSeed
    var reduceMotion: Bool

    @State private var isRising = false

    var body: some View {
        if reduceMotion {
            EmptyView()
        } else {
            Circle()
                .fill(seed.color)
                .frame(width: seed.size, height: seed.size)
                .blur(radius: isRising ? 1.8 : 0.3)
                .opacity(isRising ? 0 : 0.86)
                .scaleEffect(isRising ? 0.45 : 1)
                .offset(
                    x: seed.startX + (isRising ? seed.drift : 0),
                    y: isRising ? -seed.rise : 0
                )
                .onAppear {
                    withAnimation(.easeOut(duration: seed.duration).delay(seed.delay)) {
                        isRising = true
                    }
                }
        }
    }
}

#Preview("Ember Particle") {
    ZStack {
        Color.black.ignoresSafeArea()
        EmberParticleView(
            seed: EmberParticleSeed(
                delay: 0,
                duration: 1.1,
                startX: 0,
                drift: 20,
                rise: 110,
                size: 8,
                color: AppTheme.Palette.emberGold
            ),
            reduceMotion: false
        )
    }
}
