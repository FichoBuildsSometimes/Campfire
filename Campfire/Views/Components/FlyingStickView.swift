import SwiftUI

struct FlyingStickSeed: Identifiable {
    let id = UUID()
    var delay: Double
    var startRotation: Double
    var endRotation: Double
}

struct FlyingStickView: View {
    var seed: FlyingStickSeed
    var size: CGFloat
    var reduceMotion: Bool

    @State private var hasEnteredFire = false

    var body: some View {
        if reduceMotion {
            EmptyView()
        } else {
            stick
                .frame(width: size * 0.28, height: size * 0.045)
                .scaleEffect(hasEnteredFire ? 0.26 : 1)
                .rotationEffect(.degrees(hasEnteredFire ? seed.endRotation : seed.startRotation))
                .opacity(hasEnteredFire ? 0 : 1)
                .offset(
                    x: hasEnteredFire ? size * 0.02 : size * 0.36,
                    y: hasEnteredFire ? size * 0.10 : size * 0.34
                )
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.62).delay(seed.delay)) {
                        hasEnteredFire = true
                    }
                }
        }
    }

    private var stick: some View {
        RoundedRectangle(cornerRadius: size * 0.018, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.54, green: 0.31, blue: 0.16),
                        Color(red: 0.34, green: 0.18, blue: 0.09)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.018, style: .continuous)
                    .stroke(Color(red: 0.76, green: 0.48, blue: 0.25).opacity(0.58), lineWidth: 1)
            }
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Color(red: 0.82, green: 0.56, blue: 0.32).opacity(0.55))
                    .frame(width: size * 0.08, height: size * 0.008)
                    .padding(.leading, size * 0.035)
            }
            .shadow(color: AppTheme.Palette.ember.opacity(0.26), radius: 8, x: 0, y: 4)
    }
}

#Preview("Flying Stick") {
    ZStack {
        AppTheme.Palette.forestDeep.ignoresSafeArea()
        FlyingStickView(
            seed: FlyingStickSeed(delay: 0, startRotation: 26, endRotation: -14),
            size: 240,
            reduceMotion: false
        )
        .frame(width: 240, height: 240)
    }
}
