import Foundation
import UserNotifications

struct ReminderNotificationService {
    static let shared = ReminderNotificationService()

    private static let notificationIdentifier = "campfire.daily.walk.reminder"

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleDailyReminder(hour: Int, minute: Int) async throws {
        let normalizedHour = CampfirePreferences.clampedReminderHour(hour)
        let normalizedMinute = CampfirePreferences.clampedReminderMinute(minute)

        let content = UNMutableNotificationContent()
        content.title = "Campfire is waiting"
        content.body = "Take a short walk to keep your fire warm."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = normalizedHour
        dateComponents.minute = normalizedMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: trigger
        )

        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        try await center.add(request)
    }

    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.notificationIdentifier])
    }
}
