import SwiftUI

struct ProfileStatCard: View {
    var title: String
    var value: String
    var caption: String
    var systemImage: String
    var accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 30, height: 30)
                .background(accent.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Palette.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.creamMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(caption)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.creamMuted.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

#Preview("Profile Stat Card") {
    ZStack {
        AppTheme.Palette.navyInk.ignoresSafeArea()
        GlassCard {
            ProfileStatCard(
                title: "Total steps",
                value: "128,420",
                caption: "All-time",
                systemImage: "figure.walk",
                accent: AppTheme.Palette.forestMuted
            )
        }
        .padding()
    }
}
