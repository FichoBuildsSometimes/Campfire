import SwiftUI
import WidgetKit

struct MediumCampfireWidgetView: View {
    var entry: CampfireWidgetEntry

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                WidgetBackgroundView(size: .medium, dayPhase: entry.dayPhase)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                HStack(spacing: 10) {
                    WidgetCampfireImage(stage: entry.data.stage, glowScale: 1.18)
                        .frame(width: proxy.size.width * 0.34, height: proxy.size.height * 0.84)
                        .padding(.top, proxy.size.height * 0.06)

                    metricsPanel
                        .frame(maxWidth: .infinity, maxHeight: proxy.size.height * 0.78)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .unredacted()
        }
        .containerBackground(for: .widget) {
            Color(red: 0.02, green: 0.06, blue: 0.09)
        }
        .widgetURL(URL(string: "campfire://home"))
    }

    private var metricsPanel: some View {
        HStack(spacing: 0) {
            WidgetMetricColumn(
                title: "Steps",
                value: entry.data.stepsTitle,
                systemImage: "figure.walk",
                accent: WidgetTheme.Palette.forestGlow
            )

            metricDivider

            WidgetMetricColumn(
                title: "Sticks",
                value: entry.data.sticksTitle,
                systemImage: nil,
                accent: WidgetTheme.Palette.creamMuted,
                usesStickIcon: true
            )

            metricDivider

            WidgetMetricColumn(
                title: "Active kcal",
                value: entry.data.activeCaloriesTitle,
                systemImage: "flame.fill",
                accent: WidgetTheme.Palette.emberGold
            )

            metricDivider

            WidgetMetricColumn(
                title: "Fire Charge",
                value: entry.data.fireChargeTitle,
                systemImage: "flame.circle.fill",
                accent: WidgetTheme.Palette.ember
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: WidgetTheme.Radius.panel, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: WidgetTheme.Radius.panel, style: .continuous)
                .fill(Color.black.opacity(0.16))

            RoundedRectangle(cornerRadius: WidgetTheme.Radius.panel, style: .continuous)
                .strokeBorder(WidgetTheme.Palette.glassStroke, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 8)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.22), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 1)
            .padding(.vertical, 8)
    }
}
