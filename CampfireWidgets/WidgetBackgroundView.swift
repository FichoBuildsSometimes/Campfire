import SwiftUI

enum WidgetBackgroundSize {
    case small
    case medium
}

struct WidgetBackgroundView: View {
    var size: WidgetBackgroundSize
    var dayPhase: WidgetDayPhase

    private var assetName: String {
        switch (size, dayPhase) {
        case (.small, .day):
            "widget_bg_small_day"
        case (.small, .night):
            "widget_bg_small_night"
        case (.medium, .day):
            "widget_bg_medium_day"
        case (.medium, .night):
            "widget_bg_medium_night"
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image(assetName, bundle: .main)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                readabilityOverlay
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var readabilityOverlay: some View {
        ZStack {
            LinearGradient(
                colors: dayPhase == .day
                    ? [Color.black.opacity(0.18), Color.black.opacity(0.42)]
                    : [Color.black.opacity(0.48), WidgetTheme.Palette.navyInk.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [Color.black.opacity(0.28), .clear, Color.black.opacity(0.32)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}
