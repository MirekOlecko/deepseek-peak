import AppKit
import UserNotifications

/// System notifications for rate changes.
@MainActor
final class Notifier {

    private let available: Bool
    private var didRequestAuthorization = false

    init() {
        // UNUserNotificationCenter requires a real .app bundle.
        available = Bundle.main.bundleIdentifier != nil
    }

    func requestAuthorizationIfNeeded() {
        guard available, !didRequestAuthorization else { return }
        didRequestAuthorization = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func post(title: String, body: String, sound: Bool = true) {
        if sound {
            NSSound(named: "Ping")?.play()
        }
        guard available else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
