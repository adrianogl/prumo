import SwiftUI
import UserNotifications
import PRumoKit

@main
struct PRumoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: AppModel

    init() {
        let notifications = NotificationService()
        UNUserNotificationCenter.current().delegate = notifications
        let model = AppModel(notifications: notifications)
        _model = State(initialValue: model)
        model.start()
        model.registerHotKey()
        model.updates.start()
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
        .defaultLaunchBehavior(.suppressed)

        Settings {
            SettingsView(model: model)
        }
    }
}
