import AppKit
import PRumoKit
@preconcurrency import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate, Sendable {
    @MainActor var onFixWithClaude: (String, URL) -> Void = { _, _ in }

    override init() {
        super.init()
        let open = UNNotificationAction(
            identifier: NotificationCategories.openAction,
            title: NotificationCategories.openTitle, options: [.foreground])
        let fix = UNNotificationAction(
            identifier: NotificationCategories.fixWithClaudeAction,
            title: NotificationCategories.fixWithClaudeTitle, options: [.foreground])
        let category = UNNotificationCategory(
            identifier: NotificationCategories.ciFailed, actions: [open, fix],
            intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func post(_ events: [NotificationEvent]) {
        let center = UNUserNotificationCenter.current()
        for event in events {
            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = event.body
            content.threadIdentifier = event.threadID
            content.userInfo = [
                AppConstants.notificationURLKey: event.url.absoluteString,
                NotificationCategories.pullRequestIDKey: event.pullRequestID,
            ]
            if event.kind == .ciFailed {
                content.categoryIdentifier = NotificationCategories.ciFailed
            }
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard
            let string = userInfo[AppConstants.notificationURLKey] as? String,
            let url = URL(string: string)
        else { return }
        if response.actionIdentifier == NotificationCategories.fixWithClaudeAction,
           let id = userInfo[NotificationCategories.pullRequestIDKey] as? String {
            await MainActor.run { onFixWithClaude(id, url) }
            return
        }
        await MainActor.run { _ = NSWorkspace.shared.open(url) }
    }
}
