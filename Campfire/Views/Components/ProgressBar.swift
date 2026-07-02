import SwiftUI

struct ProgressBar: View {
    var value: Double
    var height: CGFloat = 10
    var tint: Color = AppTheme.Palette.ember
    var track: Color = Color.white.opacity(0.14)

    private var clampedValue: Double {
        min(max(value, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(track)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.Palette.emberGold, tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(proxy.size.width * clampedValue, height))
                    .shadow(color: tint.opacity(0.45), radius: 10, x: 0, y: 0)
                    .animation(.spring(response: 0.45, dampingFraction: 0.82), value: clampedValue)
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(clampedValue * 100)) percent")
    }
}

#Preview("Progress") {
    ZStack {
        AppTheme.Palette.forestDeep.ignoresSafeArea()
        ProgressBar(value: 0.72)
            .padding()
    }
}
