import SwiftUI
import WidgetKit

@main
struct CampfireWidgets: WidgetBundle {
    var body: some Widget {
        SmallCampfireWidget()
        MediumCampfireWidget()
        CampfireLockScreenWidget()
    }
}

struct SmallCampfireWidget: Widget {
    private let kind = "CampfireSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CampfireWidgetProvider()) { entry in
            SmallCampfireWidgetView(entry: entry)
        }
        .configurationDisplayName("Campfire Steps")
        .description("Keep your steps and fire charge close by.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct MediumCampfireWidget: Widget {
    private let kind = "CampfireMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CampfireWidgetProvider()) { entry in
            MediumCampfireWidgetView(entry: entry)
        }
        .configurationDisplayName("Campfire Stats")
        .description("See today's steps, sticks, active calories, and fire charge.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct CampfireLockScreenWidget: Widget {
    private let kind = "CampfireLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CampfireWidgetProvider()) { entry in
            CampfireLockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("Campfire")
        .description("See today's fire charge and steps from the Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

#Preview("Campfire Small Night", as: .systemSmall) {
    SmallCampfireWidget()
} timeline: {
    CampfireWidgetEntry.previewNight
}

#Preview("Campfire Medium Night", as: .systemMedium) {
    MediumCampfireWidget()
} timeline: {
    CampfireWidgetEntry.previewNight
}

#Preview("Campfire Small Day", as: .systemSmall) {
    SmallCampfireWidget()
} timeline: {
    CampfireWidgetEntry.previewDay
}

#Preview("Campfire Medium Day", as: .systemMedium) {
    MediumCampfireWidget()
} timeline: {
    CampfireWidgetEntry.previewDay
}

#Preview("Campfire Lock Circular", as: .accessoryCircular) {
    CampfireLockScreenWidget()
} timeline: {
    CampfireWidgetEntry.previewDay
}

#Preview("Campfire Lock Rectangular", as: .accessoryRectangular) {
    CampfireLockScreenWidget()
} timeline: {
    CampfireWidgetEntry.previewDay
}

#Preview("Campfire Lock Inline", as: .accessoryInline) {
    CampfireLockScreenWidget()
} timeline: {
    CampfireWidgetEntry.previewDay
}
