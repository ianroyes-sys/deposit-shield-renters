import Foundation
import UserNotifications

/// Local deposit-deadline reminders — scheduled the moment a move-out
/// walkthrough completes, at the state's return deadline minus 7/3/0 days.
/// No push infrastructure needed; these fire entirely on-device.
enum NotificationManager {
    static func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func scheduleDeadlineReminders(propertyId: UUID, propertyName: String, state: String?) async {
        guard let law = StateDepositLaws.law(for: state) else { return }

        await requestAuthorization()
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        // Clear any stale reminders from a previous move-out on this property.
        cancelDeadlineReminders(propertyId: propertyId)

        let deadline = Calendar.current.date(byAdding: .day, value: law.returnDeadlineDays, to: Date()) ?? Date()

        for offset in [7, 3, 0] {
            guard let fireDate = Calendar.current.date(byAdding: .day, value: -offset, to: deadline), fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Deposit Shield"
            content.body = offset == 0
                ? "Today is your landlord's deadline to return your deposit for \(propertyName) in \(law.code)."
                : "Your landlord's deadline to return your deposit for \(propertyName) in \(law.code) is in \(offset) day\(offset == 1 ? "" : "s")."
            content.sound = .default

            var comps = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
            comps.hour = 9
            comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: identifier(propertyId: propertyId, offset: offset), content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    static func cancelDeadlineReminders(propertyId: UUID) {
        let ids = [7, 3, 0].map { identifier(propertyId: propertyId, offset: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static func identifier(propertyId: UUID, offset: Int) -> String {
        "deposit-deadline-\(propertyId.uuidString)-\(offset)"
    }
}
