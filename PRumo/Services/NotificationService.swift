import AppKit
import PRumoKit
@preconcurrency import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate, Sendable {
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
            content.userInfo = [AppConstants.notificationURLKey: event.url.absoluteString]
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
        guard
            let string = response.notification.request.content.userInfo[AppConstants.notificationURLKey] as? String,
            let url = URL(string: string)
        else { return }
        await MainActor.run { _ = NSWorkspace.shared.open(url) }
    }
}
