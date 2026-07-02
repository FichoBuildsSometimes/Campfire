import SwiftUI

struct StatCard: View {
    var title: String
    var value: String
    var caption: String
    var systemImage: String
    var accent: Color = AppTheme.Palette.ember
    var progress: Double?
    var showsChevron: Bool = false

    var body: some View {
        GlassCard(cornerRadius: 22, contentPadding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 30, height: 30)
                        .background(accent.opacity(0.16), in: Circle())

                    Spacer(minLength: 6)

                    if showsChevron {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.Palette.creamMuted)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.creamMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(value)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.Palette.cream)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                if let progress {
                    ProgressBar(value: progress, height: 7, tint: accent)
                } else {
                    Text(caption)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.creamMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }
}

#Preview("Stat Card") {
    ZStack {
        AppTheme.Palette.forestDeep.ignoresSafeArea()
        StatCard(
            title: "Fire Charge",
            value: "72%",
            caption: "Warm and steady",
            systemImage: "flame.fill",
            progress: 0.72
        )
        .frame(width: 170)
        .padding()
    }
}
