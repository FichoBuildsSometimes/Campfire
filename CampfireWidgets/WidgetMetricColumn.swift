import SwiftUI

struct WidgetMetricColumn: View {
    var title: String
    var value: String
    var systemImage: String?
    var accent: Color
    var usesStickIcon = false

    var body: some View {
        VStack(spacing: 5) {
            icon
                .frame(height: 18)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetTheme.Palette.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.64)
                .shadow(color: .black.opacity(0.42), radius: 3, x: 0, y: 1)

            Text(title)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetTheme.Palette.creamMuted)
                .lineLimit(2)
                .minimumScaleFactor(0.64)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var icon: some View {
        if usesStickIcon {
            StickIcon()
                .stroke(accent, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .frame(width: 18, height: 18)
                .shadow(color: accent.opacity(0.36), radius: 4, x: 0, y: 2)
        } else if let systemImage {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.36), radius: 4, x: 0, y: 2)
        }
    }
}

private struct StickIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.maxY * 0.78))
        path.addLine(to: CGPoint(x: rect.maxX * 0.76, y: rect.minY + rect.height * 0.18))
        path.move(to: CGPoint(x: rect.maxX * 0.46, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX * 0.72, y: rect.midY + rect.height * 0.10))
        return path
    }
}
