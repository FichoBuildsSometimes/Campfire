import Foundation
import OSLog

protocol SharedWidgetDataStoring {
    func load() -> CampfireWidgetData?
    func loadOrMock() -> CampfireWidgetData
    func save(_ data: CampfireWidgetData)
}

struct SharedWidgetDataStore: SharedWidgetDataStoring {
    static let shared = SharedWidgetDataStore()

    static let appGroupIdentifier = "group.com.ivanmilas.campfire"
    static let widgetDataKey = "campfire_widget_data"

    private static let logger = Logger(subsystem: "com.ficho.Campfire", category: "SharedWidgetDataStore")

    private let defaults: UserDefaults?
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? SharedWidgetDataStore.makeSharedDefaults()
    }

    func load() -> CampfireWidgetData? {
        guard let defaults else {
            Self.logger.warning("Unable to load widget data because App Group defaults are unavailable.")
            return nil
        }

        guard let data = defaults.data(forKey: Self.widgetDataKey) else {
            return nil
        }

        do {
            return try decoder.decode(CampfireWidgetData.self, from: data)
        } catch {
            Self.logger.warning("Unable to decode widget data: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func loadOrMock() -> CampfireWidgetData {
        load() ?? .mock
    }

    func save(_ data: CampfireWidgetData) {
        guard let defaults else {
            Self.logger.warning("Unable to save widget data because App Group defaults are unavailable.")
            return
        }

        do {
            let encodedData = try encoder.encode(data)
            defaults.set(encodedData, forKey: Self.widgetDataKey)
            Self.logger.debug("Saved widget data: steps=\(data.stepsToday), fireCharge=\(data.fireCharge)")
        } catch {
            Self.logger.warning("Unable to encode widget data: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func makeSharedDefaults() -> UserDefaults? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            logger.warning("Unable to create App Group defaults for \(appGroupIdentifier, privacy: .public).")
            return nil
        }

        return defaults
    }
}
