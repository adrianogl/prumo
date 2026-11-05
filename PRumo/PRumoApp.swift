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

        Window(OnboardingText.windowTitle, id: OnboardingText.id) {
            OnboardingView(app: model)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(model: model)
        }
    }
}
