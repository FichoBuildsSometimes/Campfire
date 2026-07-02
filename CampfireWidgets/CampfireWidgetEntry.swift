import WidgetKit

struct CampfireWidgetEntry: TimelineEntry {
    let date: Date
    let data: CampfireWidgetData
    let dayPhase: WidgetDayPhase

    static func mock(date: Date = .now) -> CampfireWidgetEntry {
        CampfireWidgetEntry(
            date: date,
            data: .mock,
            dayPhase: WidgetDayPhase(date: date)
        )
    }

    static let previewDay = CampfireWidgetEntry(
        date: Date(timeIntervalSince1970: 1_717_672_400),
        data: .mock,
        dayPhase: .day
    )

    static let previewNight = CampfireWidgetEntry(
        date: Date(timeIntervalSince1970: 1_717_719_600),
        data: .mock,
        dayPhase: .night
    )
}
