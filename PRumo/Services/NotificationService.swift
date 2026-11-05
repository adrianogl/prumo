import AppKit
import PRumoKit
@preconcurrency import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate, Sendable {
    @MainActor var onFixWithClaude: (String, URL) -> Void = { _, _ in }
    @MainActor var onRerun: (String, URL) -> Void = { _, _ in }

    @MainActor var onMute: (String) -> Void = { _ in }

    override init() {
        super.init()
        let open = UNNotificationAction(
            identifier: NotificationCategories.openAction,
            title: NotificationCategories.openTitle, options: [.foreground])
        let rerun = UNNotificationAction(
            identifier: NotificationCategories.rerunAction,
            title: NotificationCategories.rerunTitle, options: [.foreground])
        let fix = UNNotificationAction(
            identifier: NotificationCategories.fixWithClaudeAction,
            title: NotificationCategories.fixWithClaudeTitle, options: [.foreground])
        let mute = UNNotificationAction(
            identifier: NotificationCategories.muteAction,
            title: NotificationCategories.muteTitle, options: [.foreground])
        let categories = [
            UNNotificationCategory(
                identifier: NotificationCategories.ciFailed, actions: [open, rerun, fix, mute],
                intentIdentifiers: [], options: []),
            UNNotificationCategory(
                identifier: NotificationCategories.ciFailedNoRun, actions: [open, fix, mute],
                intentIdentifiers: [], options: []),
            UNNotificationCategory(
                identifier: NotificationCategories.conflict, actions: [open, mute],
                intentIdentifiers: [], options: []),
            UNNotificationCategory(
                identifier: NotificationCategories.pullRequest, actions: [open],
                intentIdentifiers: [], options: []),
        ]
        UNUserNotificationCenter.current().setNotificationCategories(Set(categories))
    }

    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func post(_ events: [NotificationEvent], grouped: Bool) {
        let center = UNUserNotificationCenter.current()
        for event in events {
            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = event.body
            content.threadIdentifier = grouped ? event.threadID : ""
            content.userInfo = [
                AppConstants.notificationURLKey: event.url.absoluteString,
                NotificationCategories.pullRequestIDKey: event.pullRequestID,
            ]
            switch event.kind {
            case .ciFailed:
                content.categoryIdentifier = event.failedRunID == nil
                    ? NotificationCategories.ciFailedNoRun : NotificationCategories.ciFailed
            case .conflict:
                content.categoryIdentifier = NotificationCategories.conflict
            default:
                content.categoryIdentifier = NotificationCategories.pullRequest
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
        let id = userInfo[NotificationCategories.pullRequestIDKey] as? String
        if response.actionIdentifier == NotificationCategories.fixWithClaudeAction, let id {
            await MainActor.run { onFixWithClaude(id, url) }
            return
        }
        if response.actionIdentifier == NotificationCategories.muteAction {
            if let id { await MainActor.run { onMute(id) } }
            return
        }
        if response.actionIdentifier == NotificationCategories.rerunAction, let id {
            await MainActor.run { onRerun(id, url) }
            return
        }
        await MainActor.run { _ = NSWorkspace.shared.open(url) }
    }
}
