import SwiftUI
import WidgetKit

struct CampfireLockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var entry: CampfireWidgetEntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                Color.clear
            }
            .widgetURL(URL(string: "campfire://home"))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .accessoryInline:
            inline
        default:
            rectangular
        }
    }

    private var circular: some View {
        Gauge(value: Double(entry.data.fireCharge), in: 0...100) {
            Image(systemName: "flame.fill")
        } currentValueLabel: {
            Text(entry.data.fireChargeTitle)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.72)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(WidgetTheme.Palette.emberGold)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.caption.weight(.bold))

                Text("Campfire")
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
            }

            Text(entry.data.fireChargeTitle)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("\(entry.data.stepsTitle) steps")
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private var inline: some View {
        Text("Campfire \(entry.data.fireChargeTitle) - \(entry.data.stepsTitle) steps")
    }
}
