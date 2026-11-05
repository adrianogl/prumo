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
            PopoverView(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
