import SwiftUI

struct WidgetCampfireImage: View {
    var stage: CampfireStage
    var glowScale: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                WidgetTheme.Palette.emberGold.opacity(0.54),
                                WidgetTheme.Palette.ember.opacity(0.24),
                                .clear
                            ],
                            center: .center,
                            startRadius: 4,
                            endRadius: min(proxy.size.width, proxy.size.height) * 0.58
                        )
                    )
                    .blur(radius: 7)
                    .scaleEffect(x: 1.08 * glowScale, y: 0.82 * glowScale)
                    .offset(y: proxy.size.height * 0.08)

                Ellipse()
                    .fill(Color.black.opacity(0.30))
                    .frame(width: proxy.size.width * 0.58, height: proxy.size.height * 0.14)
                    .blur(radius: 6)
                    .offset(y: proxy.size.height * 0.04)

                Image("widget_\(stage.assetName)", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                    .shadow(color: WidgetTheme.Palette.ember.opacity(0.40), radius: 13, x: 0, y: 7)
                    .accessibilityLabel("Campfire")
            }
        }
    }
}
