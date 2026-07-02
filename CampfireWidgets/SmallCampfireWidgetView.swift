import SwiftUI
import WidgetKit

struct SmallCampfireWidgetView: View {
    var entry: CampfireWidgetEntry

    var body: some View {
        content
        .containerBackground(for: .widget) {
            Color(red: 0.02, green: 0.06, blue: 0.09)
        }
        .widgetURL(URL(string: "campfire://home"))
        .unredacted()
    }

    private var content: some View {
        ZStack {
            backgroundLayer

            LinearGradient(
                colors: [
                    Color.black.opacity(entry.dayPhase == .day ? 0.22 : 0.52),
                    Color.black.opacity(0.08),
                    WidgetTheme.Palette.navyInk.opacity(0.78)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.30),
                    .clear,
                    Color.black.opacity(0.26)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            WidgetTheme.Palette.emberGold.opacity(0.48),
                            WidgetTheme.Palette.ember.opacity(0.24),
                            .clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 72
                    )
                )
                .blur(radius: 10)
                .frame(width: 136, height: 136)
                .offset(x: 5, y: -2)

            VStack {
                HStack {
                    fireBadge
                    Spacer()
                }

                Spacer()
            }
            .padding(.top, 13)
            .padding(.horizontal, 13)

            WidgetCampfireImage(stage: entry.data.stage, glowScale: 1.04)
                .frame(width: 86, height: 76)
                .offset(y: -2)

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                Text(entry.data.stepsTitle)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetTheme.Palette.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .shadow(color: .black.opacity(0.55), radius: 4, x: 0, y: 2)

                Text("steps")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetTheme.Palette.forestGlow)
                    .textCase(.uppercase)
                    .shadow(color: .black.opacity(0.45), radius: 3, x: 0, y: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.horizontal, 13)
            .padding(.bottom, 11)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .unredacted()
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.06, blue: 0.09),
                Color(red: 0.08, green: 0.16, blue: 0.13)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(entry.dayPhase == .day ? "widget_bg_small_day" : "widget_bg_small_night")
                .resizable()
                .scaledToFill()
        }
        .clipped()
    }

    private var fireBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 11, weight: .black))

            Text(entry.data.fireChargeTitle)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(WidgetTheme.Palette.emberGold)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(WidgetTheme.Palette.navyInk.opacity(0.66))

            Capsule()
                .fill(WidgetTheme.Palette.ember.opacity(0.14))

            Capsule()
                .strokeBorder(WidgetTheme.Palette.emberGold.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: WidgetTheme.Palette.ember.opacity(0.28), radius: 9, x: 0, y: 4)
    }
}
