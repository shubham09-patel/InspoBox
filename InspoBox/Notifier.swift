import Foundation
import UserNotifications

/// Local reminders: 1 day before the deadline and at the deadline time.
final class NotifDelegate: NSObject, UNUserNotificationCenterDelegate {
    // Show banners even while the menu bar popup is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound])
    }
}

enum Notifier {
    static let delegate = NotifDelegate()

    static func setup() {
        UNUserNotificationCenter.current().delegate = delegate
    }

    static func cancel(_ id: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["\(id)-pre", "\(id)-due"])
    }

    static func schedule(_ p: Project) {
        cancel(p.id)
        guard p.remind, p.phase != .uploaded, let deadline = p.deadline else { return }
        let title = p.title
        let phase = p.phase.rawValue
        let pid = p.id.uuidString
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            func add(_ suffix: String, _ date: Date, _ heading: String, _ body: String) {
                guard date > Date() else { return }
                let content = UNMutableNotificationContent()
                content.title = heading
                content.body = body
                content.sound = .default
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                center.add(UNNotificationRequest(identifier: "\(pid)-\(suffix)", content: content, trigger: trigger))
            }
            let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: deadline) ?? deadline
            add("pre", dayBefore, "⏰ \(title) — due tomorrow", "Current phase: \(phase)")
            add("due", deadline, "🎬 \(title) — deadline now", "Current phase: \(phase)")
        }
    }
}
