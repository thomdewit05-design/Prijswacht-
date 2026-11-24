import Foundation
import PrijswachtCore
import UserNotifications

/// Lokale meldingen. De app stuurt er maar twee: een prijsdaling en een
/// retourtermijn die bijna afloopt.
enum NotificationManager {
    static let purchaseIDKey = "purchaseID"

    @discardableResult
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func scheduleReturnReminder(id: UUID, title: String, lastDay: Date, now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        let identifier = "return-\(id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard let moment = ReturnWindow.reminderDate(lastDay: lastDay, now: now) else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Retourtermijn loopt af")
        content.body = String(localized: "Je kunt \(title) nog 3 dagen retourneren.")
        content.sound = .default
        content.userInfo = [purchaseIDKey: id.uuidString]

        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: moment)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static func cancelReturnReminder(id: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["return-\(id.uuidString)"])
    }

    static func notifyDrop(id: UUID, title: String, dropCents: Int, daysRemaining: Int) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "\(title) is \(Euro.string(dropCents)) goedkoper")
        content.body = daysRemaining >= 0
            ? String(localized: "Je kunt nog \(daysRemaining) dagen retourneren. Bekijk de snelste route.")
            : String(localized: "Bekijk wat je kunt doen.")
        content.sound = .default
        content.userInfo = [purchaseIDKey: id.uuidString]
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "drop-\(id.uuidString)", content: content, trigger: nil))
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Een tik op een melding opent het routescherm van die aankoop.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let raw = response.notification.request.content.userInfo[NotificationManager.purchaseIDKey] as? String
        guard let id = raw.flatMap(UUID.init(uuidString:)) else { return }
        await MainActor.run { AppRouter.shared.open(purchaseID: id) }
    }
}
