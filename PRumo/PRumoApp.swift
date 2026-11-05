import SwiftUI
import UserNotifications
import PRumoKit

@main
struct PRumoApp: App {
    @State private var model: AppModel

    init() {
        let notifications = NotificationService()
        UNUserNotificationCenter.current().delegate = notifications
        let model = AppModel(notifications: notifications)
        _model = State(initialValue: model)
        model.start()
    }

    var body: some Scene {
        MenuBarExtra {
            Text("PRumo")
            Text("\(model.snapshot?.mine.count ?? 0) PRs minhas")
        } label: {
            Image("MenuBarGlyph")
        }
        .menuBarExtraStyle(.window)
    }
}
